import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/bird/bird_feature_detector.dart';

void main() {
  group('BirdFeatureDetector', () {
    test('detectBirds handles empty image', () {
      final size = const ui.Size(64, 64);
      final data = Uint8List(64 * 64 * 4); // All black
      for (int i = 0; i < data.length; i += 4) {
        data[i + 3] = 255;
      }
      
      final birds = BirdFeatureDetector.detectBirds(size, data);
      expect(birds.isEmpty, true);
    });

    // Note: Creating a synthetic bird image is complex due to _calculateHeadScore and _detectBeak logic.
    // We'll focus on ensuring it doesn't crash and handles basic empty scenarios for now.
    // In a real scenario, we might want to mock the private methods or use small test fixtures.
  });
}
