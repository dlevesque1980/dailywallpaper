import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/color/color_scoring_logic.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/color/color_feature_detector.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

void main() {
  group('ColorScoringLogic', () {
    final analysis = ImageColorAnalysis(
      dominantColors: [],
      vibrantRegions: [],
      averageSaturation: 0.5,
      averageBrightness: 0.5,
      colorVariety: 1.0,
    );

    test('scoreColorCrop handles black image', () {
      final crop = const CropCoordinates(x: 0.25, y: 0.25, width: 0.5, height: 0.5, confidence: 1.0, strategy: 'test');
      final size = const ui.Size(10, 10);
      final data = Uint8List(10 * 10 * 4); // All black
      for (int i = 0; i < data.length; i += 4) {
        data[i + 3] = 255;
      }
      
      final score = ColorScoringLogic.scoreColorCrop(crop, size, data, analysis);
      expect(score, 0.0);
    });

    test('scoreColorCrop handles colorful image', () {
      final crop = const CropCoordinates(x: 0.0, y: 0.0, width: 1.0, height: 1.0, confidence: 1.0, strategy: 'test');
      final size = const ui.Size(10, 10);
      final data = Uint8List(10 * 10 * 4);
      // Red pixels
      for (int i = 0; i < data.length; i += 4) {
        data[i] = 255;
        data[i + 3] = 255;
      }
      
      final score = ColorScoringLogic.scoreColorCrop(crop, size, data, analysis);
      expect(score, greaterThan(0.3)); // Should have some vibrancy score
    });
  });
}
