import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import '../models/crop_settings.dart';
import '../cache/intelligent_cache_manager.dart';
import '../interfaces/crop_analyzer.dart';
import 'image_processing_pipeline.dart';
import 'device_capability_detector.dart';
import 'performance_budget_calculator.dart';
import 'battery_optimizer.dart';
import 'performance_models.dart';
import 'image_processing_models.dart';

/// Manages performance monitoring, adaptive quality, and resource optimization
class PerformanceManager {
  static final PerformanceManager _instance = PerformanceManager._internal();

  factory PerformanceManager() => _instance;

  PerformanceManager._internal();

  final IntelligentCacheManager _cacheManager = IntelligentCacheManager();
  final ImageProcessingPipeline _pipeline = ImageProcessingPipeline();

  // Performance metrics
  final List<PerformanceMetric> _metrics = [];
  final Map<String, Duration> _analyzerPerformance = {};
  Timer? _memoryMonitorTimer;

  // Adaptive settings
  CropAggressiveness _currentQuality = CropAggressiveness.balanced;
  bool _isLowMemoryMode = false;

  // Processing budgets
  Duration _processingBudget = const Duration(seconds: 2);
  int _memoryBudgetMB = 100;
  final PerformanceBudgetCalculator _budgetCalculator = PerformanceBudgetCalculator();

  /// Initializes the performance manager
  Future<void> initialize() async {
    final capabilities = await DeviceCapabilityDetector.getDeviceCapability();
    _memoryBudgetMB = capabilities.totalRam ~/ 8; // 12.5% of total RAM

    _currentQuality = await _budgetCalculator.determineOptimalQuality();

    // Start memory monitoring
    _startMemoryMonitoring();

    // Start performance metrics collection
    _startMetricsCollection();
  }

  /// Gets adaptive crop settings based on current performance conditions
  Future<CropSettings> getAdaptiveSettings(CropSettings baseSettings) async {
    final capabilities =
        await DeviceCapabilityDetector.getDeviceCapability();
    final memoryStatus = await _getMemoryStatus();

    // Apply battery optimizations first
    var adaptiveSettings =
        await BatteryOptimizer.optimizeSettingsForBattery(baseSettings);

    // Calculate adaptive budget
    final adaptiveBudget = _budgetCalculator.calculateProcessingBudget(
      capabilities,
      memoryStatus == MemoryStatus.high || memoryStatus == MemoryStatus.critical,
    );

    // Create final adaptive settings
    return adaptiveSettings.copyWith(
      maxProcessingTime: adaptiveBudget,
    );
  }

  /// Records performance metrics for an operation
  void recordMetric(PerformanceMetric metric) {
    _metrics.add(metric);

    // Update analyzer performance tracking
    _analyzerPerformance[metric.analyzerName] = metric.processingTime;

    // Keep only recent metrics
    if (_metrics.length > 1000) {
      _metrics.removeRange(0, _metrics.length - 1000);
    }

    // Trigger adaptive adjustments if needed
    _checkForAdaptiveAdjustments();
  }

  /// Gets current performance statistics
  PerformanceStats getPerformanceStats() {
    if (_metrics.isEmpty) {
      return const PerformanceStats(
        averageProcessingTime: Duration.zero,
        successRate: 0.0,
        memoryUsageMB: 0.0,
        cacheHitRate: 0.0,
        totalOperations: 0,
      );
    }

    final totalTime = _metrics.fold<Duration>(
      Duration.zero,
      (sum, metric) => sum + metric.processingTime,
    );

    final averageTime = Duration(
      microseconds: totalTime.inMicroseconds ~/ _metrics.length,
    );

    final successfulOperations = _metrics.where((m) => m.isSuccessful).length;
    final successRate = successfulOperations / _metrics.length;

    return PerformanceStats(
      averageProcessingTime: averageTime,
      successRate: successRate,
      memoryUsageMB: _getCurrentMemoryUsageMB(),
      cacheHitRate: 0.0, // Will be updated by cache manager
      totalOperations: _metrics.length,
    );
  }

  /// Monitors memory usage and triggers optimization
  void _startMemoryMonitoring() {
    // Prevent periodic timer in test environment which causes pumpAndSettle to hang
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    _memoryMonitorTimer =
        Timer.periodic(const Duration(seconds: 30), (timer) async {
      final memoryUsage = _getCurrentMemoryUsageMB();

      if (memoryUsage > _memoryBudgetMB * 0.8) {
        await _handleHighMemoryUsage();
      }
    });
  }

  /// Handles high memory usage situations
  Future<void> _handleHighMemoryUsage() async {
    if (!_isLowMemoryMode) {
      _isLowMemoryMode = true;

      // Clear caches
      _pipeline.clearCache();
      await _cacheManager.optimizeCache();

      // Reduce quality temporarily
      if (_currentQuality == CropAggressiveness.aggressive) {
        _currentQuality = CropAggressiveness.balanced;
      } else if (_currentQuality == CropAggressiveness.balanced) {
        _currentQuality = CropAggressiveness.conservative;
      }

      // Reduce processing budget
      _processingBudget = Duration(
        milliseconds: (_processingBudget.inMilliseconds * 0.7).round(),
      );
    }
}
  /// Checks for adaptive adjustments based on recent performance
  void _checkForAdaptiveAdjustments() {
    if (_metrics.length < 10) return;

    final recentMetrics = _metrics.skip(_metrics.length - 10).toList();
    final averageTime = recentMetrics.fold<Duration>(
          Duration.zero,
          (sum, metric) => sum + metric.processingTime,
        ) ~/
        recentMetrics.length;

    // If processing is consistently slow, reduce quality
    if (averageTime > _processingBudget * 1.2) {
      if (_currentQuality == CropAggressiveness.aggressive) {
        _currentQuality = CropAggressiveness.balanced;
      } else if (_currentQuality == CropAggressiveness.balanced) {
        _currentQuality = CropAggressiveness.conservative;
      }
    }

    // If processing is consistently fast and conditions allow, increase quality
    else if (averageTime < _processingBudget * 0.5 && !_isLowMemoryMode) {
      if (_currentQuality == CropAggressiveness.conservative) {
        _currentQuality = CropAggressiveness.balanced;
      } else if (_currentQuality == CropAggressiveness.balanced) {
        _currentQuality = CropAggressiveness.aggressive;
      }
    }
  }

  /// Starts metrics collection
  void _startMetricsCollection() {
    // Prevent periodic timer in test environment which causes pumpAndSettle to hang
    if (Platform.environment.containsKey('FLUTTER_TEST')) return;

    // Periodic cleanup of old metrics
    Timer.periodic(const Duration(minutes: 5), (timer) {
      final cutoffTime = DateTime.now().subtract(const Duration(hours: 1));
      _metrics.removeWhere((metric) => metric.timestamp.isBefore(cutoffTime));
    });
  }

  /// Gets current memory usage in MB
  double _getCurrentMemoryUsageMB() {
    // This is a simplified implementation
    // In a real app, you'd use platform-specific memory monitoring
    try {
      return ProcessInfo.currentRss / (1024 * 1024);
    } catch (e) {
      return 50.0; // Default estimate
    }
  }

  /// Gets memory status
  Future<MemoryStatus> _getMemoryStatus() async {
    final usageMB = _getCurrentMemoryUsageMB();

    if (usageMB > _memoryBudgetMB * 0.9) {
      return MemoryStatus.critical;
    } else if (usageMB > _memoryBudgetMB * 0.7) {
      return MemoryStatus.high;
    } else {
      return MemoryStatus.normal;
    }
  }

  /// Optimizes performance settings
  Future<void> optimizePerformance() async {
    // Clear caches
    _pipeline.clearCache();
    await _cacheManager.optimizeCache();

    // Reset adaptive settings
    _currentQuality = await _budgetCalculator.determineOptimalQuality();
    _isLowMemoryMode = false;

    // Clear old metrics
    _metrics.clear();
    _analyzerPerformance.clear();
  }

  /// Gets pipeline cache statistics
  CacheStats getPipelineCacheStats() {
    return _pipeline.getCacheStats();
  }

  /// Preprocesses image using the pipeline
  Future<ui.Image> preprocessImage(
      ui.Image image, CropSettings settings) async {
    return await _pipeline.preprocessImage(image, settings);
  }

  /// Processes image with multiple analyzers using the optimized pipeline
  Future<List<CropAnalysisResult>> processImageWithAnalyzers(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
    List<CropAnalyzer> analyzers,
  ) async {
    final stopwatch = Stopwatch()..start();

    try {
      final results =
          await _pipeline.processImage(image, targetSize, settings, analyzers);

      // Record metrics for each analyzer result
      for (final result in results) {
        recordMetric(PerformanceMetric(
          analyzerName: result.analyzerName,
          processingTime: result.processingTime,
          isSuccessful: result.isSuccessful,
          timestamp: DateTime.now(),
          confidence: result.confidence,
          error: result.error,
        ));
      }

      return results;
    } catch (e) {
      // Record failure metric
      recordMetric(PerformanceMetric.failure(
        analyzerName: 'pipeline',
        processingTime: stopwatch.elapsed,
        error: e.toString(),
      ));
      rethrow;
    } finally {
      stopwatch.stop();
    }
  }

  /// Gets analyzer performance statistics
  Map<String, AnalyzerPerformanceStats> getAnalyzerStats() {
    final stats = <String, AnalyzerPerformanceStats>{};

    for (final analyzerName in _analyzerPerformance.keys) {
      final analyzerMetrics =
          _metrics.where((m) => m.analyzerName == analyzerName).toList();

      if (analyzerMetrics.isNotEmpty) {
        final totalTime = analyzerMetrics.fold<Duration>(
          Duration.zero,
          (sum, metric) => sum + metric.processingTime,
        );

        final averageTime = Duration(
          microseconds: totalTime.inMicroseconds ~/ analyzerMetrics.length,
        );

        final successCount =
            analyzerMetrics.where((m) => m.isSuccessful).length;
        final successRate = successCount / analyzerMetrics.length;

        stats[analyzerName] = AnalyzerPerformanceStats(
          analyzerName: analyzerName,
          averageProcessingTime: averageTime,
          successRate: successRate,
          totalOperations: analyzerMetrics.length,
        );
      }
    }

    return stats;
  }

  /// Disposes resources
  Future<void> dispose() async {
    _memoryMonitorTimer?.cancel();
    await _cacheManager.close();
  }
}
