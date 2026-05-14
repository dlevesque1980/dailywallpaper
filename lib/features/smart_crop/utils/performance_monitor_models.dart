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
      ? Duration(
          microseconds: (totalDuration.inMicroseconds / totalCount).round())
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
      'recent_hour_average_duration_ms':
          recentHourAverageDuration.inMilliseconds,
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
