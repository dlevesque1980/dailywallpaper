import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/analyzers.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/crop_analyzer.dart';
import 'dart:ui' as ui;

void main() {
  group('Unified Analyzer Tests', () {
    late ui.Image testImage;
    late List<CropAnalyzer> analyzers;

    setUpAll(() async {
      // Create test image once
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = const ui.Color(0xFF000000);
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 100, 100), paint);
      final picture = recorder.endRecording();
      testImage = await picture.toImage(100, 100);

      // Initialize all analyzers
      analyzers = [
        RuleOfThirdsCropAnalyzer(),
        CenterWeightedCropAnalyzer(),
        EntropyBasedCropAnalyzer(),
        ColorCropAnalyzer(),
        FaceDetectionCropAnalyzer(),
        ObjectDetectionCropAnalyzer(),
        EnhancedCompositionCropAnalyzer(),
      ];
    });

    test('all analyzers should produce valid results', () async {
      const targetSize = ui.Size(50, 50);

      for (final analyzer in analyzers) {
        final result = await analyzer.analyze(testImage, targetSize);

        expect(result.isValid, isTrue,
            reason: '${analyzer.strategyName} should produce valid result');
        expect(result.score, greaterThanOrEqualTo(0.0),
            reason: '${analyzer.strategyName} score should be non-negative');
        expect(result.score, lessThanOrEqualTo(1.0),
            reason: '${analyzer.strategyName} score should be <= 1.0');
      }
    }, tags: ['unit']);

    test('all analyzers should handle edge cases', () async {
      const edgeCases = [
        ui.Size(1, 1), // Tiny target
        ui.Size(200, 200), // Larger than source
        ui.Size(50, 25), // Different aspect ratio
      ];

      for (final targetSize in edgeCases) {
        for (final analyzer in analyzers) {
          final result = await analyzer.analyze(testImage, targetSize);
          expect(result, isNotNull,
              reason: '${analyzer.strategyName} should handle $targetSize');
        }
      }
    }, tags: ['unit']);

    test('analyzers should complete within time limits', () async {
      const targetSize = ui.Size(50, 50);

      for (final analyzer in analyzers) {
        final stopwatch = Stopwatch()..start();
        await analyzer.analyze(testImage, targetSize);
        stopwatch.stop();

        expect(stopwatch.elapsedMilliseconds, lessThan(1000),
            reason: '${analyzer.strategyName} should complete within 1s');
      }
    }, tags: ['unit']);
  });
}
