import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/composition/composition_scoring_logic.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

void main() {
  group('CompositionScoringLogic', () {
    test('scoreRuleOfThirds for perfect 1/3, 1/3 point', () {
      final crop = CropCoordinates(x: 1/3 - 0.25, y: 1/3 - 0.25, width: 0.5, height: 0.5, confidence: 1.0, strategy: 'test');
      final score = CompositionScoringLogic.scoreRuleOfThirds(crop);
      expect(score, closeTo(1.0, 0.01));
    });

    test('scoreRuleOfThirds for center point', () {
      final crop = CropCoordinates(x: 0.25, y: 0.25, width: 0.5, height: 0.5, confidence: 1.0, strategy: 'test');
      final score = CompositionScoringLogic.scoreRuleOfThirds(crop);
      // Distance from (0.5, 0.5) to (0.66, 0.66) or (0.33, 0.33) is ~0.23
      expect(score, lessThan(0.5));
    });

    test('scoreGoldenRatio for perfect golden ratio point', () {
      const g = CompositionScoringLogic.goldenRatio;
      final crop = CropCoordinates(x: g - 0.1, y: g - 0.1, width: 0.2, height: 0.2, confidence: 1.0, strategy: 'test');
      final score = CompositionScoringLogic.scoreGoldenRatio(crop);
      expect(score, closeTo(1.0, 0.01));
    });

    test('scoreComposition handles uniform image', () {
      final crop = CropCoordinates(x: 0.25, y: 0.25, width: 0.5, height: 0.5, confidence: 1.0, strategy: 'test');
      final size = const ui.Size(100, 100);
      final data = Uint8List(100 * 100 * 4); // All black
      
      final score = CompositionScoringLogic.scoreComposition(crop, size, data);
      expect(score, greaterThan(0.0));
      expect(score, lessThanOrEqualTo(1.0));
    });
  });
}
