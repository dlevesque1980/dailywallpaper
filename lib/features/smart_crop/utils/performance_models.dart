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
