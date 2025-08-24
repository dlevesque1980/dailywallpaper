import 'dart:async';
import 'dart:collection';
import 'dart:math' as math;

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
    
    final recentMetrics = _metrics.where((m) => m.timestamp.isAfter(oneHourAgo)).toList();
    final dailyMetrics = _metrics.where((m) => m.timestamp.isAfter(oneDayAgo)).toList();
    
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
    
    final averageMemory = memoryUsages.reduce((a, b) => a + b) / memoryUsages.length;
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
    final cacheHits = _metrics
        .where((m) => m.metadata['from_cache'] == true)
        .length;
    
    final cacheMisses = _metrics
        .where((m) => m.metadata['from_cache'] == false)
        .length;
    
    final totalCacheRequests = cacheHits + cacheMisses;
    final cacheHitRate = totalCacheRequests > 0 ? cacheHits / totalCacheRequests : 0.0;
    
    final cacheHitDurations = _metrics
        .where((m) => m.metadata['from_cache'] == true)
        .map((m) => m.duration)
        .toList();
    
    final cacheMissDurations = _metrics
        .where((m) => m.metadata['from_cache'] == false)
        .map((m) => m.duration)
        .toList();
    
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
    final stats = _operationStats[metric.operation] ?? OperationStats.empty(metric.operation);
    
    final updatedStats = OperationStats(
      operation: metric.operation,
      totalCount: stats.totalCount + 1,
      successCount: stats.successCount + (metric.success ? 1 : 0),
      failureCount: stats.failureCount + (metric.success ? 0 : 1),
      totalDuration: stats.totalDuration + metric.duration,
      minDuration: stats.minDuration == null 
          ? metric.duration 
          : Duration(microseconds: math.min(
              stats.minDuration!.inMicroseconds,
              metric.duration.inMicroseconds,
            )),
      maxDuration: stats.maxDuration == null
          ? metric.duration
          : Duration(microseconds: math.max(
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
    
    final totalMicroseconds = metrics
        .map((m) => m.duration.inMicroseconds)
        .reduce((a, b) => a + b);
    
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

/// Individual performance metric
class PerformanceMetric {
  final String operation;
  final Duration duration;
  final bool success;
  final DateTime timestamp;
  final String? error;
  final Map<String, dynamic> metadata;
  
  const PerformanceMetric({
    required this.operation,
    required this.duration,
    required this.success,
    required this.timestamp,
    this.error,
    this.metadata = const {},
  });
  
  Map<String, dynamic> toMap() {
    return {
      'operation': operation,
      'duration_ms': duration.inMilliseconds,
      'success': success,
      'timestamp': timestamp.toIso8601String(),
      'error': error,
      'metadata': metadata,
    };
  }
}

/// Overall performance statistics
class PerformanceStats {
  final int totalOperations;
  final int successfulOperations;
  final int failedOperations;
  final double successRate;
  final Duration averageDuration;
  final Duration medianDuration;
  final Duration minDuration;
  final Duration maxDuration;
  final Duration totalDuration;
  
  const PerformanceStats({
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.successRate,
    required this.averageDuration,
    required this.medianDuration,
    required this.minDuration,
    required this.maxDuration,
    required this.totalDuration,
  });
  
  factory PerformanceStats.empty() {
    return const PerformanceStats(
      totalOperations: 0,
      successfulOperations: 0,
      failedOperations: 0,
      successRate: 1.0,
      averageDuration: Duration.zero,
      medianDuration: Duration.zero,
      minDuration: Duration.zero,
      maxDuration: Duration.zero,
      totalDuration: Duration.zero,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'total_operations': totalOperations,
      'successful_operations': successfulOperations,
      'failed_operations': failedOperations,
      'success_rate': successRate,
      'average_duration_ms': averageDuration.inMilliseconds,
      'median_duration_ms': medianDuration.inMilliseconds,
      'min_duration_ms': minDuration.inMilliseconds,
      'max_duration_ms': maxDuration.inMilliseconds,
      'total_duration_ms': totalDuration.inMilliseconds,
    };
  }
}

/// Statistics for a specific operation
class OperationStats {
  final String operation;
  final int totalCount;
  final int successCount;
  final int failureCount;
  final Duration totalDuration;
  final Duration? minDuration;
  final Duration? maxDuration;
  final DateTime lastUpdated;
  
  const OperationStats({
    required this.operation,
    required this.totalCount,
    required this.successCount,
    required this.failureCount,
    required this.totalDuration,
    this.minDuration,
    this.maxDuration,
    required this.lastUpdated,
  });
  
  factory OperationStats.empty(String operation) {
    return OperationStats(
      operation: operation,
      totalCount: 0,
      successCount: 0,
      failureCount: 0,
      totalDuration: Duration.zero,
      lastUpdated: DateTime.now(),
    );
  }
  
  double get successRate => totalCount > 0 ? successCount / totalCount : 1.0;
  
  Duration get averageDuration => totalCount > 0 
      ? Duration(microseconds: (totalDuration.inMicroseconds / totalCount).round())
      : Duration.zero;
  
  Map<String, dynamic> toMap() {
    return {
      'operation': operation,
      'total_count': totalCount,
      'success_count': successCount,
      'failure_count': failureCount,
      'success_rate': successRate,
      'total_duration_ms': totalDuration.inMilliseconds,
      'average_duration_ms': averageDuration.inMilliseconds,
      'min_duration_ms': minDuration?.inMilliseconds,
      'max_duration_ms': maxDuration?.inMilliseconds,
      'last_updated': lastUpdated.toIso8601String(),
    };
  }
}

/// Performance trends over time
class PerformanceTrends {
  final int recentHourMetrics;
  final double recentHourSuccessRate;
  final Duration recentHourAverageDuration;
  final int dailyMetrics;
  final double dailySuccessRate;
  final Duration dailyAverageDuration;
  final bool isPerformanceDegrading;
  
  const PerformanceTrends({
    required this.recentHourMetrics,
    required this.recentHourSuccessRate,
    required this.recentHourAverageDuration,
    required this.dailyMetrics,
    required this.dailySuccessRate,
    required this.dailyAverageDuration,
    required this.isPerformanceDegrading,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'recent_hour_metrics': recentHourMetrics,
      'recent_hour_success_rate': recentHourSuccessRate,
      'recent_hour_average_duration_ms': recentHourAverageDuration.inMilliseconds,
      'daily_metrics': dailyMetrics,
      'daily_success_rate': dailySuccessRate,
      'daily_average_duration_ms': dailyAverageDuration.inMilliseconds,
      'is_performance_degrading': isPerformanceDegrading,
    };
  }
}

/// Memory usage statistics
class MemoryUsageStats {
  final double averageMemoryMB;
  final double medianMemoryMB;
  final double minMemoryMB;
  final double maxMemoryMB;
  final int samplesCount;
  
  const MemoryUsageStats({
    required this.averageMemoryMB,
    required this.medianMemoryMB,
    required this.minMemoryMB,
    required this.maxMemoryMB,
    required this.samplesCount,
  });
  
  factory MemoryUsageStats.empty() {
    return const MemoryUsageStats(
      averageMemoryMB: 0.0,
      medianMemoryMB: 0.0,
      minMemoryMB: 0.0,
      maxMemoryMB: 0.0,
      samplesCount: 0,
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'average_memory_mb': averageMemoryMB,
      'median_memory_mb': medianMemoryMB,
      'min_memory_mb': minMemoryMB,
      'max_memory_mb': maxMemoryMB,
      'samples_count': samplesCount,
    };
  }
}

/// Cache performance statistics
class CachePerformanceStats {
  final int cacheHits;
  final int cacheMisses;
  final double cacheHitRate;
  final Duration averageCacheHitDuration;
  final Duration averageCacheMissDuration;
  
  const CachePerformanceStats({
    required this.cacheHits,
    required this.cacheMisses,
    required this.cacheHitRate,
    required this.averageCacheHitDuration,
    required this.averageCacheMissDuration,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'cache_hits': cacheHits,
      'cache_misses': cacheMisses,
      'cache_hit_rate': cacheHitRate,
      'average_cache_hit_duration_ms': averageCacheHitDuration.inMilliseconds,
      'average_cache_miss_duration_ms': averageCacheMissDuration.inMilliseconds,
    };
  }
}