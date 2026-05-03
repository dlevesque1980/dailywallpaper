import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'smart_crop/smart_cropper.dart';
import 'smart_crop/smart_crop_preferences.dart';
import 'smart_crop/utils/screen_utils.dart';
import 'smart_crop/utils/image_utils.dart';

/// Service de préchargement intelligent des images
/// Gère le chargement parallèle et la mise en cache optimisée
class ImagePreloaderService {
  static final ImagePreloaderService _instance =
      ImagePreloaderService._internal();
  factory ImagePreloaderService() => _instance;
  ImagePreloaderService._internal();

  // Cache des images préchargées
  final Map<String, ui.Image> _preloadedImages = {};
  final Map<String, ui.Image> _processedImages = {};

  // Gestion des tâches en cours
  final Map<String, Future<ui.Image?>> _loadingTasks = {};
  final Map<String, Future<ui.Image?>> _processingTasks = {};

  // Configuration
  static const int maxCacheSize =
      10; // Limite de cache pour éviter les fuites mémoire
  static const int preloadDistance =
      2; // Nombre d'images à précharger en avance

  /// Précharge une liste d'images en parallèle
  /// Priorité: image courante > suivante > précédente > autres
  Future<void> preloadImages(List<ImageItem> images, int currentIndex) async {
    if (images.isEmpty) return;

    // Nettoyer le cache si nécessaire
    _cleanupCache();

    // Définir les priorités de chargement
    final priorities = _calculatePriorities(images, currentIndex);

    // Lancer le préchargement en parallèle avec gestion des priorités
    final futures = <Future<void>>[];

    for (final entry in priorities.entries) {
      final imageItem = entry.key;
      final priority = entry.value;

      futures.add(_preloadSingleImage(imageItem, priority));
    }

    // Attendre que TOUTES les images soient chargées et traitées
    // On traite les images de manière séquentielle pour ne pas saturer le thread UI
    // et permettre au loader de continuer de tourner de façon fluide.
    for (final entry in priorities.entries) {
      // Yield BEFORE starting work on an image
      await Future.delayed(Duration.zero);
      
      await _preloadSingleImage(entry.key, entry.value);
      
      // Yield AFTER working on an image
      await Future.delayed(const Duration(milliseconds: 50));
    }
  }

  /// Calcule les priorités de chargement basées sur l'index courant
  Map<ImageItem, int> _calculatePriorities(
      List<ImageItem> images, int currentIndex) {
    final priorities = <ImageItem, int>{};

    for (int i = 0; i < images.length; i++) {
      int priority;

      if (i == currentIndex) {
        priority = 1; // Priorité maximale pour l'image courante
      } else if (i == (currentIndex + 1) % images.length) {
        priority = 2; // Image suivante
      } else if (i == (currentIndex - 1 + images.length) % images.length) {
        priority = 3; // Image précédente
      } else {
        // Priorité basée sur la distance
        final distance = (i - currentIndex).abs();
        priority = 4 + distance;
      }

      priorities[images[i]] = priority;
    }

    return Map.fromEntries(priorities.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value)));
  }

  /// Précharge une image individuelle
  Future<void> _preloadSingleImage(ImageItem imageItem, int priority) async {
    final cacheKey = _getCacheKey(imageItem);

    // Éviter le double chargement
    if (_preloadedImages.containsKey(cacheKey) ||
        _loadingTasks.containsKey(cacheKey)) {
      return;
    }

    try {
      // Démarrer le chargement
      final loadingFuture = _loadImage(imageItem);
      _loadingTasks[cacheKey] = loadingFuture;

      final image = await loadingFuture;
      if (image != null) {
        _preloadedImages[cacheKey] = image;

        // Traiter le smart crop immédiatement pour garantir que l'image est prête
        // Yield before preprocessing to allow UI updates
        await Future.delayed(Duration.zero);
        await _preprocessImage(imageItem, image);
        await Future.delayed(Duration.zero);
      }
    } catch (e) {
      debugPrint('Erreur préchargement image ${imageItem.url}: $e');
    } finally {
      _loadingTasks.remove(cacheKey);
    }
  }

  /// Charge une image depuis l'URL
  Future<ui.Image?> _loadImage(ImageItem imageItem) async {
    try {
      return await ImageUtils.loadImageFromUrl(imageItem.url);
    } catch (e) {
      debugPrint('Erreur chargement image ${imageItem.url}: $e');
      return null;
    }
  }

  /// Prétraite une image avec smart crop
  Future<void> _preprocessImage(
      ImageItem imageItem, ui.Image sourceImage) async {
    final processKey = _getProcessKey(imageItem);

    if (_processedImages.containsKey(processKey) ||
        _processingTasks.containsKey(processKey)) {
      return;
    }

    try {
      final processingFuture =
          _processImageWithSmartCrop(imageItem, sourceImage);
      _processingTasks[processKey] = processingFuture;

      final processedImage = await processingFuture;
      if (processedImage != null) {
        _processedImages[processKey] = processedImage;
      }
    } catch (e) {
      debugPrint('Erreur traitement smart crop ${imageItem.url}: $e');
    } finally {
      _processingTasks.remove(processKey);
    }
  }

  /// Traite une image avec smart crop
  Future<ui.Image?> _processImageWithSmartCrop(
      ImageItem imageItem, ui.Image sourceImage) async {
    try {
      final isSmartCropEnabled =
          await SmartCropPreferences.isSmartCropEnabled();
      if (!isSmartCropEnabled) return sourceImage;

      final cropSettings = await SmartCropPreferences.getCropSettings();
      final screenSize = ScreenUtils.getPhysicalScreenSize();

      final targetSize = ScreenUtils.calculateTargetSize(
        ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        screenSize.width / screenSize.height,
        maxDimension: screenSize.width > screenSize.height
            ? screenSize.width.round()
            : screenSize.height.round(),
      );

      final result = await SmartCropper.processImage(
        imageItem.url,
        sourceImage,
        targetSize,
        cropSettings,
      );

      if (result.success) {
        // Essential: Populate the global processed cache so Carousel can see it
        SmartCropper.cacheProcessedImage(imageItem.imageIdent, result.image);
        return result.image;
      }
      return sourceImage;
    } catch (e) {
      debugPrint('Erreur smart crop ${imageItem.url}: $e');
      return sourceImage;
    }
  }

  /// Récupère une image préchargée
  ui.Image? getPreloadedImage(ImageItem imageItem) {
    final cacheKey = _getCacheKey(imageItem);
    return _preloadedImages[cacheKey];
  }

  /// Récupère une image prétraitée
  ui.Image? getProcessedImage(ImageItem imageItem) {
    final processKey = _getProcessKey(imageItem);
    return _processedImages[processKey];
  }

  /// Vérifie si une image est en cours de chargement
  bool isLoading(ImageItem imageItem) {
    final cacheKey = _getCacheKey(imageItem);
    return _loadingTasks.containsKey(cacheKey);
  }

  /// Vérifie si une image est en cours de traitement
  bool isProcessing(ImageItem imageItem) {
    final processKey = _getProcessKey(imageItem);
    return _processingTasks.containsKey(processKey);
  }

  /// Nettoie le cache pour éviter les fuites mémoire
  void _cleanupCache() {
    if (_preloadedImages.length > maxCacheSize) {
      final keysToRemove =
          _preloadedImages.keys.take(_preloadedImages.length - maxCacheSize);
      for (final key in keysToRemove) {
        _preloadedImages[key]?.dispose();
        _preloadedImages.remove(key);
      }
    }

    if (_processedImages.length > maxCacheSize) {
      final keysToRemove =
          _processedImages.keys.take(_processedImages.length - maxCacheSize);
      for (final key in keysToRemove) {
        _processedImages[key]?.dispose();
        _processedImages.remove(key);
      }
    }
  }

  /// Vide complètement le cache
  void clearCache() {
    try {
      for (final image in _preloadedImages.values) {
        image.dispose();
      }
      for (final image in _processedImages.values) {
        image.dispose();
      }
    } catch (e) {
      // Ignorer les erreurs de dispose dans les tests
      debugPrint('Erreur lors du nettoyage du cache: $e');
    }

    _preloadedImages.clear();
    _processedImages.clear();
    _loadingTasks.clear();
    _processingTasks.clear();
  }

  /// Génère une clé de cache pour une image
  String _getCacheKey(ImageItem imageItem) {
    return '${imageItem.url}_${imageItem.imageIdent}';
  }

  /// Génère une clé de traitement pour une image
  String _getProcessKey(ImageItem imageItem) {
    return '${imageItem.url}_${imageItem.imageIdent}_processed';
  }
}
