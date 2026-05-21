import 'dart:collection';
import 'dart:math' as math;
import 'performance_monitor_models.dart';

/// Monitors and tracks smart crop performance metrics
class PerformanceMonitor {
  static final PerformanceMonitor _instance = PerformanceMonitor._internal();
  factory PerformanceMonitor() => _instance;
  PerformanceMonitor._internal();

  final Queue<PerformanceMetric> _metrics = Queue<PerformanceMetric>();
  final Map<String, OperationStats> _operationStats = {};
  final Map<String, List<Duration>> _recentDurations = {};

  static const int _maxMetricsHistory = 1000;
  static const int _recentDurationsLimit = 50;

  /// Records a performance metric
  void recordMetric(PerformanceMetric metric) {
    _metrics.add(metric);

    // Maintain size limit
    while (_metrics.length > _maxMetricsHistory) {
      _metrics.removeFirst();
    }

    // Update operation stats
    _updateOperationStats(metric);

    // Update recent durations for trend analysis
    _updateRecentDurations(metric);
  }

  /// Records a successful operation
  void recordSuccess(
    String operation,
    Duration duration, {
    Map<String, dynamic>? metadata,
  }) {
    final metric = PerformanceMetric(
      operation: operation,
      duration: duration,
      success: true,
      timestamp: DateTime.now(),
      metadata: metadata ?? {},
    );

    recordMetric(metric);
  }

  /// Records a failed operation
  void recordFailure(
    String operation,
    Duration duration,
    String error, {
    Map<String, dynamic>? metadata,
  }) {
    final metric = PerformanceMetric(
      operation: operation,
      duration: duration,
      success: false,
      timestamp: DateTime.now(),
      error: error,
      metadata: metadata ?? {},
    );

    recordMetric(metric);
  }

  /// Gets overall performance statistics
  PerformanceStats getOverallStats() {
    if (_metrics.isEmpty) {
      return PerformanceStats.empty();
    }

    final totalOperations = _metrics.length;
    final successfulOperations = _metrics.where((m) => m.success).length;
    final failedOperations = totalOperations - successfulOperations;

    final durations = _metrics.map((m) => m.duration).toList();
    final totalDuration = durations.fold<Duration>(
      Duration.zero,
      (sum, duration) => sum + duration,
    );

    final averageDuration = Duration(
      microseconds: (totalDuration.inMicroseconds / totalOperations).round(),
    );

    durations.sort((a, b) => a.inMicroseconds.compareTo(b.inMicroseconds));
    final medianDuration = durations[durations.length ~/ 2];
    final minDuration = durations.first;
    final maxDuration = durations.last;

    final successRate = successfulOperations / totalOperations;

    return PerformanceStats(
      totalOperations: totalOperations,
      successfulOperations: successfulOperations,
      failedOperations: failedOperations,
      successRate: successRate,
      averageDuration: averageDuration,
      medianDuration: medianDuration,
      minDuration: minDuration,
      maxDuration: maxDuration,
      totalDuration: totalDuration,
    );
  }

  /// Gets statistics for a specific operation
  OperationStats? getOperationStats(String operation) {
    return _operationStats[operation];
  }

  /// Gets statistics for all operations
  Map<String, OperationStats> getAllOperationStats() {
    return Map.unmodifiable(_operationStats);
  }

  /// Gets recent performance trends
  PerformanceTrends getPerformanceTrends() {
    final now = DateTime.now();
    final oneHourAgo = now.subtract(const Duration(hours: 1));
    final oneDayAgo = now.subtract(const Duration(days: 1));

    final recentMetrics =
        _metrics.where((m) => m.timestamp.isAfter(oneHourAgo)).toList();
    final dailyMetrics =
        _metrics.where((m) => m.timestamp.isAfter(oneDayAgo)).toList();

    return PerformanceTrends(
      recentHourMetrics: recentMetrics.length,
      recentHourSuccessRate: recentMetrics.isEmpty
          ? 1.0
          : recentMetrics.where((m) => m.success).length / recentMetrics.length,
      recentHourAverageDuration: _calculateAverageDuration(recentMetrics),
      dailyMetrics: dailyMetrics.length,
      dailySuccessRate: dailyMetrics.isEmpty
          ? 1.0
          : dailyMetrics.where((m) => m.success).length / dailyMetrics.length,
      dailyAverageDuration: _calculateAverageDuration(dailyMetrics),
      isPerformanceDegrading: _isPerformanceDegrading(),
    );
  }

  /// Gets memory usage statistics from recorded metadata
  MemoryUsageStats getMemoryUsageStats() {
    final metricsWithMemory = _metrics
        .where((m) => m.metadata.containsKey('memory_usage_mb'))
        .toList();

    if (metricsWithMemory.isEmpty) {
      return MemoryUsageStats.empty();
    }

    final memoryUsages = metricsWithMemory
        .map((m) => (m.metadata['memory_usage_mb'] as num).toDouble())
        .toList();

    memoryUsages.sort();

    final averageMemory =
        memoryUsages.reduce((a, b) => a + b) / memoryUsages.length;
    final medianMemory = memoryUsages[memoryUsages.length ~/ 2];
    final minMemory = memoryUsages.first;
    final maxMemory = memoryUsages.last;

    return MemoryUsageStats(
      averageMemoryMB: averageMemory,
      medianMemoryMB: medianMemory,
      minMemoryMB: minMemory,
      maxMemoryMB: maxMemory,
      samplesCount: memoryUsages.length,
    );
  }

  /// Gets cache performance statistics
  CachePerformanceStats getCachePerformanceStats() {
    final cacheHits =
        _metrics.where((m) => m.metadata['from_cache'] == true).length;

    final cacheMisses =
        _metrics.where((m) => m.metadata['from_cache'] == false).length;

    final totalCacheRequests = cacheHits + cacheMisses;
    final cacheHitRate =
        totalCacheRequests > 0 ? cacheHits / totalCacheRequests : 0.0;

    return CachePerformanceStats(
      cacheHits: cacheHits,
      cacheMisses: cacheMisses,
      cacheHitRate: cacheHitRate,
      averageCacheHitDuration: _calculateAverageDuration(
        _metrics.where((m) => m.metadata['from_cache'] == true).toList(),
      ),
      averageCacheMissDuration: _calculateAverageDuration(
        _metrics.where((m) => m.metadata['from_cache'] == false).toList(),
      ),
    );
  }

  /// Exports performance data for analytics
  Map<String, dynamic> exportAnalyticsData() {
    final overallStats = getOverallStats();
    final trends = getPerformanceTrends();
    final memoryStats = getMemoryUsageStats();
    final cacheStats = getCachePerformanceStats();

    return {
      'overall_stats': overallStats.toMap(),
      'trends': trends.toMap(),
      'memory_stats': memoryStats.toMap(),
      'cache_stats': cacheStats.toMap(),
      'operation_stats': _operationStats.map(
        (key, value) => MapEntry(key, value.toMap()),
      ),
      'export_timestamp': DateTime.now().toIso8601String(),
      'metrics_count': _metrics.length,
    };
  }

  /// Clears all performance data
  void clear() {
    _metrics.clear();
    _operationStats.clear();
    _recentDurations.clear();
  }

  /// Updates operation statistics
  void _updateOperationStats(PerformanceMetric metric) {
    final stats = _operationStats[metric.operation] ??
        OperationStats.empty(metric.operation);

    final updatedStats = OperationStats(
      operation: metric.operation,
      totalCount: stats.totalCount + 1,
      successCount: stats.successCount + (metric.success ? 1 : 0),
      failureCount: stats.failureCount + (metric.success ? 0 : 1),
      totalDuration: stats.totalDuration + metric.duration,
      minDuration: stats.minDuration == null
          ? metric.duration
          : Duration(
              microseconds: math.min(
              stats.minDuration!.inMicroseconds,
              metric.duration.inMicroseconds,
            )),
      maxDuration: stats.maxDuration == null
          ? metric.duration
          : Duration(
              microseconds: math.max(
              stats.maxDuration!.inMicroseconds,
              metric.duration.inMicroseconds,
            )),
      lastUpdated: metric.timestamp,
    );

    _operationStats[metric.operation] = updatedStats;
  }

  /// Updates recent durations for trend analysis
  void _updateRecentDurations(PerformanceMetric metric) {
    final durations = _recentDurations[metric.operation] ?? <Duration>[];
    durations.add(metric.duration);

    // Maintain size limit
    while (durations.length > _recentDurationsLimit) {
      durations.removeAt(0);
    }

    _recentDurations[metric.operation] = durations;
  }

  /// Calculates average duration from metrics
  Duration _calculateAverageDuration(List<PerformanceMetric> metrics) {
    if (metrics.isEmpty) return Duration.zero;

    final totalMicroseconds =
        metrics.map((m) => m.duration.inMicroseconds).reduce((a, b) => a + b);

    return Duration(microseconds: (totalMicroseconds / metrics.length).round());
  }

  /// Determines if performance is degrading based on recent trends
  bool _isPerformanceDegrading() {
    // Simple heuristic: compare recent performance to historical average
    final allMetrics = _metrics.toList();
    if (allMetrics.length < 10) return false;

    final recentCount = math.min(20, allMetrics.length);
    final recentMetrics = allMetrics.sublist(allMetrics.length - recentCount);

    final recentAverage = _calculateAverageDuration(recentMetrics);
    final overallAverage = _calculateAverageDuration(allMetrics);

    // Consider degrading if recent average is 50% slower than overall
    return recentAverage.inMicroseconds > (overallAverage.inMicroseconds * 1.5);
  }
}
