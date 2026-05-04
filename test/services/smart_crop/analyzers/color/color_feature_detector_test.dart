import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/color/color_feature_detector.dart';

void main() {
  group('ColorFeatureDetector', () {
    test('rgbToHsv for red', () {
      final hsv = ColorFeatureDetector.rgbToHsv(255, 0, 0);
      expect(hsv.hue, 0.0);
      expect(hsv.saturation, 1.0);
      expect(hsv.value, 1.0);
    });

    test('rgbToHsv for green', () {
      final hsv = ColorFeatureDetector.rgbToHsv(0, 255, 0);
      expect(hsv.hue, 120.0);
      expect(hsv.saturation, 1.0);
      expect(hsv.value, 1.0);
    });

    test('rgbToHsv for blue', () {
      final hsv = ColorFeatureDetector.rgbToHsv(0, 0, 255);
      expect(hsv.hue, 240.0);
      expect(hsv.saturation, 1.0);
      expect(hsv.value, 1.0);
    });

    test('rgbToHsv for white', () {
      final hsv = ColorFeatureDetector.rgbToHsv(255, 255, 255);
      expect(hsv.saturation, 0.0);
      expect(hsv.value, 1.0);
    });

    test('rgbToHsv for black', () {
      final hsv = ColorFeatureDetector.rgbToHsv(0, 0, 0);
      expect(hsv.value, 0.0);
    });

    test('analyze handles simple image', () {
      final size = const ui.Size(16, 16);
      final data = Uint8List(16 * 16 * 4); // All black
      for (int i = 0; i < data.length; i += 4) {
        data[i + 3] = 255; // A
      }
      
      final analysis = ColorFeatureDetector.analyze(size, data);
      expect(analysis.dominantColors.length, 1);
      expect(analysis.vibrantRegions.isEmpty, true);
      expect(analysis.averageSaturation, 0.0);
    });

    test('analyze detects vibrant regions', () {
      final size = const ui.Size(16, 16);
      final data = Uint8List(16 * 16 * 4);
      // Half red (vibrant), half black
      for (int i = 0; i < data.length; i += 4) {
        if (i < data.length ~/ 2) { 
          data[i] = 255;
          data[i + 1] = 0;
          data[i + 2] = 0;
        } else {
          data[i] = 0;
          data[i + 1] = 0;
          data[i + 2] = 0;
        }
        data[i + 3] = 255;
      }
      
      final analysis = ColorFeatureDetector.analyze(size, data);
      expect(analysis.vibrantRegions.isNotEmpty, true);
      expect(analysis.averageSaturation, 0.5);
    });
  });
}
