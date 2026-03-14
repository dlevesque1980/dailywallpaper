import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import '../models/crop_settings.dart';
import '../cache/intelligent_cache_manager.dart';
import '../interfaces/crop_analyzer.dart';
import 'image_processing_pipeline.dart';
import 'device_capability_detector.dart';
import 'battery_optimizer.dart';

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

  /// Initializes the performance manager
  Future<void> initialize() async {
    // Set initial quality based on device capabilities
    _currentQuality = await _determineOptimalQuality();

    // Start memory monitoring
    _startMemoryMonitoring();

    // Start performance metrics collection
    _startMetricsCollection();
  }

  /// Gets adaptive crop settings based on current performance conditions
  Future<CropSettings> getAdaptiveSettings(CropSettings baseSettings) async {
    final deviceCapabilities =
        await DeviceCapabilityDetector.getDeviceCapability();
    final memoryStatus = await _getMemoryStatus();

    // Apply battery optimizations first
    var adaptiveSettings =
        await BatteryOptimizer.optimizeSettingsForBattery(baseSettings);

    // Adjust processing budget based on device capabilities
    final adaptiveBudget = _calculateProcessingBudget(
      deviceCapabilities,
      memoryStatus,
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

  /// Determines optimal quality based on device capabilities
  Future<CropAggressiveness> _determineOptimalQuality() async {
    final capabilities = await DeviceCapabilityDetector.getDeviceCapability();

    if (capabilities.isHighPerformance) {
      return CropAggressiveness.aggressive;
    } else if (capabilities.overallTier == PerformanceTier.medium) {
      return CropAggressiveness.balanced;
    } else {
      return CropAggressiveness.conservative;
    }
  }

  /// Calculates processing budget based on conditions
  Duration _calculateProcessingBudget(
    DeviceCapability capabilities,
    MemoryStatus memoryStatus,
  ) {
    var baseBudget = const Duration(seconds: 2);

    // Adjust based on device capabilities
    if (capabilities.isHighPerformance) {
      baseBudget = const Duration(seconds: 3);
    } else if (capabilities.isLowPerformance) {
      baseBudget = const Duration(milliseconds: 1500);
    }

    // Apply timeout multiplier from device capabilities
    baseBudget = Duration(
      milliseconds:
          (baseBudget.inMilliseconds * capabilities.timeoutMultiplier).round(),
    );

    // Reduce budget if memory is constrained
    if (memoryStatus.isHigh) {
      baseBudget = Duration(
        milliseconds: (baseBudget.inMilliseconds * 0.8).round(),
      );
    }

    return baseBudget;
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
    _currentQuality = await _determineOptimalQuality();
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

/// Performance metric for a single operation
class PerformanceMetric {
  final String analyzerName;
  final Duration processingTime;
  final bool isSuccessful;
  final DateTime timestamp;
  final double? confidence;
  final String? error;

  const PerformanceMetric({
    required this.analyzerName,
    required this.processingTime,
    required this.isSuccessful,
    required this.timestamp,
    this.confidence,
    this.error,
  });

  factory PerformanceMetric.success({
    required String analyzerName,
    required Duration processingTime,
    double? confidence,
  }) {
    return PerformanceMetric(
      analyzerName: analyzerName,
      processingTime: processingTime,
      isSuccessful: true,
      timestamp: DateTime.now(),
      confidence: confidence,
    );
  }

  factory PerformanceMetric.failure({
    required String analyzerName,
    required Duration processingTime,
    required String error,
  }) {
    return PerformanceMetric(
      analyzerName: analyzerName,
      processingTime: processingTime,
      isSuccessful: false,
      timestamp: DateTime.now(),
      error: error,
    );
  }

  @override
  String toString() {
    return 'PerformanceMetric($analyzerName: ${processingTime.inMilliseconds}ms, '
        'success=$isSuccessful, confidence=${confidence?.toStringAsFixed(2)})';
  }
}

/// Overall performance statistics
class PerformanceStats {
  final Duration averageProcessingTime;
  final double successRate;
  final double memoryUsageMB;
  final double cacheHitRate;
  final int totalOperations;

  const PerformanceStats({
    required this.averageProcessingTime,
    required this.successRate,
    required this.memoryUsageMB,
    required this.cacheHitRate,
    required this.totalOperations,
  });

  double get successRatePercentage => successRate * 100;
  double get cacheHitRatePercentage => cacheHitRate * 100;

  @override
  String toString() {
    return 'PerformanceStats(avgTime: ${averageProcessingTime.inMilliseconds}ms, '
        'success: ${successRatePercentage.toStringAsFixed(1)}%, '
        'memory: ${memoryUsageMB.toStringAsFixed(1)}MB, '
        'cache: ${cacheHitRatePercentage.toStringAsFixed(1)}%)';
  }
}

/// Analyzer-specific performance statistics
class AnalyzerPerformanceStats {
  final String analyzerName;
  final Duration averageProcessingTime;
  final double successRate;
  final int totalOperations;

  const AnalyzerPerformanceStats({
    required this.analyzerName,
    required this.averageProcessingTime,
    required this.successRate,
    required this.totalOperations,
  });

  @override
  String toString() {
    return 'AnalyzerPerformanceStats($analyzerName: '
        '${averageProcessingTime.inMilliseconds}ms, '
        '${(successRate * 100).toStringAsFixed(1)}% success, '
        '$totalOperations ops)';
  }
}

/// Memory status levels
enum MemoryStatus {
  normal,
  high,
  critical,
}

extension MemoryStatusExtension on MemoryStatus {
  bool get isHigh => this == MemoryStatus.high;
  bool get isCritical => this == MemoryStatus.critical;
}
