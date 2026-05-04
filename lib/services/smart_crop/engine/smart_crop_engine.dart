import 'dart:async';
import 'dart:ui' as ui;

import '../interfaces/crop_analyzer.dart';
import '../interfaces/analysis_context.dart';
import '../models/crop_coordinates.dart';
import '../models/crop_score.dart';
import '../models/crop_result.dart';
import '../models/crop_settings.dart';
import '../registry/analyzer_registry.dart';
import '../utils/error_handler.dart';
import '../utils/degradation_manager.dart';
import '../utils/fallback_strategies.dart';
import '../analyzers/analyzers.dart';
import 'analyzer_runner.dart';
import 'scoring_engine.dart';
import 'crop_post_processor.dart';

/// Exception thrown when crop analysis fails
class CropAnalysisException implements Exception {
  final String message;
  final String? imageId;
  final Object? cause;

  const CropAnalysisException(this.message, [this.imageId, this.cause]);

  @override
  String toString() =>
      "CropAnalysisException: $message${imageId != null ? ' (imageId: $imageId)' : ''}${cause != null ? ' (cause: $cause)' : ''}";
}

/// Main orchestrator class for Smart Crop v2 analysis
class SmartCropEngine {
  static final SmartCropEngine _instance = SmartCropEngine._internal();
  factory SmartCropEngine() => _instance;
  SmartCropEngine._internal() 
      : _registry = AnalyzerRegistry(),
        _runner = AnalyzerRunner(),
        _postProcessor = CropPostProcessor() {
    _scoringEngine = ScoringEngine(_registry);
  }

  final AnalyzerRegistry _registry;
  final SmartCropErrorHandler _errorHandler = SmartCropErrorHandler();
  final DegradationManager _degradationManager = DegradationManager();
  final FallbackCropStrategies _fallbackStrategies = FallbackCropStrategies();
  final AnalyzerRunner _runner;
  late final ScoringEngine _scoringEngine;
  final CropPostProcessor _postProcessor;

  bool _isInitialized = false;
  final Map<String, dynamic> _engineStats = {};

  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      _registry.registerAnalyzer(FaceDetectionCropAnalyzer());
      _registry.registerAnalyzer(ObjectDetectionCropAnalyzer());
      _registry.registerAnalyzer(BirdDetectionCropAnalyzer());
      _registry.registerAnalyzer(SubjectDetectionCropAnalyzer());
      _registry.registerAnalyzer(LandscapeAwareCropAnalyzer());
      _registry.registerAnalyzer(RuleOfThirdsCropAnalyzer());
      _registry.registerAnalyzer(CenterWeightedCropAnalyzer());
      _registry.registerAnalyzer(EntropyBasedCropAnalyzer());
      _registry.registerAnalyzer(EdgeDetectionCropAnalyzer());
      _registry.registerAnalyzer(MlSubjectCropAnalyzer());

      _isInitialized = true;
      _engineStats['initialized_at'] = DateTime.now().toIso8601String();
      _engineStats['total_analyses'] = 0;
      _engineStats['successful_analyses'] = 0;
      _engineStats['failed_analyses'] = 0;
    } catch (e) {
      throw CropAnalysisException('Failed to initialize SmartCropEngine', null, e);
    }
  }

  Future<CropResult> analyzeCrop({
    required String imageId,
    required ui.Image image,
    required ui.Size targetSize,
    CropSettings? settings,
    Map<String, dynamic>? metadata,
  }) async {
    _ensureInitialized();
    final analysisSettings = settings ?? CropSettings.defaultSettings;
    final stopwatch = Stopwatch()..start();

    _engineStats['total_analyses'] = (_engineStats['total_analyses'] as int? ?? 0) + 1;

    try {
      final recentErrors = _errorHandler.getRecentErrors(within: const Duration(minutes: 5));
      final degradationLevel = _degradationManager.assessDegradationNeeds(
        image: image,
        settings: analysisSettings,
        recentErrors: recentErrors,
      );

      final effectiveSettings = degradationLevel != DegradationLevel.none
          ? _degradationManager.createDegradedSettings(analysisSettings, degradationLevel)
          : analysisSettings;

      final context = AnalysisContext(imageId: imageId, settings: effectiveSettings, metadata: metadata ?? {});

      if (_shouldSkipSmartCrop(image, targetSize, effectiveSettings)) {
        stopwatch.stop();
        final fallback = _createFallback(image, targetSize, 'skipped', effectiveSettings);
        return _createResult(fallback, [], stopwatch.elapsed, false, {'skipped': true});
      }

      var analyzers = _registry.getCompatibleAnalyzers(image, effectiveSettings);
      analyzers = _degradationManager.filterAnalyzers(analyzers, degradationLevel, image, effectiveSettings);

      if (analyzers.isEmpty) {
        stopwatch.stop();
        final fallback = _createFallback(image, targetSize, 'no_analyzers', effectiveSettings);
        return _createResult(fallback, [], stopwatch.elapsed, false, {'no_analyzers': true});
      }

      final scores = await _runner.runAnalyzers(
        image: image,
        targetSize: targetSize,
        context: context,
        analyzers: analyzers,
        onAnalyzerStarted: (name) => _registry.recordUsage(name),
      );

      if (scores.isEmpty) {
        stopwatch.stop();
        final fallback = _createFallback(image, targetSize, 'failed', effectiveSettings);
        return _createResult(fallback, [], stopwatch.elapsed, false, {'analysis_failed': true});
      }

      var bestCrop = _scoringEngine.selectBestCrop(scores, effectiveSettings);
      bestCrop = _postProcessor.postProcess(
        bestCrop: bestCrop,
        allScores: scores,
        image: image,
        targetSize: targetSize,
        settings: effectiveSettings,
      );

      stopwatch.stop();
      _engineStats['successful_analyses'] = (_engineStats['successful_analyses'] as int? ?? 0) + 1;

      return _createResult(bestCrop, scores, stopwatch.elapsed, false, {'success': true});
    } catch (e, stackTrace) {
      stopwatch.stop();
      _errorHandler.recordError(CropError.fromException(e, stackTrace, imageId: imageId));
      _engineStats['failed_analyses'] = (_engineStats['failed_analyses'] as int? ?? 0) + 1;

      final fallback = _createFallback(image, targetSize, 'error', settings);
      return _createResult(fallback, [], stopwatch.elapsed, false, {'error': e.toString()});
    }
  }

  bool _shouldSkipSmartCrop(ui.Image image, ui.Size targetSize, CropSettings settings) {
    return image.width < 100 || image.height < 100 || targetSize.width < 50 || targetSize.height < 50;
  }

  CropCoordinates _createFallback(ui.Image image, ui.Size targetSize, String reason, CropSettings? settings) {
    return _fallbackStrategies.createFallbackCrop(image: image, targetSize: targetSize, reason: reason, settings: settings);
  }

  CropResult _createResult(CropCoordinates best, List<CropScore> all, Duration time, bool fromCache, Map<String, dynamic> meta) {
    return CropResult(
      bestCrop: best,
      allScores: all,
      processingTime: time,
      fromCache: fromCache,
      analyzerMetadata: meta,
      performanceMetrics: PerformanceMetrics(totalTime: time, analyzerTimes: {}, memoryUsage: 0, analyzersExecuted: all.length, analyzersSkipped: 0, cacheHitRate: fromCache ? 1.0 : 0.0),
      scoringBreakdown: {for (var s in all) s.strategy: s.score},
    );
  }

  void _ensureInitialized() {
    if (!_isInitialized) throw StateError('SmartCropEngine not initialized');
  }
}
