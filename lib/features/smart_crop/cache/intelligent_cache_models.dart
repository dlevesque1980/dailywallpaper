/// Statistics for analyzer-specific cache
class AnalyzerCacheStats {
  final String analyzerName;
  final int totalEntries;
  final double averageAccessCount;
  final int maxAccessCount;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;

  const AnalyzerCacheStats({
    required this.analyzerName,
    required this.totalEntries,
    required this.averageAccessCount,
    required this.maxAccessCount,
    this.oldestEntry,
    this.newestEntry,
  });

  Duration? get cacheAge {
    if (oldestEntry == null || newestEntry == null) return null;
    return newestEntry!.difference(oldestEntry!);
  }

  @override
  String toString() {
    return 'AnalyzerCacheStats($analyzerName: entries=$totalEntries, '
        'avgAccess=${averageAccessCount.toStringAsFixed(1)}, '
        'age=${cacheAge?.inDays ?? 0}d)';
  }
}

/// Result of cache optimization
class CacheOptimizationResult {
  final bool success;
  final int removedEntries;
  final int spaceSavedBytes;
  final String? error;

  const CacheOptimizationResult({
    required this.success,
    required this.removedEntries,
    required this.spaceSavedBytes,
    this.error,
  });

  double get spaceSavedMB => spaceSavedBytes / (1024 * 1024);

  @override
  String toString() {
    return 'CacheOptimizationResult(success: $success, removed: $removedEntries, '
        'saved: ${spaceSavedMB.toStringAsFixed(2)}MB)';
  }
}

/// Cache effectiveness metrics
class CacheEffectivenessMetrics {
  final double hitRate;
  final double averageAccessCount;
  final double accessEfficiency;
  final int totalEntries;
  final int recentEntries;
  final int mediumAgeEntries;
  final int oldEntries;

  const CacheEffectivenessMetrics({
    required this.hitRate,
    required this.averageAccessCount,
    required this.accessEfficiency,
    required this.totalEntries,
    required this.recentEntries,
    required this.mediumAgeEntries,
    required this.oldEntries,
  });

  double get hitRatePercentage => hitRate * 100;
  double get freshnessFactor =>
      totalEntries > 0 ? recentEntries / totalEntries : 0.0;

  @override
  String toString() {
    return 'CacheEffectivenessMetrics(hitRate: ${hitRatePercentage.toStringAsFixed(1)}%, '
        'efficiency: ${accessEfficiency.toStringAsFixed(1)}, '
        'freshness: ${(freshnessFactor * 100).toStringAsFixed(1)}%)';
  }
}
