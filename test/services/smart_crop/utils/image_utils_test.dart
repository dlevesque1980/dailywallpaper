import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

void main() {
  group('ImageUtils', () {
    group('validateAndClampCoordinates', () {
      test('should clamp coordinates within valid bounds', () {
        final coordinates = CropCoordinates(
          x: -0.1,
          y: 0.8, // Changed to allow some space for height
          width: 1.2,
          height: 0.8,
          confidence: 1.5,
          strategy: 'test',
        );

        final result = ImageUtils.validateAndClampCoordinates(coordinates, 100, 100);

        expect(result.x, equals(0.0));
        expect(result.y, equals(0.8));
        expect(result.width, equals(1.0)); // Full remaining width from x=0
        expect(result.height, closeTo(0.2, 0.001)); // Remaining height from y=0.8
        expect(result.confidence, equals(1.0));
      });

      test('should preserve valid coordinates', () {
        final coordinates = CropCoordinates(
          x: 0.2,
          y: 0.3,
          width: 0.5,
          height: 0.4,
          confidence: 0.8,
          strategy: 'test',
        );

        final result = ImageUtils.validateAndClampCoordinates(coordinates, 100, 100);

        expect(result.x, equals(0.2));
        expect(result.y, equals(0.3));
        expect(result.width, equals(0.5));
        expect(result.height, equals(0.4));
        expect(result.confidence, equals(0.8));
      });
    });

    group('areCoordinatesValid', () {
      test('should return true for valid coordinates', () {
        final coordinates = CropCoordinates(
          x: 0.2,
          y: 0.3,
          width: 0.5,
          height: 0.4,
          confidence: 0.8,
          strategy: 'test',
        );

        expect(ImageUtils.areCoordinatesValid(coordinates), isTrue);
      });

      test('should return false for invalid coordinates', () {
        final coordinates = CropCoordinates(
          x: -0.1,
          y: 0.3,
          width: 0.5,
          height: 0.4,
          confidence: 0.8,
          strategy: 'test',
        );

        expect(ImageUtils.areCoordinatesValid(coordinates), isFalse);
      });

      test('should return false when crop extends beyond bounds', () {
        final coordinates = CropCoordinates(
          x: 0.8,
          y: 0.3,
          width: 0.5, // x + width = 1.3 > 1.0
          height: 0.4,
          confidence: 0.8,
          strategy: 'test',
        );

        expect(ImageUtils.areCoordinatesValid(coordinates), isFalse);
      });
    });

    group('relativeToAbsolute', () {
      test('should convert relative coordinates to absolute pixels', () {
        final coordinates = CropCoordinates(
          x: 0.2,
          y: 0.3,
          width: 0.5,
          height: 0.4,
          confidence: 0.8,
          strategy: 'test',
        );

        final result = ImageUtils.relativeToAbsolute(coordinates, 1000, 800);

        expect(result, equals([200, 240, 500, 320]));
      });
    });

    group('absoluteToRelative', () {
      test('should convert absolute coordinates to relative', () {
        final result = ImageUtils.absoluteToRelative(
          200, 240, 500, 320, 1000, 800, 'test', 0.8,
        );

        expect(result.x, closeTo(0.2, 0.001));
        expect(result.y, closeTo(0.3, 0.001));
        expect(result.width, closeTo(0.5, 0.001));
        expect(result.height, closeTo(0.4, 0.001));
        expect(result.confidence, equals(0.8));
        expect(result.strategy, equals('test'));
      });
    });

    group('calculateLuminance', () {
      test('should calculate correct luminance for white', () {
        final luminance = ImageUtils.calculateLuminance(255, 255, 255);
        expect(luminance, equals(1.0));
      });

      test('should calculate correct luminance for black', () {
        final luminance = ImageUtils.calculateLuminance(0, 0, 0);
        expect(luminance, equals(0.0));
      });

      test('should calculate correct luminance for gray', () {
        final luminance = ImageUtils.calculateLuminance(128, 128, 128);
        expect(luminance, closeTo(0.502, 0.001));
      });
    });

    group('calculateCropArea', () {
      test('should calculate correct crop area', () {
        final coordinates = CropCoordinates(
          x: 0.2,
          y: 0.3,
          width: 0.5,
          height: 0.4,
          confidence: 0.8,
          strategy: 'test',
        );

        final area = ImageUtils.calculateCropArea(coordinates);
        expect(area, equals(0.2)); // 0.5 * 0.4
      });
    });

    group('calculateCropCenter', () {
      test('should calculate correct crop center', () {
        final coordinates = CropCoordinates(
          x: 0.2,
          y: 0.3,
          width: 0.4,
          height: 0.2,
          confidence: 0.8,
          strategy: 'test',
        );

        final center = ImageUtils.calculateCropCenter(coordinates);
        expect(center[0], equals(0.4)); // 0.2 + 0.4/2
        expect(center[1], equals(0.4)); // 0.3 + 0.2/2
      });
    });

    group('calculateCropAspectRatio', () {
      test('should calculate correct aspect ratio', () {
        final coordinates = CropCoordinates(
          x: 0.2,
          y: 0.3,
          width: 0.8,
          height: 0.4,
          confidence: 0.8,
          strategy: 'test',
        );

        final aspectRatio = ImageUtils.calculateCropAspectRatio(coordinates);
        expect(aspectRatio, equals(2.0)); // 0.8 / 0.4
      });
    });

    group('createCenterCrop', () {
      test('should create center crop for landscape aspect ratio', () {
        final crop = ImageUtils.createCenterCrop(2.0, 'center', 0.9);

        expect(crop.x, equals(0.0));
        expect(crop.y, equals(0.25));
        expect(crop.width, equals(1.0));
        expect(crop.height, equals(0.5));
        expect(crop.confidence, equals(0.9));
        expect(crop.strategy, equals('center'));
      });

      test('should create center crop for portrait aspect ratio', () {
        final crop = ImageUtils.createCenterCrop(0.5, 'center', 0.9);

        expect(crop.x, equals(0.25));
        expect(crop.y, equals(0.0));
        expect(crop.width, equals(0.5));
        expect(crop.height, equals(1.0));
        expect(crop.confidence, equals(0.9));
        expect(crop.strategy, equals('center'));
      });
    });
  });
}