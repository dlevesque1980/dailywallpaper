import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/landscape/landscape_feature_detector.dart';

void main() {
  group('LandscapeFeatureDetector', () {
    test('detectHorizon finds sharp transition', () {
      final size = const ui.Size(16, 32);
      final data = Uint8List(16 * 32 * 4);
      // Top half white, bottom half black
      for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 16; x++) {
          final idx = (y * 16 + x) * 4;
          if (y < 16) {
            data[idx] = data[idx+1] = data[idx+2] = 255;
          } else {
            data[idx] = data[idx+1] = data[idx+2] = 0;
          }
          data[idx + 3] = 255;
        }
      }
      
      final horizon = LandscapeFeatureDetector.detectHorizon(size, data);
      // Transition is at y=16 (index 16 / 32 = 0.5)
      expect(horizon, closeTo(0.5, 0.1));
    });

    test('detectSubjectAreas finds high variance areas', () {
      final size = const ui.Size(32, 32);
      final data = Uint8List(32 * 32 * 4);
      // All white except one 8x8 block with noise
      for (int y = 0; y < 32; y++) {
        for (int x = 0; x < 32; x++) {
          final idx = (y * 32 + x) * 4;
          if (y >= 8 && y < 16 && x >= 8 && x < 16) {
            data[idx] = (x + y) % 2 == 0 ? 255 : 0;
            data[idx+1] = (x + y) % 2 == 0 ? 255 : 0;
            data[idx+2] = (x + y) % 2 == 0 ? 255 : 0;
          } else {
            data[idx] = 255;
            data[idx+1] = 255;
            data[idx+2] = 255;
          }
          data[idx + 3] = 255;
        }
      }
      
      final areas = LandscapeFeatureDetector.detectSubjectAreas(size, data);
      expect(areas.isNotEmpty, true);
    });
  });
}
