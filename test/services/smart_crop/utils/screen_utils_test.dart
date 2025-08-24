import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/screen_utils.dart';
import 'dart:ui' as ui;

void main() {
  group('ScreenUtils', () {
    group('calculateTargetSize', () {
      test('should calculate target size for wider source', () {
        final sourceSize = ui.Size(1920, 1080); // 16:9
        final targetAspectRatio = 4.0 / 3.0; // 4:3

        final result = ScreenUtils.calculateTargetSize(sourceSize, targetAspectRatio);

        expect(result.width, closeTo(1440, 0.1)); // 1080 * 4/3
        expect(result.height, equals(1080));
      });

      test('should calculate target size for taller source', () {
        final sourceSize = ui.Size(1080, 1920); // 9:16
        final targetAspectRatio = 16.0 / 9.0; // 16:9

        final result = ScreenUtils.calculateTargetSize(sourceSize, targetAspectRatio);

        expect(result.width, equals(1080));
        expect(result.height, closeTo(607.5, 0.1)); // 1080 / (16/9)
      });

      test('should respect maximum dimension constraint', () {
        final sourceSize = ui.Size(4000, 3000);
        final targetAspectRatio = 16.0 / 9.0;

        final result = ScreenUtils.calculateTargetSize(
          sourceSize,
          targetAspectRatio,
          maxDimension: 1000,
        );

        expect(result.width, lessThanOrEqualTo(1000));
        expect(result.height, lessThanOrEqualTo(1000));
        expect(result.width / result.height, closeTo(16.0 / 9.0, 0.01));
      });

      test('should throw for invalid source size', () {
        expect(
          () => ScreenUtils.calculateTargetSize(ui.Size(0, 100), 16.0 / 9.0),
          throwsArgumentError,
        );
      });
    });

    group('findClosestAspectRatio', () {
      test('should find exact match', () {
        final result = ScreenUtils.findClosestAspectRatio(16.0 / 9.0);

        expect(result.key, equals('16:9'));
        expect(result.value, equals(16.0 / 9.0));
      });

      test('should find closest match within tolerance', () {
        final result = ScreenUtils.findClosestAspectRatio(1.78); // Close to 16:9

        expect(result.key, equals('16:9'));
        expect(result.value, equals(16.0 / 9.0));
      });

      test('should return custom for no close match', () {
        final customRatio = 10.0;
        final result = ScreenUtils.findClosestAspectRatio(customRatio);

        expect(result.key, equals('custom'));
        expect(result.value, equals(customRatio));
      });
    });

    group('isUltraWideRatio', () {
      test('should identify ultra-wide ratios', () {
        expect(ScreenUtils.isUltraWideRatio(21.0 / 9.0), isTrue);
        expect(ScreenUtils.isUltraWideRatio(3.0), isTrue);
        expect(ScreenUtils.isUltraWideRatio(16.0 / 9.0), isFalse);
        expect(ScreenUtils.isUltraWideRatio(1.5), isFalse);
      });
    });

    group('isTallRatio', () {
      test('should identify tall ratios', () {
        expect(ScreenUtils.isTallRatio(9.0 / 16.0), isTrue);
        expect(ScreenUtils.isTallRatio(0.8), isTrue);
        expect(ScreenUtils.isTallRatio(16.0 / 9.0), isFalse);
        expect(ScreenUtils.isTallRatio(1.2), isFalse);
      });
    });

    group('calculateCropFactor', () {
      test('should return 1.0 for matching aspect ratios', () {
        final sourceSize = ui.Size(1920, 1080);
        final targetRatio = 16.0 / 9.0;

        final factor = ScreenUtils.calculateCropFactor(sourceSize, targetRatio);

        expect(factor, closeTo(1.0, 0.01));
      });

      test('should return less than 1.0 when cropping is needed', () {
        final sourceSize = ui.Size(1920, 1080); // 16:9
        final targetRatio = 4.0 / 3.0; // 4:3

        final factor = ScreenUtils.calculateCropFactor(sourceSize, targetRatio);

        expect(factor, lessThan(1.0));
      });
    });

    group('getFallbackCropCoordinates', () {
      test('should create center crop for wider source', () {
        final sourceSize = ui.Size(1920, 1080); // 16:9
        final targetRatio = 4.0 / 3.0; // 4:3

        final coords = ScreenUtils.getFallbackCropCoordinates(sourceSize, targetRatio);

        expect(coords[0], greaterThan(0)); // x > 0 (cropped from sides)
        expect(coords[1], equals(0.0)); // y = 0 (full height)
        expect(coords[2], lessThan(1.0)); // width < 1.0 (cropped)
        expect(coords[3], equals(1.0)); // height = 1.0 (full height)
      });

      test('should create center crop for taller source', () {
        final sourceSize = ui.Size(1080, 1920); // 9:16
        final targetRatio = 16.0 / 9.0; // 16:9

        final coords = ScreenUtils.getFallbackCropCoordinates(sourceSize, targetRatio);

        expect(coords[0], equals(0.0)); // x = 0 (full width)
        expect(coords[1], greaterThan(0)); // y > 0 (cropped from top/bottom)
        expect(coords[2], equals(1.0)); // width = 1.0 (full width)
        expect(coords[3], lessThan(1.0)); // height < 1.0 (cropped)
      });
    });

    group('isValidAspectRatio', () {
      test('should validate reasonable aspect ratios', () {
        expect(ScreenUtils.isValidAspectRatio(16.0 / 9.0), isTrue);
        expect(ScreenUtils.isValidAspectRatio(9.0 / 16.0), isTrue);
        expect(ScreenUtils.isValidAspectRatio(1.0), isTrue);
        expect(ScreenUtils.isValidAspectRatio(21.0 / 9.0), isTrue);
      });

      test('should reject extreme aspect ratios', () {
        expect(ScreenUtils.isValidAspectRatio(0.05), isFalse);
        expect(ScreenUtils.isValidAspectRatio(15.0), isFalse);
        expect(ScreenUtils.isValidAspectRatio(double.infinity), isFalse);
        expect(ScreenUtils.isValidAspectRatio(double.nan), isFalse);
      });
    });

    group('getOrientation', () {
      test('should identify orientations correctly', () {
        expect(ScreenUtils.getOrientation(16.0 / 9.0), equals('landscape'));
        expect(ScreenUtils.getOrientation(9.0 / 16.0), equals('portrait'));
        expect(ScreenUtils.getOrientation(1.0), equals('square'));
        expect(ScreenUtils.getOrientation(1.01), equals('landscape')); // Further from square
      });
    });

    group('getOptimalAnalysisSize', () {
      test('should return original size if within limits', () {
        final sourceSize = ui.Size(400, 300);
        final result = ScreenUtils.getOptimalAnalysisSize(sourceSize);

        expect(result, equals(sourceSize));
      });

      test('should scale down large landscape images', () {
        final sourceSize = ui.Size(2000, 1000);
        final result = ScreenUtils.getOptimalAnalysisSize(sourceSize, maxAnalysisSize: 512);

        expect(result.width, equals(512));
        expect(result.height, equals(256));
      });

      test('should scale down large portrait images', () {
        final sourceSize = ui.Size(1000, 2000);
        final result = ScreenUtils.getOptimalAnalysisSize(sourceSize, maxAnalysisSize: 512);

        expect(result.width, equals(256));
        expect(result.height, equals(512));
      });
    });
  });
}