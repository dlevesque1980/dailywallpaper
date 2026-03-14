import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_type_detector.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

void main() {
  group('ImageTypeDetector', () {
    test('should detect Bing images correctly', () {
      final settings = ImageTypeDetector.detectOptimalSettings(
        _createMockImage(1920, 1080),
        imageSource: 'bing.en-US',
      );

      expect(settings.aggressiveness, equals(CropAggressiveness.aggressive));
      expect(settings.enableRuleOfThirds, isTrue);
      expect(settings.enableEntropyAnalysis, isTrue);
      expect(settings.enableEdgeDetection, isTrue);
    });

    test('should detect NASA images correctly', () {
      final settings = ImageTypeDetector.detectOptimalSettings(
        _createMockImage(1920, 1080),
        imageSource: 'nasa.2024-01-01',
      );

      expect(settings.aggressiveness, equals(CropAggressiveness.aggressive));
      expect(settings.enableRuleOfThirds, isTrue);
      expect(settings.enableEntropyAnalysis, isTrue);
      expect(settings.enableEdgeDetection, isTrue);
    });

    test('should detect Pexels images correctly', () {
      final settings = ImageTypeDetector.detectOptimalSettings(
        _createMockImage(1920, 1080),
        imageSource: 'pexels.nature',
      );

      expect(settings.aggressiveness, equals(CropAggressiveness.aggressive));
      expect(settings.enableRuleOfThirds, isTrue);
      expect(settings.enableEntropyAnalysis, isTrue);
      expect(settings.enableEdgeDetection, isTrue);
    });

    test('should detect landscape images by aspect ratio', () {
      // Image très large (paysage)
      final landscapeSettings = ImageTypeDetector.detectOptimalSettings(
        _createMockImage(2560, 1440), // ratio = 1.78
      );

      expect(landscapeSettings.aggressiveness,
          equals(CropAggressiveness.aggressive));

      // Image portrait
      final portraitSettings = ImageTypeDetector.detectOptimalSettings(
        _createMockImage(1080, 1920), // ratio = 0.56
      );

      expect(portraitSettings.aggressiveness,
          equals(CropAggressiveness.conservative));
    });

    test('should identify landscape images correctly', () {
      expect(
        ImageTypeDetector.isLikelyLandscape(
          _createMockImage(1920, 1080),
          imageSource: 'bing.en-US',
        ),
        isTrue,
      );

      expect(
        ImageTypeDetector.isLikelyLandscape(
          _createMockImage(2560, 1440), // ratio = 1.78
        ),
        isTrue,
      );

      expect(
        ImageTypeDetector.isLikelyLandscape(
          _createMockImage(1080, 1920), // ratio = 0.56
        ),
        isFalse,
      );
    });

    test('should identify images needing conservative processing', () {
      // Image portrait
      expect(
        ImageTypeDetector.needsConservativeProcessing(
          _createMockImage(1080, 1920),
        ),
        isTrue,
      );

      // Image très petite
      expect(
        ImageTypeDetector.needsConservativeProcessing(
          _createMockImage(640, 480),
        ),
        isTrue,
      );

      // Image paysage normale
      expect(
        ImageTypeDetector.needsConservativeProcessing(
          _createMockImage(1920, 1080),
        ),
        isFalse,
      );
    });

    test('should adjust settings for target size', () {
      final baseSettings = CropSettings.balanced;
      final sourceImage = _createMockImage(1920, 1080); // ratio = 1.78

      // Target très différent (portrait)
      final portraitTarget = ui.Size(1080, 1920); // ratio = 0.56
      final adjustedForPortrait = ImageTypeDetector.adjustForTargetSize(
        baseSettings,
        portraitTarget,
        sourceImage,
      );

      // Devrait être plus agressif car grande différence de ratio
      expect(adjustedForPortrait.aggressiveness,
          equals(CropAggressiveness.aggressive));
      expect(adjustedForPortrait.enableEdgeDetection, isTrue);

      // Target similaire
      final similarTarget = ui.Size(1920, 1200); // ratio = 1.6
      final adjustedForSimilar = ImageTypeDetector.adjustForTargetSize(
        baseSettings,
        similarTarget,
        sourceImage,
      );

      // Devrait être plus conservateur car petite différence
      expect(adjustedForSimilar.aggressiveness,
          equals(CropAggressiveness.conservative));
    });

    test('should provide optimized settings for each source', () {
      final bingSettings = ImageTypeDetector.getBingOptimizedSettings();
      expect(
          bingSettings.aggressiveness, equals(CropAggressiveness.aggressive));
      expect(bingSettings.enableCenterWeighting, isFalse); // Spécifique à Bing

      final nasaSettings = ImageTypeDetector.getNASAOptimizedSettings();
      expect(
          nasaSettings.aggressiveness, equals(CropAggressiveness.aggressive));
      expect(nasaSettings.enableCenterWeighting, isTrue); // Spécifique à NASA

      final pexelsSettings = ImageTypeDetector.getPexelsOptimizedSettings();
      expect(
          pexelsSettings.aggressiveness, equals(CropAggressiveness.balanced));
      expect(pexelsSettings.enableEdgeDetection,
          isFalse); // Plus modéré pour Pexels
    });

    test('should handle null image source gracefully', () {
      final settings = ImageTypeDetector.detectOptimalSettings(
        _createMockImage(1920, 1080),
        imageSource: null,
      );

      // Devrait utiliser la détection par ratio d'aspect
      expect(settings.aggressiveness, equals(CropAggressiveness.aggressive));
    });

    test('should handle unknown image source', () {
      final settings = ImageTypeDetector.detectOptimalSettings(
        _createMockImage(1920, 1080),
        imageSource: 'unknown.source',
      );

      // Devrait utiliser la détection par ratio d'aspect
      expect(settings.aggressiveness, equals(CropAggressiveness.aggressive));
    });
  });
}

/// Crée une image mock pour les tests
ui.Image _createMockImage(int width, int height) {
  // Cette fonction crée un objet mock qui simule une ui.Image
  // Pour les tests, nous utilisons une classe simple qui implémente les propriétés nécessaires
  return _MockImage(width, height);
}

/// Classe mock pour simuler ui.Image dans les tests
class _MockImage implements ui.Image {
  @override
  final int width;

  @override
  final int height;

  _MockImage(this.width, this.height);

  // Implémentations minimales pour les autres méthodes requises
  @override
  void dispose() {}

  @override
  ui.ColorSpace get colorSpace => ui.ColorSpace.sRGB;

  @override
  Future<ByteData?> toByteData(
      {ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) async {
    // Retourner des données mock pour les tests
    return ByteData(width * height * 4);
  }

  @override
  ui.Image clone() => _MockImage(width, height);

  @override
  bool get debugDisposed => false;

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;

  @override
  bool isCloneOf(ui.Image other) => false;
}
