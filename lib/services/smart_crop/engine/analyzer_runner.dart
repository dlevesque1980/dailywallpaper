import 'dart:async';
import 'dart:ui' as ui;
import 'package:dailywallpaper/services/smart_crop/interfaces/analysis_context.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';

class AnalyzerRunner {
  Future<List<CropScore>> runAnalyzers({
    required ui.Image image,
    required ui.Size targetSize,
    required AnalysisContext context,
    required List<CropAnalyzer> analyzers,
    void Function(String name)? onAnalyzerStarted,
    void Function(String name, Duration duration, bool success)? onAnalyzerFinished,
  }) async {
    final scores = <CropScore>[];

    for (final analyzer in analyzers) {
      if (context.hasExceededTimeout) break;

      // Yield to UI thread
      await Future.delayed(Duration.zero);

      try {
        final analyzerName = analyzer is CropAnalyzerV2 ? analyzer.name : analyzer.strategyName;
        onAnalyzerStarted?.call(analyzerName);

        final stopwatch = Stopwatch()..start();
        
        final score = analyzer is CropAnalyzerV2
            ? await analyzer.analyzeWithContext(image, targetSize, context)
            : await analyzer.analyze(image, targetSize);

        stopwatch.stop();
        onAnalyzerFinished?.call(analyzerName, stopwatch.elapsed, true);

        if (score.isValid && score.score >= analyzer.minConfidenceThreshold) {
          scores.add(score);
        }
      } catch (e) {
        onAnalyzerFinished?.call(analyzer is CropAnalyzerV2 ? analyzer.name : analyzer.strategyName, Duration.zero, false);
      }
    }

    return scores;
  }
}
