import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/engine/analyzer_runner.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/analysis_context.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import '../../../fakes/fake_crop_analyzer.dart';
import '../../../fakes/fake_image.dart';

class MockAnalyzerWithScore extends FakeCropAnalyzer {
  final CropScore score;
  MockAnalyzerWithScore(String name, this.score) : super(name);

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    return score;
  }
}

void main() {
  group('AnalyzerRunner', () {
    late AnalyzerRunner runner;
    late AnalysisContext context;
    late ui.Image image;
    final targetSize = const ui.Size(100, 100);

    setUp(() {
      runner = AnalyzerRunner();
      context = AnalysisContext(
        imageId: 'test',
        settings: CropSettings.defaultSettings,
        metadata: {},
      );
      image = FakeImage(width: 100, height: 100);
    });

    test('runAnalyzers collects scores from analyzers', () async {
      final score1 = CropScore(
        strategy: 'a1',
        score: 0.8,
        coordinates: const CropCoordinates(x: 0, y: 0, width: 0.5, height: 0.5, confidence: 0.8, strategy: 'a1'),
        metrics: const {},
      );
      final analyzers = [
        MockAnalyzerWithScore('a1', score1),
      ];

      final result = await runner.runAnalyzers(
        image: image,
        targetSize: targetSize,
        context: context,
        analyzers: analyzers,
      );

      expect(result.length, 1);
      expect(result.first.strategy, 'a1');
    });

    test('runAnalyzers respects timeout', () async {
      final settings = CropSettings.defaultSettings.copyWith(
        maxProcessingTime: const Duration(milliseconds: 1),
      );
      context = context.copyWith(settings: settings, startTime: DateTime.now().subtract(const Duration(seconds: 1)));
      
      final analyzers = [
        MockAnalyzerWithScore('a1', CropScore.empty('a1')),
      ];

      final result = await runner.runAnalyzers(
        image: image,
        targetSize: targetSize,
        context: context,
        analyzers: analyzers,
      );

      expect(result.isEmpty, true);
    });
  });
}
