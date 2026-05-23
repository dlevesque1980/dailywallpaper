import 'dart:async';
import 'dart:ui' as ui;
import 'package:dailywallpaper/features/smart_crop/interfaces/analysis_context.dart';
import 'package:dailywallpaper/features/smart_crop/interfaces/crop_analyzer.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_score.dart';

/// If ML Subject returns a score at or above this threshold, we skip the
/// parallel group entirely — ML Kit already found an excellent crop.
const double _earlyExitThreshold = 0.90;

/// Runner that executes analyzers in the optimal order:
///
/// **Execution order:**
/// 1. Exclusive analyzers (ML Subject) run **first**, one at a time.
///    - ML Subject is the highest-quality analyzer (weight 0.85).
///    - If its score ≥ [_earlyExitThreshold], we return immediately without
///      running the rest — saving the full parallel group cost.
///    - If ML Subject fails, times out, or scores below the threshold,
///      we continue to the parallel group.
/// 2. All remaining (parallel-safe) analyzers run concurrently via
///    `Future.wait()`.
/// 3. All collected scores are returned to the ScoringEngine, which picks
///    the overall winner regardless of which group produced it.
///
/// **Grouping logic:**
///   • Exclusive — `CropAnalyzerV2` where `metadata.isMemoryIntensive == true`
///                 (currently only `MlSubjectCropAnalyzer`, due to ML Kit
///                 native singleton — concurrent calls cause SIGSEGV).
///   • Parallel  — everything else (pure-Dart Isolate work, always safe).
class AnalyzerRunner {
  Future<List<CropScore>> runAnalyzers({
    required ui.Image image,
    required ui.Size targetSize,
    required AnalysisContext context,
    required List<CropAnalyzer> analyzers,
    void Function(String name)? onAnalyzerStarted,
    void Function(String name, Duration duration, bool success)?
        onAnalyzerFinished,
  }) async {
    // Split into exclusive (ML Kit) and parallel (everyone else).
    final exclusive = <CropAnalyzer>[];
    final parallel = <CropAnalyzer>[];

    for (final analyzer in analyzers) {
      if (_requiresExclusiveExecution(analyzer)) {
        exclusive.add(analyzer);
      } else {
        parallel.add(analyzer);
      }
    }

    // ── Step 1 : Exclusive analyzers first (ML Subject) ───────────────────
    final exclusiveScores = <CropScore>[];
    for (final analyzer in exclusive) {
      if (context.hasExceededTimeout) break;

      final score = await _runSingle(
        analyzer: analyzer,
        image: image,
        targetSize: targetSize,
        context: context,
        onAnalyzerStarted: onAnalyzerStarted,
        onAnalyzerFinished: onAnalyzerFinished,
      );

      if (score != null) {
        exclusiveScores.add(score);

        // Early exit: ML Subject nailed it — skip the entire parallel group.
        if (score.score >= _earlyExitThreshold) {
          return exclusiveScores;
        }
      }
    }

    // ── Step 2 : Parallel group (ML Subject failed or scored below threshold)
    final parallelScores = <CropScore>[];
    if (parallel.isNotEmpty && !context.hasExceededTimeout) {
      final futures = parallel.map(
        (a) => _runSingle(
          analyzer: a,
          image: image,
          targetSize: targetSize,
          context: context,
          onAnalyzerStarted: onAnalyzerStarted,
          onAnalyzerFinished: onAnalyzerFinished,
        ),
      );

      final results = await Future.wait(futures, eagerError: false);
      for (final score in results) {
        if (score != null) parallelScores.add(score);
      }
    }

    // Combine both groups — ScoringEngine picks the winner.
    return [...exclusiveScores, ...parallelScores];
  }

  // ── Internals ──────────────────────────────────────────────────────────────

  /// An analyzer requires exclusive (non-concurrent) execution when it uses a
  /// native singleton that cannot handle concurrent calls (e.g. ML Kit subject
  /// segmentation). We use isMemoryIntensive as the marker since only ML Subject
  /// sets it to true.
  bool _requiresExclusiveExecution(CropAnalyzer analyzer) {
    if (analyzer is CropAnalyzerV2) {
      return analyzer.metadata.isMemoryIntensive;
    }
    return false; // v1 analyzers are pure-Dart, always parallel-safe.
  }

  /// Runs a single analyzer and returns its score (or null on error/skip).
  Future<CropScore?> _runSingle({
    required CropAnalyzer analyzer,
    required ui.Image image,
    required ui.Size targetSize,
    required AnalysisContext context,
    void Function(String name)? onAnalyzerStarted,
    void Function(String name, Duration duration, bool success)?
        onAnalyzerFinished,
  }) async {
    final analyzerName =
        analyzer is CropAnalyzerV2 ? analyzer.name : analyzer.strategyName;

    try {
      onAnalyzerStarted?.call(analyzerName);
      final stopwatch = Stopwatch()..start();

      final score = analyzer is CropAnalyzerV2
          ? await analyzer.analyzeWithContext(image, targetSize, context)
          : await analyzer.analyze(image, targetSize);

      stopwatch.stop();
      onAnalyzerFinished?.call(analyzerName, stopwatch.elapsed, true);

      if (score.isValid && score.score >= analyzer.minConfidenceThreshold) {
        return score;
      }
      return null;
    } catch (e) {
      onAnalyzerFinished?.call(analyzerName, Duration.zero, false);
      return null;
    }
  }
}
