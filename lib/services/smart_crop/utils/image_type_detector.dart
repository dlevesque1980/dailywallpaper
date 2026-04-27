import 'dart:ui' as ui;
import '../models/crop_settings.dart';

/// Détecteur de type d'image pour optimiser automatiquement les paramètres de crop
class ImageTypeDetector {
  /// Détecte le type d'image et retourne les paramètres optimaux
  static CropSettings detectOptimalSettings(ui.Image image,
      {String? imageSource}) {
    final aspectRatio = image.width / image.height;

    // Détection basée sur la source de l'image
    if (imageSource != null) {
      if (imageSource.contains('bing') || imageSource.contains('nasa')) {
        // Images Bing et NASA sont généralement des paysages de haute qualité
        return CropSettings.landscapeOptimized;
      }

      if (imageSource.contains('pexels')) {
        // Pexels a une variété d'images, utiliser des paramètres équilibrés
        return aspectRatio > 1.5
            ? CropSettings.landscapeOptimized
            : CropSettings.balanced;
      }
    }

    // Détection basée sur le ratio d'aspect
    if (aspectRatio > 1.6) {
      // Image très large - probablement un paysage
      return CropSettings.landscapeOptimized;
    } else if (aspectRatio > 1.2) {
      // Image modérément large - paysage ou photo générale
      return CropSettings.balanced;
    } else if (aspectRatio < 0.8) {
      // Image portrait - utiliser des paramètres conservateurs
      return CropSettings.conservative;
    } else {
      // Image carrée ou proche du carré - paramètres équilibrés
      return CropSettings.balanced;
    }
  }

  /// Détecte si une image est probablement un paysage
  static bool isLikelyLandscape(ui.Image image, {String? imageSource}) {
    final aspectRatio = image.width / image.height;

    // Vérification par source
    if (imageSource != null) {
      if (imageSource.contains('bing') || imageSource.contains('nasa')) {
        return true;
      }
    }

    // Vérification par ratio d'aspect
    return aspectRatio > 1.3;
  }

  /// Détecte si une image nécessite un traitement conservateur
  static bool needsConservativeProcessing(ui.Image image,
      {String? imageSource}) {
    final aspectRatio = image.width / image.height;

    // Images portrait ou très petites
    if (aspectRatio < 0.9 || image.width < 800 || image.height < 600) {
      return true;
    }

    return false;
  }

  /// Ajuste les paramètres en fonction de la taille de l'écran cible
  static CropSettings adjustForTargetSize(
      CropSettings baseSettings, ui.Size targetSize, ui.Image sourceImage) {
    final targetAspectRatio = targetSize.width / targetSize.height;
    final sourceAspectRatio = sourceImage.width / sourceImage.height;
    final aspectRatioDifference = (targetAspectRatio - sourceAspectRatio).abs();

    // Si la différence de ratio est importante, utiliser des paramètres plus agressifs
    if (aspectRatioDifference > 0.5) {
      return baseSettings.copyWith(
        aggressiveness: CropAggressiveness.aggressive,
        enableEdgeDetection: true,
        maxProcessingTime: const Duration(seconds: 3),
      );
    }

    // Si la différence est minime, on peut être plus conservateur
    if (aspectRatioDifference < 0.2) {
      return baseSettings.copyWith(
        aggressiveness: CropAggressiveness.conservative,
        maxProcessingTime: const Duration(seconds: 1),
      );
    }

    return baseSettings;
  }

  /// Retourne des paramètres optimisés pour les images Bing spécifiquement
  static CropSettings getBingOptimizedSettings() {
    return const CropSettings(
      aggressiveness: CropAggressiveness.aggressive,
      enableRuleOfThirds: true,
      enableEntropyAnalysis: true,
      enableEdgeDetection: true,
      enableCenterWeighting:
          false, // Les images Bing ont souvent des sujets décentrés
      maxProcessingTime:
          Duration(seconds: 4), // Plus de temps pour une meilleure analyse
      enableSubjectScaling: true,
      minSubjectCoverage: 0.60, // Softer: allows wider crop window with letterbox fill
      maxScaleFactor: 3.0,
      enableMlSubjectDetection: true,
      allowLetterbox: true, // Blurred fill for wide landscape→portrait conversions
    );
  }

  /// Retourne des paramètres optimisés pour les images NASA
  static CropSettings getNASAOptimizedSettings() {
    return const CropSettings(
      aggressiveness: CropAggressiveness.aggressive,
      enableRuleOfThirds: true,
      enableEntropyAnalysis: true,
      enableEdgeDetection: true,
      enableCenterWeighting:
          true, // Les images NASA peuvent avoir des sujets centrés
      maxProcessingTime: Duration(seconds: 3),
      enableSubjectScaling: true,
      minSubjectCoverage: 0.60,
      maxScaleFactor: 3.0,
      enableMlSubjectDetection: true,
      allowLetterbox: true,
    );
  }

  /// Retourne des paramètres optimisés pour les images Pexels
  static CropSettings getPexelsOptimizedSettings() {
    return const CropSettings(
      aggressiveness: CropAggressiveness.balanced,
      enableRuleOfThirds: true,
      enableEntropyAnalysis: true,
      enableEdgeDetection: false, // Pexels a des images variées, rester modéré
      enableCenterWeighting: true,
      maxProcessingTime: Duration(seconds: 2),
    );
  }

  /// Détecte si un sujet est probablement un gros plan (macro)
  static bool isMacroCloseUp(ui.Rect subjectBounds, ui.Size imageSize) {
    final relWidth = subjectBounds.width / imageSize.width;
    final relHeight = subjectBounds.height / imageSize.height;

    // Si le sujet occupe plus de 40% de la largeur ou de la hauteur,
    // c'est probablement un gros plan où un crop agressif serait dommageable.
    return relWidth > 0.4 || relHeight > 0.4;
  }
}
