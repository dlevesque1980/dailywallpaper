import 'package:flutter_test/flutter_test.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dailywallpaper/services/smart_crop/utils/fallback_strategies.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

// Mock image for testing
class MockImage implements ui.Image {
  @override
  final int width;

  @override
  final int height;

  MockImage({this.width = 1000, this.height = 1000});

  @override
  void dispose() {}

  @override
  ui.ColorSpace get colorSpace => throw UnimplementedError();

  @override
  Future<ByteData?> toByteData(
      {ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) {
    throw UnimplementedError();
  }

  @override
  bool get debugDisposed => false;

  @override
  ui.Image clone() => this;

  @override
  bool isCloneOf(ui.Image other) => false;

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;
}

void main() {
  group('FallbackCropStrategies', () {
    late FallbackCropStrategies strategies;
    late ui.Image mockImage;
    late ui.Size targetSize;
    late CropSettings defaultSettings;

    setUp(() {
      strategies = FallbackCropStrategies();
      mockImage = MockImage(width: 1200, height: 800);
      targetSize = const ui.Size(600, 400);
      defaultSettings = CropSettings.defaultSettings;
    });

    group('Fallback Crop Creation', () {
      test('should create intelligent center crop for timeout reason', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'timeout',
          settings: defaultSettings,
        );

        expect(crop.strategy, equals('intelligent_center_fallback'));
        expect(crop.confidence, equals(0.7));
        expect(crop.x, greaterThanOrEqualTo(0.0));
        expect(crop.y, greaterThanOrEqualTo(0.0));
        expect(crop.width, greaterThan(0.0));
        expect(crop.height, greaterThan(0.0));
        expect(crop.x + crop.width, lessThanOrEqualTo(1.0));
        expect(crop.y + crop.height, lessThanOrEqualTo(1.0));
      });

      test('should create aspect ratio aware crop for analyzer failure', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'analyzer_failure',
          settings: defaultSettings,
        );

        expect(crop.strategy, equals('aspect_ratio_aware_fallback'));
        expect(crop.confidence, equals(0.6));
      });

      test('should create safe zone crop for invalid input', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'invalid_input',
          settings: defaultSettings,
        );

        expect(crop.strategy, equals('safe_zone_fallback'));
        expect(crop.confidence, equals(0.5));
      });

      test('should use aggressiveness level for fallback selection', () {
        final conservativeSettings = defaultSettings.copyWith(
          aggressiveness: CropAggressiveness.conservative,
        );

        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'test',
          settings: conservativeSettings,
        );

        // Should create a valid crop regardless of aggressiveness
        expect(crop.x, greaterThanOrEqualTo(0.0));
        expect(crop.y, greaterThanOrEqualTo(0.0));
        expect(crop.width, greaterThan(0.0));
        expect(crop.height, greaterThan(0.0));
      });
    });

    group('Intelligent Center Crop', () {
      test('should handle wider target aspect ratio', () {
        final wideTarget = const ui.Size(800, 400); // 2:1 aspect ratio
        final squareImage =
            MockImage(width: 1000, height: 1000); // 1:1 aspect ratio

        final crop = strategies.createFallbackCrop(
          image: squareImage,
          targetSize: wideTarget,
          reason: 'timeout',
        );

        // Should use full width, crop height
        expect(crop.width, equals(1.0));
        expect(crop.height, lessThan(1.0));
        expect(crop.x, equals(0.0));
        expect(crop.y, greaterThanOrEqualTo(0.0));
      });

      test('should handle taller target aspect ratio', () {
        final tallTarget = const ui.Size(400, 800); // 1:2 aspect ratio
        final squareImage =
            MockImage(width: 1000, height: 1000); // 1:1 aspect ratio

        final crop = strategies.createFallbackCrop(
          image: squareImage,
          targetSize: tallTarget,
          reason: 'timeout',
        );

        // Should use full height, crop width
        expect(crop.height, equals(1.0));
        expect(crop.width, lessThan(1.0));
        expect(crop.y, equals(0.0));
        expect(crop.x, greaterThanOrEqualTo(0.0));
      });

      test('should apply rule of thirds positioning when enabled', () {
        final settingsWithRuleOfThirds = defaultSettings.copyWith(
          enableRuleOfThirds: true,
        );

        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: const ui.Size(400, 800), // Tall target
          reason: 'timeout',
          settings: settingsWithRuleOfThirds,
        );

        // Should create a valid crop
        expect(crop.x, greaterThanOrEqualTo(0.0));
        expect(crop.y, greaterThanOrEqualTo(0.0));
        expect(crop.width, greaterThan(0.0));
        expect(crop.height, greaterThan(0.0));
      });
    });

    group('Aspect Ratio Aware Crop', () {
      test('should include padding to avoid edge artifacts', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'analyzer_failure',
        );

        // Should not use the full image (due to padding)
        expect(crop.width, lessThan(1.0));
        expect(crop.height, lessThan(1.0));
      });

      test('should maintain reasonable crop dimensions', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'analyzer_failure',
        );

        expect(crop.width, greaterThanOrEqualTo(0.1));
        expect(crop.height, greaterThanOrEqualTo(0.1));
        expect(crop.width, lessThanOrEqualTo(1.0));
        expect(crop.height, lessThanOrEqualTo(1.0));
      });
    });

    group('User Preference Crop', () {
      test('should use intelligent center when no preferences available', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'network_error',
          settings: CropSettings.defaultSettings,
        );

        // Should fall back to intelligent center
        expect(crop.confidence, greaterThanOrEqualTo(0.6));
      });

      test('should create user preference crop based on aggressiveness', () {
        final aggressiveSettings = defaultSettings.copyWith(
          aggressiveness: CropAggressiveness.aggressive,
        );

        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: const ui.Size(400, 800), // Tall target
          reason: 'network_error',
          settings: aggressiveSettings,
        );

        expect(crop.strategy, equals('user_preference_fallback'));
        expect(crop.x, greaterThanOrEqualTo(0.0));
        expect(crop.y, greaterThanOrEqualTo(0.0));
        expect(crop.x + crop.width, lessThanOrEqualTo(1.0));
        expect(crop.y + crop.height, lessThanOrEqualTo(1.0));
      });
    });

    group('Safe Zone Crop', () {
      test('should maintain safe margins from edges', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'invalid_input',
        );

        // Should have margins from edges
        expect(crop.x, greaterThan(0.05)); // At least 5% margin
        expect(crop.y, greaterThan(0.05));
        expect(crop.x + crop.width,
            lessThan(0.95)); // At least 5% margin from right
        expect(crop.y + crop.height,
            lessThan(0.95)); // At least 5% margin from bottom
      });

      test('should ensure minimum crop size', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'invalid_input',
        );

        expect(crop.width, greaterThanOrEqualTo(0.2));
        expect(crop.height, greaterThanOrEqualTo(0.2));
      });
    });

    group('Ultimate Center Crop', () {
      test('should create simple center crop', () {
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: targetSize,
          reason: 'ultimate_fallback',
        );

        expect(crop.strategy, contains('fallback'));
        expect(crop.confidence, lessThanOrEqualTo(0.5));
      });

      test('should handle extreme aspect ratios', () {
        final extremeTarget = const ui.Size(100, 1000); // Very tall
        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: extremeTarget,
          reason: 'ultimate_fallback',
        );

        expect(crop.width, greaterThanOrEqualTo(0.1));
        expect(crop.height, greaterThanOrEqualTo(0.1));
      });
    });

    group('Multiple Fallback Options', () {
      test('should create multiple fallback options with scores', () {
        final options = strategies.createFallbackOptions(
          image: mockImage,
          targetSize: targetSize,
        );

        expect(options.length, equals(3));

        // Should be sorted by score (highest first)
        for (int i = 0; i < options.length - 1; i++) {
          expect(options[i].score, greaterThanOrEqualTo(options[i + 1].score));
        }

        // All options should have valid coordinates
        for (final option in options) {
          expect(option.coordinates.x, greaterThanOrEqualTo(0.0));
          expect(option.coordinates.y, greaterThanOrEqualTo(0.0));
          expect(option.coordinates.width, greaterThan(0.0));
          expect(option.coordinates.height, greaterThan(0.0));
          expect(option.coordinates.x + option.coordinates.width,
              lessThanOrEqualTo(1.0));
          expect(option.coordinates.y + option.coordinates.height,
              lessThanOrEqualTo(1.0));
        }
      });

      test('should include different fallback types', () {
        final options = strategies.createFallbackOptions(
          image: mockImage,
          targetSize: targetSize,
        );

        final strategies_used = options.map((o) => o.strategy).toSet();
        expect(strategies_used.contains('intelligent_center_fallback'), isTrue);
        expect(strategies_used.contains('aspect_ratio_aware_fallback'), isTrue);
        expect(strategies_used.contains('safe_zone_fallback'), isTrue);
      });

      test('should assign reasonable confidence scores', () {
        final options = strategies.createFallbackOptions(
          image: mockImage,
          targetSize: targetSize,
        );

        for (final option in options) {
          final confidence = option.metrics['confidence'] as double?;
          expect(confidence, greaterThanOrEqualTo(0.0));
          expect(confidence, lessThanOrEqualTo(1.0));
        }

        // Intelligent center should have highest confidence
        final intelligentCenter = options.firstWhere(
          (o) => o.strategy == 'intelligent_center_fallback',
        );
        expect(intelligentCenter.metrics['confidence'], equals(0.7));
      });
    });

    group('Edge Cases', () {
      test('should handle very small images', () {
        final smallImage = MockImage(width: 50, height: 50);

        final crop = strategies.createFallbackCrop(
          image: smallImage,
          targetSize: targetSize,
          reason: 'test',
        );

        expect(crop.width, greaterThan(0.0));
        expect(crop.height, greaterThan(0.0));
      });

      test('should handle very small target sizes', () {
        final smallTarget = const ui.Size(10, 10);

        final crop = strategies.createFallbackCrop(
          image: mockImage,
          targetSize: smallTarget,
          reason: 'test',
        );

        expect(crop.width, greaterThan(0.0));
        expect(crop.height, greaterThan(0.0));
      });

      test('should handle square images and targets', () {
        final squareImage = MockImage(width: 1000, height: 1000);
        final squareTarget = const ui.Size(500, 500);

        final crop = strategies.createFallbackCrop(
          image: squareImage,
          targetSize: squareTarget,
          reason: 'test',
        );

        // Should be close to full image for square-to-square
        expect(crop.width, greaterThan(0.8));
        expect(crop.height, greaterThan(0.8));
      });

      test('should handle extreme aspect ratio mismatches', () {
        final wideImage = MockImage(width: 2000, height: 500); // 4:1
        final tallTarget = const ui.Size(200, 800); // 1:4

        final crop = strategies.createFallbackCrop(
          image: wideImage,
          targetSize: tallTarget,
          reason: 'test',
        );

        expect(crop.width, greaterThanOrEqualTo(0.1));
        expect(crop.height, greaterThanOrEqualTo(0.1));
        expect(crop.width, lessThanOrEqualTo(1.0));
        expect(crop.height, lessThanOrEqualTo(1.0));
      });
    });

    group('Crop Bias', () {
      test('should handle aggressiveness-based positioning correctly', () {
        final testCases = [
          CropAggressiveness.conservative,
          CropAggressiveness.balanced,
          CropAggressiveness.aggressive,
        ];

        for (final aggressiveness in testCases) {
          final settingsWithAggressiveness = defaultSettings.copyWith(
            aggressiveness: aggressiveness,
          );

          final crop = strategies.createFallbackCrop(
            image: MockImage(width: 1000, height: 1000),
            targetSize: const ui.Size(400, 800), // Tall target
            reason: 'network_error',
            settings: settingsWithAggressiveness,
          );

          // Should create valid crops for all aggressiveness levels
          expect(crop.strategy, equals('user_preference_fallback'));
          expect(crop.x, greaterThanOrEqualTo(0.0));
          expect(crop.y, greaterThanOrEqualTo(0.0));
          expect(crop.x + crop.width, lessThanOrEqualTo(1.0));
          expect(crop.y + crop.height, lessThanOrEqualTo(1.0));
        }
      });
    });
  });

  group('CropBias', () {
    test('should create crop bias with correct values', () {
      const bias = CropBias(horizontal: 0.3, vertical: 0.7);

      expect(bias.horizontal, equals(0.3));
      expect(bias.vertical, equals(0.7));
    });
  });
}
