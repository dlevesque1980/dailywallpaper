import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

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
import '../utils/subject_fit_checker.dart';
import '../analyzers/analyzers.dart';
// import '../utils/performance_monitor.dart'; // TODO: Implement performance monitoring

/// Exception thrown when crop analysis fails
class CropAnalysisException implements Exception {
  final String message;
  final String? imageId;
  final Object? cause;

  const CropAnalysisException(this.message, [this.imageId, this.cause]);

  @override
  String toString() =>
      'CropAnalysisException: $message${imageId != null ? ' (imageId: $imageId)' : ''}${cause != null ? ' (cause: $cause)' : ''}';
}

/// Main orchestrator class for Smart Crop v2 analysis
class SmartCropEngine {
  static final SmartCropEngine _instance = SmartCropEngine._internal();
  factory SmartCropEngine() => _instance;
  SmartCropEngine._internal();

  final AnalyzerRegistry _registry = AnalyzerRegistry();
  final SmartCropErrorHandler _errorHandler = SmartCropErrorHandler();
  final DegradationManager _degradationManager = DegradationManager();
  final FallbackCropStrategies _fallbackStrategies = FallbackCropStrategies();
  // final PerformanceMonitor _performanceMonitor = PerformanceMonitor(); // TODO: Implement performance monitoring

  bool _isInitialized = false;
  final Map<String, dynamic> _engineStats = {};
  final List<Duration> _recentProcessingTimes = [];

  /// Whether the engine is initialized
  bool get isInitialized => _isInitialized;

  /// Initializes the engine with default analyzers
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Register built-in analyzers
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

      // For now, we'll mark as initialized
      _isInitialized = true;

      _engineStats['initialized_at'] = DateTime.now().toIso8601String();
      _engineStats['total_analyses'] = 0;
      _engineStats['successful_analyses'] = 0;
      _engineStats['failed_analyses'] = 0;
    } catch (e) {
      throw CropAnalysisException(
          'Failed to initialize SmartCropEngine', null, e);
    }
  }

  /// Registers a new crop analyzer
  void registerAnalyzer(CropAnalyzer analyzer) {
    _ensureInitialized();
    _registry.registerAnalyzer(analyzer);
  }

  /// Unregisters an analyzer
  bool unregisterAnalyzer(String name) {
    _ensureInitialized();
    return _registry.unregisterAnalyzer(name);
  }

  /// Main crop analysis method with comprehensive error handling and graceful degradation
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

    // Update stats
    _engineStats['total_analyses'] =
        (_engineStats['total_analyses'] as int? ?? 0) + 1;

    try {
      // Validate inputs with enhanced error handling
      _validateInputsWithErrorHandling(
          image, targetSize, analysisSettings, imageId);

      // Assess degradation needs
      final recentProcessingTime = _getAverageRecentProcessingTime();
      final recentErrors =
          _errorHandler.getRecentErrors(within: const Duration(minutes: 5));

      final degradationLevel = _degradationManager.assessDegradationNeeds(
        image: image,
        settings: analysisSettings,
        recentProcessingTime: recentProcessingTime,
        recentErrors: recentErrors,
      );

      // Apply degradation if needed
      final effectiveSettings = degradationLevel != DegradationLevel.none
          ? _degradationManager.createDegradedSettings(
              analysisSettings, degradationLevel)
          : analysisSettings;

      if (degradationLevel != DegradationLevel.none) {
        _degradationManager.recordDegradationEvent(
          level: degradationLevel,
          reason: 'performance_optimization',
          imageId: imageId,
          context: {
            'recent_processing_time_ms': recentProcessingTime?.inMilliseconds,
            'recent_errors': recentErrors.length,
          },
        );
      }

      // Create analysis context
      final context = AnalysisContext(
        imageId: imageId,
        settings: effectiveSettings,
        metadata: metadata ?? {},
      );

      // Check if we should skip smart cropping
      if (_shouldSkipSmartCrop(image, targetSize, effectiveSettings)) {
        stopwatch.stop();
        final fallbackCrop = _createEnhancedFallbackCrop(
            image, targetSize, 'skipped_smart_crop', effectiveSettings);

        return _createEnhancedCropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: stopwatch.elapsed,
          fromCache: false,
          analyzerMetadata: {'skipped_smart_crop': true},
        );
      }

      // Get compatible analyzers with degradation filtering
      var analyzers =
          _registry.getCompatibleAnalyzers(image, effectiveSettings);
      analyzers = _degradationManager.filterAnalyzers(
          analyzers, degradationLevel, image, effectiveSettings);

      if (analyzers.isEmpty) {
        stopwatch.stop();
        final fallbackCrop = _createEnhancedFallbackCrop(
            image, targetSize, 'no_analyzers', effectiveSettings);

        return _createEnhancedCropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: stopwatch.elapsed,
          fromCache: false,
          analyzerMetadata: {'skipped_smart_crop': true},
        );
      }

      // Perform analysis with progressive fallback
      final result = await _performAnalysisWithProgressiveFallback(
        image,
        targetSize,
        context,
        analyzers,
        effectiveSettings,
      );

      stopwatch.stop();
      _recordProcessingTime(stopwatch.elapsed);

      // Update stats
      _engineStats['successful_analyses'] =
          (_engineStats['successful_analyses'] as int? ?? 0) + 1;

      return result.copyWith(processingTime: stopwatch.elapsed);
    } catch (e, stackTrace) {
      stopwatch.stop();
      _recordProcessingTime(stopwatch.elapsed);

      // Record error with comprehensive context
      final error = CropError.fromException(
        e,
        stackTrace,
        imageId: imageId,
        context: {
          'image_size': '${image.width}x${image.height}',
          'target_size': '${targetSize.width}x${targetSize.height}',
          'processing_time_ms': stopwatch.elapsedMilliseconds,
        },
      );
      _errorHandler.recordError(error);

      // Update stats
      _engineStats['failed_analyses'] =
          (_engineStats['failed_analyses'] as int? ?? 0) + 1;

      // Return enhanced fallback crop with user feedback
      final fallbackCrop = _createEnhancedFallbackCrop(
          image, targetSize, 'analysis_error', settings);

      return _createEnhancedCropResult(
        bestCrop: fallbackCrop,
        allScores: [],
        processingTime: stopwatch.elapsed,
        fromCache: false,
        analyzerMetadata: {
          'error_occurred': true,
          'error_message': _errorHandler.getUserFriendlyMessage(error),
          'fallback_used': true,
        },
      );
    }
  }

  /// Performs analysis with timeout protection
  Future<CropResult> _performAnalysisWithTimeout(
    ui.Image image,
    ui.Size targetSize,
    AnalysisContext context,
    List<CropAnalyzer> analyzers,
    Duration timeout,
  ) async {
    final completer = Completer<CropResult>();
    Timer? timeoutTimer;

    // Set up timeout
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        final fallbackCrop =
            _createEnhancedFallbackCrop(image, targetSize, 'timeout', null);
        final enhancedResult = _createEnhancedCropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: timeout,
          fromCache: false,
          analyzerMetadata: {'timeout': true},
        );
        completer.complete(enhancedResult);
      }
    });

    // Perform analysis
    _performAnalysis(image, targetSize, context, analyzers, completer);

    final result = await completer.future;
    timeoutTimer.cancel();

    return result;
  }

  /// Performs the actual crop analysis
  Future<void> _performAnalysis(
    ui.Image image,
    ui.Size targetSize,
    AnalysisContext context,
    List<CropAnalyzer> analyzers,
    Completer<CropResult> completer,
  ) async {
    final scores = <CropScore>[];
    int failedAnalyzers = 0;

    try {
      // Run analyzers in priority order
      for (final analyzer in analyzers) {
        if (completer.isCompleted) break;

        // Yield to the UI thread before each analyzer to keep the spinner fluid
        await Future.delayed(Duration.zero);

        // Check if we've exceeded timeout
        if (context.hasExceededTimeout) {
          final fallbackCrop = _createEnhancedFallbackCrop(
              image, targetSize, 'timeout_during_analysis', context.settings);
          if (!completer.isCompleted) {
            final enhancedResult = _createEnhancedCropResult(
              bestCrop: fallbackCrop,
              allScores: scores,
              processingTime: context.elapsedTime,
              fromCache: false,
              analyzerMetadata: {'timeout_during_analysis': true},
            );
            completer.complete(enhancedResult);
          }
          return;
        }

        try {
          // Record usage
          final analyzerName = analyzer is CropAnalyzerV2
              ? analyzer.name
              : analyzer.strategyName;
          _registry.recordUsage(analyzerName);

          // Performance monitoring hooks (only for v2 analyzers)
          if (analyzer is CropAnalyzerV2) {
            analyzer.onAnalysisStart(
                context.imageId,
                ui.Size(image.width.toDouble(), image.height.toDouble()),
                targetSize);
          }

          final analyzerStopwatch = Stopwatch()..start();

          // Run the analyzer (use v2 method if available, otherwise fall back to v1)
          final score = analyzer is CropAnalyzerV2
              ? await analyzer.analyzeWithContext(image, targetSize, context)
              : await analyzer.analyze(image, targetSize);

          analyzerStopwatch.stop();

          // Performance monitoring hook (only for v2 analyzers)
          if (analyzer is CropAnalyzerV2) {
            analyzer.onAnalysisComplete(
                context.imageId, analyzerStopwatch.elapsed, true);
          }

          // Validate and add score
          if (score.isValid && score.score >= analyzer.minConfidenceThreshold) {
            scores.add(score);
          }
        } catch (e, stackTrace) {
          failedAnalyzers++;

          // Performance monitoring hook (only for v2 analyzers)
          if (analyzer is CropAnalyzerV2) {
            analyzer.onAnalysisError(context.imageId, e, stackTrace);
          }

          // Continue with other analyzers
          continue;
        }
      }

      // Check if we have any valid scores
      if (scores.isEmpty || failedAnalyzers == analyzers.length) {
        final fallbackCrop = _createEnhancedFallbackCrop(
            image, targetSize, 'all_analyzers_failed', context.settings);
        if (!completer.isCompleted) {
          final enhancedResult = _createEnhancedCropResult(
            bestCrop: fallbackCrop,
            allScores: [],
            processingTime: context.elapsedTime,
            fromCache: false,
            analyzerMetadata: {'all_analyzers_failed': true},
          );
          completer.complete(enhancedResult);
        }
        return;
      }

      // Select best crop from scores
      var bestCrop = _selectBestCrop(scores, context.settings);

      // Apply Subject Fit Checker if scaling is enabled
      if (context.settings.enableSubjectScaling) {
        try {
          final originalScore = scores.firstWhere(
              (s) => s.coordinates.strategy == bestCrop.strategy,
              orElse: () => scores.first);
          final metrics = originalScore.metrics;

          if (metrics.containsKey('subject_x') &&
              metrics.containsKey('subject_y') &&
              metrics.containsKey('subject_width') &&
              metrics.containsKey('subject_height')) {
            final subjectBounds = ui.Rect.fromLTWH(
                metrics['subject_x']!,
                metrics['subject_y']!,
                metrics['subject_width']!,
                metrics['subject_height']!);

            final fitResult = SubjectFitChecker.checkSubjectFit(
              bestCrop,
              subjectBounds,
              ui.Size(image.width.toDouble(), image.height.toDouble()),
              targetSize,
              minCoverage: context.settings.minSubjectCoverage,
              maxScale: context.settings.maxScaleFactor,
              allowLetterbox: context.settings.allowLetterbox,
            );

            if (fitResult.needsScaling) {
              bestCrop = fitResult.adjustedCrop;
            }
          }
        } catch (e) {
          // Ignore scaling errors to prevent crop failure
        }
      }

      // Apply letterbox crop expansion for wide landscape images when allowed.
      // When the source image is wide (>1.3 aspect) and allowLetterbox is on,
      // expand the crop window to capture more of the scene. The crop center
      // stays the same; applyCropAndResize fills the empty portrait space with
      // a blurred background rather than using an ultra-narrow portrait strip.
      if (context.settings.allowLetterbox) {
        try {
          final imageAspect = image.width / image.height;
          if (imageAspect > 1.3) {
            // Target a crop width of 50% of the image (vs the default ~27-32%)
            // This is wide enough to show a meaningful portion of the scene
            // while still having some blurred fill on the sides.
            const targetLetterboxWidth = 0.50;
            if (bestCrop.width < targetLetterboxWidth) {
              final cropCenterX = bestCrop.x + bestCrop.width / 2;
              final newX = (cropCenterX - targetLetterboxWidth / 2).clamp(0.0, 1.0 - targetLetterboxWidth);
              bestCrop = bestCrop.copyWith(
                x: newX,
                width: targetLetterboxWidth,
                strategy: '${bestCrop.strategy}_letterbox',
              );
            }
          }
        } catch (e) {
          // Ignore letterbox expansion errors
        }
      }

      if (!completer.isCompleted) {
        final enhancedResult = _createEnhancedCropResult(
          bestCrop: bestCrop,
          allScores: scores,
          processingTime: context.elapsedTime,
          fromCache: false,
          analyzerMetadata: {
            'analysis_completed': true,
            if (bestCrop.strategy.contains('ml_subject_detection'))
              'ml_subject_used': true,
            if (bestCrop.strategy.contains('letterbox'))
              'letterbox_applied': true,
          },
        );
        completer.complete(enhancedResult);
      }
    } catch (e) {
      if (!completer.isCompleted) {
        final fallbackCrop = _createEnhancedFallbackCrop(
            image, targetSize, 'analysis_exception', context.settings);
        final enhancedResult = _createEnhancedCropResult(
          bestCrop: fallbackCrop,
          allScores: scores,
          processingTime: context.elapsedTime,
          fromCache: false,
          analyzerMetadata: {'analysis_exception': true},
        );
        completer.complete(enhancedResult);
      }
    }
  }

  /// Selects the best crop from analyzer scores
  CropCoordinates _selectBestCrop(
      List<CropScore> scores, CropSettings settings) {
    if (scores.isEmpty) {
      throw StateError('No valid crop scores available');
    }

    // Calculate weighted scores
    final weightedScores = <CropScore>[];

    for (final score in scores) {
      // Find the analyzer that produced this score (handle specialized strategy names)
      CropAnalyzer? analyzer;
      
      // Try exact match first
      analyzer = _registry.getAnalyzer(score.strategy);
      
      // If no exact match, try matching by prefix (e.g. subject_detection_context matches subject_detection)
      if (analyzer == null) {
        for (final a in _registry.getAllAnalyzers()) {
          if (score.strategy.startsWith(a.strategyName)) {
            analyzer = a;
            break;
          }
        }
      }

      if (analyzer != null) {
        double aggressivenessMultiplier = 1.0;
        final baseStrategy = analyzer.strategyName;

        if (baseStrategy == 'ml_subject_detection' || baseStrategy == 'subject_detection') {
          switch (settings.aggressiveness) {
            case CropAggressiveness.conservative:
              aggressivenessMultiplier = 1.0;
              break;
            case CropAggressiveness.balanced:
              aggressivenessMultiplier = 1.1;
              break;
            case CropAggressiveness.aggressive:
              aggressivenessMultiplier = 1.2;
              break;
          }
        }

        final weightedScore =
            score.score * analyzer.weight * aggressivenessMultiplier;

        weightedScores.add(score.copyWith(
          score: weightedScore,
          metrics: {
            ...score.metrics,
            'weighted_score': weightedScore,
            'original_score': score.score,
            'analyzer_weight': analyzer.weight,
            'aggressiveness_multiplier': aggressivenessMultiplier,
          },
        ));
      } else {
        // Fallback for unknown analyzers - use raw score
        weightedScores.add(score);
      }
    }

    // Sort by weighted score
    weightedScores.sort((a, b) => b.score.compareTo(a.score));

    final bestCandidate = weightedScores.first;

    // Stability consensus: check if we should prefer a safe center crop
    // if the "smart" crop is only marginally better.
    final centerCandidate = weightedScores.firstWhere(
      (s) => s.strategy == 'center_weighted',
      orElse: () => bestCandidate,
    );

    if (bestCandidate.strategy != 'center_weighted' &&
        bestCandidate.score < centerCandidate.score * 1.15) {
      // The "smart" improvement is too small to risk a potential bad jump/crop.
      // Stick to the safe center weighting.
      return centerCandidate.coordinates.copyWith(
        strategy: '${centerCandidate.strategy}_consensus',
      );
    }

    return bestCandidate.coordinates;
  }

  /// Creates an enhanced fallback crop using the fallback strategies system
  CropCoordinates _createEnhancedFallbackCrop(
    ui.Image image,
    ui.Size targetSize,
    String reason,
    CropSettings? settings,
  ) {
    try {
      return _fallbackStrategies.createFallbackCrop(
        image: image,
        targetSize: targetSize,
        reason: reason,
        settings: settings,
        context: {
          'engine_stats': _engineStats,
          'recent_errors': _errorHandler.getRecentErrors().length,
        },
      );
    } catch (e, stackTrace) {
      // Record fallback creation error
      final error = CropError.fromException(
        e,
        stackTrace,
        context: {'fallback_reason': reason},
      );
      _errorHandler.recordError(error);

      // Ultimate fallback - simple center crop
      return _createUltimateFallbackCrop(image, targetSize);
    }
  }

  /// Creates the ultimate fallback crop when all else fails
  CropCoordinates _createUltimateFallbackCrop(
      ui.Image image, ui.Size targetSize) {
    try {
      final imageSize =
          ui.Size(image.width.toDouble(), image.height.toDouble());
      final targetAspectRatio = targetSize.width / targetSize.height;
      final imageAspectRatio = imageSize.width / imageSize.height;

      double cropWidth, cropHeight;

      if (targetAspectRatio > imageAspectRatio) {
        cropWidth = 1.0;
        cropHeight = imageAspectRatio / targetAspectRatio;
      } else {
        cropHeight = 1.0;
        cropWidth = targetAspectRatio / imageAspectRatio;
      }

      // Ensure crop dimensions are valid
      cropWidth = math.max(0.1, math.min(1.0, cropWidth));
      cropHeight = math.max(0.1, math.min(1.0, cropHeight));

      return CropCoordinates(
        x: (1.0 - cropWidth) / 2,
        y: (1.0 - cropHeight) / 2,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.1,
        strategy: 'ultimate_fallback',
      );
    } catch (e) {
      // Absolute last resort
      return CropCoordinates(
        x: 0.0,
        y: 0.0,
        width: 1.0,
        height: 1.0,
        confidence: 0.05,
        strategy: 'absolute_fallback',
      );
    }
  }

  /// Validates input parameters with enhanced error handling
  void _validateInputsWithErrorHandling(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
    String imageId,
  ) {
    try {
      if (image.width <= 0 || image.height <= 0) {
        throw ArgumentError(
            'Invalid image dimensions: ${image.width}x${image.height}');
      }

      if (targetSize.width <= 0 || targetSize.height <= 0) {
        throw ArgumentError(
            'Invalid target size: ${targetSize.width}x${targetSize.height}');
      }

      if (!settings.isValid) {
        throw ArgumentError('Invalid crop settings');
      }

      // Additional validation checks
      if (image.width > 10000 || image.height > 10000) {
        final error = CropError(
          type: CropErrorType.resourceExhaustion,
          message: 'Image too large: ${image.width}x${image.height}',
          severity: ErrorSeverity.medium,
          imageId: imageId,
          isRecoverable: true,
          context: {
            'image_width': image.width,
            'image_height': image.height,
            'max_recommended': 10000,
          },
        );
        _errorHandler.recordError(error);
      }
    } catch (e, stackTrace) {
      final error = CropError.fromException(
        e,
        stackTrace,
        imageId: imageId,
        context: {
          'validation_stage': 'input_validation',
          'image_size': '${image.width}x${image.height}',
          'target_size': '${targetSize.width}x${targetSize.height}',
        },
      );
      _errorHandler.recordError(error);
      rethrow;
    }
  }

  /// Determines if smart cropping should be skipped
  bool _shouldSkipSmartCrop(
      ui.Image image, ui.Size targetSize, CropSettings settings) {
    // Skip if image is too small
    if (image.width < 100 || image.height < 100) {
      return true;
    }

    // Skip if target size is very small
    if (targetSize.width < 50 || targetSize.height < 50) {
      return true;
    }

    // Skip if timeout is extremely short
    if (settings.maxProcessingTime.inMilliseconds < 10) {
      return true;
    }

    return false;
  }

  /// Ensures the engine is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'SmartCropEngine not initialized. Call initialize() first.');
    }
  }

  /// Creates an enhanced CropResult with performance metrics
  CropResult _createEnhancedCropResult({
    required CropCoordinates bestCrop,
    required List<CropScore> allScores,
    required Duration processingTime,
    required bool fromCache,
    Map<String, dynamic>? analyzerMetadata,
    int memoryUsage = 0,
    int analyzersExecuted = 0,
    int analyzersSkipped = 0,
    Map<String, Duration>? analyzerTimes,
  }) {
    final scoringBreakdown = <String, double>{};
    final finalAnalyzerTimes = analyzerTimes ?? <String, Duration>{};

    // Extract analyzer scores from allScores
    for (final score in allScores) {
      scoringBreakdown[score.strategy] = score.score;
      // Add analyzer time if not provided
      if (!finalAnalyzerTimes.containsKey(score.strategy) &&
          allScores.isNotEmpty) {
        finalAnalyzerTimes[score.strategy] = Duration(
          milliseconds:
              (processingTime.inMilliseconds / allScores.length).round(),
        );
      }
    }

    return CropResult(
      bestCrop: bestCrop,
      allScores: allScores,
      processingTime: processingTime,
      fromCache: fromCache,
      analyzerMetadata: analyzerMetadata ?? {},
      performanceMetrics: PerformanceMetrics(
        totalTime: processingTime,
        analyzerTimes: finalAnalyzerTimes,
        memoryUsage: memoryUsage,
        analyzersExecuted: analyzersExecuted,
        analyzersSkipped: analyzersSkipped,
        cacheHitRate: fromCache ? 1.0 : 0.0,
      ),
      scoringBreakdown: scoringBreakdown,
    );
  }

  /// Performs analysis with progressive fallback strategies
  Future<CropResult> _performAnalysisWithProgressiveFallback(
    ui.Image image,
    ui.Size targetSize,
    AnalysisContext context,
    List<CropAnalyzer> analyzers,
    CropSettings settings,
  ) async {
    // Create fallback chain
    final fallbackChain =
        _degradationManager.createFallbackChain(image, targetSize, settings);

    // Try each fallback strategy
    for (final fallbackStrategy in fallbackChain) {
      try {
        final result = await _performAnalysisWithTimeout(
          image,
          targetSize,
          context.copyWith(settings: fallbackStrategy.settings),
          analyzers,
          fallbackStrategy.timeout,
        );

        // If we got a valid result, return it
        if (result.bestCrop.confidence > 0.2) {
          return result.copyWith(
            analyzerMetadata: {
              ...result.analyzerMetadata,
              'fallback_strategy': fallbackStrategy.name,
              'degradation_applied': fallbackStrategy.name != 'original',
            },
          );
        }
      } catch (e, stackTrace) {
        // Record fallback failure and try next strategy
        final error = CropError.fromException(
          e,
          stackTrace,
          imageId: context.imageId,
          context: {
            'fallback_strategy': fallbackStrategy.name,
            'timeout_ms': fallbackStrategy.timeout.inMilliseconds,
          },
        );
        _errorHandler.recordError(error);
        continue;
      }
    }

    // All fallback strategies failed - use ultimate fallback
    final ultimateFallback = _createUltimateFallbackCrop(image, targetSize);
    return _createEnhancedCropResult(
      bestCrop: ultimateFallback,
      allScores: [],
      processingTime: context.elapsedTime,
      fromCache: false,
      analyzerMetadata: {
        'fallback_strategy': 'ultimate',
        'all_strategies_failed': true,
      },
    );
  }

  /// Records processing time for performance monitoring
  void _recordProcessingTime(Duration processingTime) {
    _recentProcessingTimes.add(processingTime);

    // Keep only recent times (last 20 analyses)
    if (_recentProcessingTimes.length > 20) {
      _recentProcessingTimes.removeAt(0);
    }
  }

  /// Gets average recent processing time
  Duration? _getAverageRecentProcessingTime() {
    if (_recentProcessingTimes.isEmpty) return null;

    final totalMs = _recentProcessingTimes
        .map((d) => d.inMilliseconds)
        .reduce((a, b) => a + b);

    return Duration(
        milliseconds: (totalMs / _recentProcessingTimes.length).round());
  }

  /// Gets comprehensive engine statistics including error handling
  Map<String, dynamic> getStats() {
    return {
      'engine': Map.from(_engineStats),
      'registry': _registry.getStats(),
      'error_handling': _errorHandler.getErrorStats(),
      'degradation': _degradationManager.getDegradationStats(),
      'performance': {
        'recent_processing_times_ms':
            _recentProcessingTimes.map((d) => d.inMilliseconds).toList(),
        'average_processing_time_ms':
            _getAverageRecentProcessingTime()?.inMilliseconds,
      },
    };
  }

  /// Gets user feedback about current system status
  Map<String, dynamic> getUserFeedback() {
    final recentErrors =
        _errorHandler.getRecentErrors(within: const Duration(minutes: 5));
    final degradationStats = _degradationManager.getDegradationStats();

    final feedback = <String, dynamic>{
      'status': 'normal',
      'messages': <String>[],
      'recommendations': <String>[],
    };

    // Check for recent critical errors
    final criticalErrors = recentErrors
        .where((e) =>
            e.severity == ErrorSeverity.critical ||
            e.severity == ErrorSeverity.high)
        .toList();

    if (criticalErrors.isNotEmpty) {
      feedback['status'] = 'degraded';
      feedback['messages']
          .add(_errorHandler.getUserFriendlyMessage(criticalErrors.first));

      if (criticalErrors.any((e) => e.type == CropErrorType.memoryPressure)) {
        feedback['recommendations'].add('Close other apps to free up memory');
      }
    }

    // Check for frequent degradations
    final totalDegradations =
        degradationStats['total_degradations'] as int? ?? 0;
    if (totalDegradations > 5) {
      feedback['status'] = 'performance_issues';
      feedback['messages'].add(
          'Performance has been automatically reduced for better stability');
      feedback['recommendations'].add('Consider restarting the app or device');
    }

    return feedback;
  }

  /// Gets the analyzer registry
  AnalyzerRegistry get registry => _registry;

  /// Disposes the engine and cleans up resources
  void dispose() {
    _registry.clear();
    _errorHandler.clearErrorHistory();
    _isInitialized = false;
    _engineStats.clear();
    _recentProcessingTimes.clear();
  }
}
