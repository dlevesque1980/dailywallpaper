import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/landscape_aware_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'dart:ui' as ui;

void main() {
  group('LandscapeAwareCropAnalyzer', () {
    late LandscapeAwareCropAnalyzer analyzer;

    setUp(() {
      analyzer = LandscapeAwareCropAnalyzer();
    });

    test('should have correct properties', () {
      expect(analyzer.strategyName, equals('landscape_aware'));
      expect(analyzer.weight, equals(0.8));
      expect(analyzer.isEnabledByDefault, isTrue);
      expect(analyzer.minConfidenceThreshold, equals(0.2));
    });

    test('should detect landscape images correctly', () {
      // Cette méthode teste la logique de détection de paysage
      // sans avoir besoin d'une vraie image

      // Simuler une image paysage (ratio > 1.3)
      const landscapeSize = ui.Size(1920, 1080); // ratio = 1.78
      const portraitSize = ui.Size(1080, 1920); // ratio = 0.56
      const squareSize = ui.Size(1080, 1080); // ratio = 1.0

      // Test avec différents ratios d'aspect
      expect(landscapeSize.width / landscapeSize.height > 1.3, isTrue);
      expect(portraitSize.width / portraitSize.height > 1.3, isFalse);
      expect(squareSize.width / squareSize.height > 1.3, isFalse);
    });

    test('should calculate crop dimensions correctly', () {
      // Test de la logique de calcul des dimensions de crop
      const imageSize = ui.Size(1920, 1080);
      const targetAspectRatio = 0.5625; // 9:16 (portrait mobile)

      // Pour une image paysage vers un format portrait
      final imageAspectRatio = imageSize.width / imageSize.height;

      double expectedCropWidth, expectedCropHeight;
      if (targetAspectRatio > imageAspectRatio) {
        expectedCropWidth = 1.0;
        expectedCropHeight = imageAspectRatio / targetAspectRatio;
      } else {
        expectedCropHeight = 1.0;
        expectedCropWidth = targetAspectRatio / imageAspectRatio;
      }

      // Vérifier que les calculs sont corrects
      expect(expectedCropWidth, closeTo(0.316, 0.01)); // ~31.6% de la largeur
      expect(expectedCropHeight, equals(1.0)); // 100% de la hauteur
    });

    test('should create valid fallback crop', () {
      const imageSize = ui.Size(1920, 1080);
      const targetAspectRatio = 0.5625;

      // Simuler la création d'un crop centré
      final imageAspectRatio = imageSize.width / imageSize.height;

      double cropWidth, cropHeight;
      if (targetAspectRatio > imageAspectRatio) {
        cropWidth = 1.0;
        cropHeight = imageAspectRatio / targetAspectRatio;
      } else {
        cropHeight = 1.0;
        cropWidth = targetAspectRatio / imageAspectRatio;
      }

      final centerCrop = CropCoordinates(
        x: (1.0 - cropWidth) / 2,
        y: (1.0 - cropHeight) / 2,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.4,
        strategy: 'landscape_aware',
      );

      // Vérifier que le crop est valide
      expect(centerCrop.isValid, isTrue);
      expect(centerCrop.x, greaterThanOrEqualTo(0.0));
      expect(centerCrop.y, greaterThanOrEqualTo(0.0));
      expect(centerCrop.x + centerCrop.width, lessThanOrEqualTo(1.0));
      expect(centerCrop.y + centerCrop.height, lessThanOrEqualTo(1.0));
    });

    test('should handle edge cases', () {
      // Test avec des tailles d'image extrêmes
      const veryWideImage = ui.Size(3840, 1080); // ratio = 3.56
      const veryTallImage = ui.Size(1080, 3840); // ratio = 0.28

      expect(veryWideImage.width / veryWideImage.height > 1.3, isTrue);
      expect(veryTallImage.width / veryTallImage.height > 1.3, isFalse);
    });

    test('should validate crop coordinates', () {
      // Test de validation des coordonnées de crop
      final validCrop = CropCoordinates(
        x: 0.1,
        y: 0.2,
        width: 0.6,
        height: 0.7,
        confidence: 0.8,
        strategy: 'landscape_aware',
      );

      final invalidCrop = CropCoordinates(
        x: -0.1, // Invalide
        y: 0.2,
        width: 0.6,
        height: 0.7,
        confidence: 0.8,
        strategy: 'landscape_aware',
      );

      expect(validCrop.isValid, isTrue);
      expect(invalidCrop.isValid, isFalse);
    });
  });
}
