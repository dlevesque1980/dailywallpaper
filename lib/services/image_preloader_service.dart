import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/features/smart_crop/smart_crop_preferences.dart';
import 'package:dailywallpaper/features/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/features/smart_crop/utils/image_utils.dart';

import 'package:dailywallpaper/services/image_preloader.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:dailywallpaper/features/smart_crop/services/crop_image_resolver.dart';

/// Service de préchargement intelligent des images
/// Gère le chargement parallèle et la mise en cache optimisée
class ImagePreloaderService implements ImagePreloader {
  static final ImagePreloaderService _instance =
      ImagePreloaderService._internal(ImageCacheServiceImpl());
  factory ImagePreloaderService() => _instance;

  final ImageCacheService _imageCache;

  ImagePreloaderService._internal(this._imageCache);

  @override
  int currentIndex = 0;

  @override
  List<ImageItem> currentImages = [];

  // Cache des images préchargées
  final Map<String, ui.Image> _preloadedImages = {};
  final Map<String, ui.Image> _processedImages = {};

  // Gestion des tâches en cours
  final Map<String, Future<ui.Image?>> _loadingTasks = {};
  final Map<String, Future<ui.Image?>> _processingTasks = {};

  // Verrou séquentiel pour le traitement Smart Crop (évite les pics de CPU/GPU sur Android 16)
  Future<void> _processingLock = Future.value();

  // ID de la session actuelle pour annuler les anciennes tâches
  int _currentSessionId = 0;

  Future<void> _enqueuePreprocessing(
      ImageItem imageItem, ui.Image sourceImage) {
    _processingLock = _processingLock.then((_) async {
      try {
        await _preprocessImage(imageItem, sourceImage);
      } catch (e) {
        debugPrint('Error preprocessing image in sequential lock: $e');
      }
    });
    return _processingLock;
  }

  // Configuration
  static const int maxCacheSize =
      20; // Augmenté pour éviter les dispose fréquents pendant la navigation
  static const int preloadDistance =
      2; // Nombre d'images à précharger en avance

  @override
  Future<void> preloadCurrentImageWithCrop(ImageItem imageItem) async {
    final cacheKey = _getCacheKey(imageItem);
    final processKey = _getProcessKey(imageItem);

    // 1. Download source if needed
    if (!_preloadedImages.containsKey(cacheKey) &&
        !_loadingTasks.containsKey(cacheKey)) {
      final loadingFuture = _loadImage(imageItem);
      _loadingTasks[cacheKey] = loadingFuture;
      final image = await loadingFuture;
      _loadingTasks.remove(cacheKey);
      if (image != null) _preloadedImages[cacheKey] = image;
    } else if (_loadingTasks.containsKey(cacheKey)) {
      final image = await _loadingTasks[cacheKey];
      if (image != null) _preloadedImages[cacheKey] = image;
    }

    final sourceImage = _preloadedImages[cacheKey];
    if (sourceImage == null) return;

    // 2. Preprocess
    if (!_processedImages.containsKey(processKey) &&
        !_processingTasks.containsKey(processKey)) {
      final processingFuture =
          _processImageWithSmartCrop(imageItem, sourceImage);
      _processingTasks[processKey] = processingFuture;
      final processedImage = await processingFuture;
      _processingTasks.remove(processKey);
      if (processedImage != null) _processedImages[processKey] = processedImage;
    } else if (_processingTasks.containsKey(processKey)) {
      final processedImage = await _processingTasks[processKey];
      if (processedImage != null) _processedImages[processKey] = processedImage;
    }
  }

  /// Précharge une liste d'images en parallèle
  /// Priorité: image courante > suivante > précédente > autres
  Future<void> preloadImages(List<ImageItem> images, int currentIndex) async {
    this.currentImages = images;
    this.currentIndex = currentIndex;
    final sessionId = ++_currentSessionId;

    if (images.isEmpty) return;

    // Nettoyer le cache si nécessaire
    // On passe l'index actuel pour NE PAS supprimer les images proches
    _cleanupCache(currentIndex, images);

    // Définir les priorités de chargement
    final priorities = _calculatePriorities(images, currentIndex);

    // Lancer le préchargement de manière SÉQUENTIELLE
    for (final entry in priorities.entries) {
      // Vérifier si une nouvelle session a démarré entre-temps
      if (sessionId != _currentSessionId) {
        return;
      }

      final imageItem = entry.key;
      final priority = entry.value;

      try {
        await _preloadSingleImage(imageItem, priority);

        // Pause pour la mémoire
        await Future.delayed(const Duration(milliseconds: 300));
      } catch (e) {
        // Ignorer les erreurs individuelles de préchargement
      }
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

  /// Précharge une image individuelle et déclenche le Smart Crop en arrière-plan
  Future<void> _preloadSingleImage(ImageItem imageItem, int priority) async {
    final cacheKey = _getCacheKey(imageItem);

    // Éviter le double chargement
    if (_preloadedImages.containsKey(cacheKey) ||
        _loadingTasks.containsKey(cacheKey)) {
      return;
    }

    try {
      // 1. Charger l'image source (téléchargement ou cache)
      final loadingFuture = _loadImage(imageItem);
      _loadingTasks[cacheKey] = loadingFuture;

      final image = await loadingFuture;
      if (image != null) {
        _preloadedImages[cacheKey] = image;
        // 2. Déclencher le prétraitement Smart Crop en arrière-plan (file d'attente séquentielle)
        unawaited(_enqueuePreprocessing(imageItem, image));
      }
    } catch (e) {
      debugPrint('Erreur préchargement image ${imageItem.url}: $e');
    } finally {
      _loadingTasks.remove(cacheKey);
    }
  }

  /// Charge une image (depuis le cache local ou l'URL)
  Future<ui.Image?> _loadImage(ImageItem imageItem) async {
    try {
      // 1. Try to load from local cache
      final localImage =
          await _imageCache.loadSourceImage(imageItem.imageIdent);
      if (localImage != null) {
        return localImage;
      }

      // 2. If not found locally, download, save, and load
      final savedPath = await _imageCache.downloadAndSaveSourceImage(
          imageItem.url, imageItem.imageIdent);
      if (savedPath != null) {
        // Enregistrer le chemin de l'image source en DB SQLite
        final dbHelper = DatabaseHelper();
        await dbHelper.updateImagePaths(
          imageItem.imageIdent,
          localSourcePath: savedPath,
        );
        imageItem.localSourcePath = savedPath;

        return await _imageCache.loadSourceImage(imageItem.imageIdent);
      }

      // 3. Fallback to direct URL load if saving failed
      return await _imageCache.loadImageFromUrl(imageItem.url);
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

    if (currentImages.isNotEmpty) {
      final index = currentImages.indexWhere((img) => img.imageIdent == imageItem.imageIdent);
      if (index != -1) {
        final diff = (index - currentIndex).abs();
        final circDist = diff > currentImages.length / 2 ? currentImages.length - diff : diff;
        if (circDist > 1) {
          return;
        }
      }
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

  /// Traite une image avec smart crop (ou charge depuis le cache)
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

      final result = await CropImageResolver.resolve(
        image: imageItem,
        sourceImage: sourceImage,
        targetSize: targetSize,
        settings: cropSettings,
        imageCache: _imageCache,
      );

      return result.image;
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

  @override
  Future<ui.Image?>? getLoadingTask(ImageItem imageItem) {
    final cacheKey = _getCacheKey(imageItem);
    return _loadingTasks[cacheKey];
  }

  @override
  Future<ui.Image?>? getProcessingTask(ImageItem imageItem) {
    final processKey = _getProcessKey(imageItem);
    return _processingTasks[processKey];
  }

  /// Nettoye le cache intelligemment
  void _cleanupCache(int currentIndex, List<ImageItem> images) {
    if (_preloadedImages.length <= maxCacheSize &&
        _processedImages.length <= maxCacheSize) {
      return;
    }

    // Identifier les images à protéger (celles proches de l'index actuel)
    final protectedKeys = <String>{};
    for (int i = currentIndex - 2; i <= currentIndex + 2; i++) {
      final idx = (i + images.length) % images.length;
      if (idx >= 0 && idx < images.length) {
        protectedKeys.add(_getCacheKey(images[idx]));
        protectedKeys.add(_getProcessKey(images[idx]));
      }
    }

    if (_preloadedImages.length > maxCacheSize) {
      final keysToRemove = _preloadedImages.keys
          .where((key) => !protectedKeys.contains(key))
          .take(_preloadedImages.length - maxCacheSize)
          .toList();

      for (final key in keysToRemove) {
        _preloadedImages[key]?.dispose();
        _preloadedImages.remove(key);
      }
    }

    if (_processedImages.length > maxCacheSize) {
      final keysToRemove = _processedImages.keys
          .where((key) => !protectedKeys.contains(key))
          .take(_processedImages.length - maxCacheSize)
          .toList();

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
