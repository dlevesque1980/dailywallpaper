import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/engine/scoring_engine.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/registry/analyzer_registry.dart';
import '../../../fakes/fake_crop_analyzer.dart';

void main() {
  group('ScoringEngine', () {
    late AnalyzerRegistry registry;
    late ScoringEngine engine;

    setUp(() {
      registry = AnalyzerRegistry();
      registry.clear();
      engine = ScoringEngine(registry);
    });

    test('selectBestCrop picks the highest score', () {
      registry.registerAnalyzer(FakeCropAnalyzer('test', weight: 1.0));
      
      final scores = [
        CropScore(
          strategy: 'test',
          score: 0.5,
          coordinates: const CropCoordinates(x: 0, y: 0, width: 0.5, height: 0.5, confidence: 0.5, strategy: 'test'),
          metrics: const {},
        ),
        CropScore(
          strategy: 'test',
          score: 0.8,
          coordinates: const CropCoordinates(x: 0.1, y: 0.1, width: 0.5, height: 0.5, confidence: 0.8, strategy: 'test_best'),
          metrics: const {},
        ),
      ];

      final result = engine.selectBestCrop(scores, CropSettings.defaultSettings);
      expect(result.strategy, 'test_best');
    });

    test('selectBestCrop applies analyzer weight', () {
      registry.registerAnalyzer(FakeCropAnalyzer('weighted', weight: 0.5));
      registry.registerAnalyzer(FakeCropAnalyzer('normal', weight: 1.0));

      final scores = [
        CropScore(
          strategy: 'weighted',
          score: 0.9, // 0.9 * 0.5 = 0.45
          coordinates: const CropCoordinates(x: 0, y: 0, width: 0.5, height: 0.5, confidence: 0.9, strategy: 'weighted'),
          metrics: const {},
        ),
        CropScore(
          strategy: 'normal',
          score: 0.5, // 0.5 * 1.0 = 0.5
          coordinates: const CropCoordinates(x: 0.1, y: 0.1, width: 0.5, height: 0.5, confidence: 0.5, strategy: 'normal'),
          metrics: const {},
        ),
      ];

      final result = engine.selectBestCrop(scores, CropSettings.defaultSettings);
      expect(result.strategy, 'normal');
    });

    test('selectBestCrop applies consensus with center_weighted', () {
      registry.registerAnalyzer(FakeCropAnalyzer('other', weight: 1.0));
      registry.registerAnalyzer(FakeCropAnalyzer('center_weighted', weight: 1.0));

      final scores = [
        CropScore(
          strategy: 'other',
          score: 0.6,
          coordinates: const CropCoordinates(x: 0, y: 0, width: 0.5, height: 0.5, confidence: 0.6, strategy: 'other'),
          metrics: const {},
        ),
        CropScore(
          strategy: 'center_weighted',
          score: 0.55,
          coordinates: const CropCoordinates(x: 0.25, y: 0.25, width: 0.5, height: 0.5, confidence: 0.55, strategy: 'center_weighted'),
          metrics: const {},
        ),
      ];

      // 0.6 is not 1.15x higher than 0.55 (0.6 / 0.55 = ~1.09)
      final result = engine.selectBestCrop(scores, CropSettings.defaultSettings);
      expect(result.strategy, 'center_weighted_consensus');
    });

    test('selectBestCrop throws if scores are empty', () {
      expect(() => engine.selectBestCrop([], CropSettings.defaultSettings), throwsStateError);
    });
  });
}
