/// Cache hit rate statistics
class CropCacheHitRate {
  final int totalEntries;
  final double averageAccessCount;
  final int maxAccessCount;
  final int minAccessCount;
  final double estimatedHitRate;

  const CropCacheHitRate({
    required this.totalEntries,
    required this.averageAccessCount,
    required this.maxAccessCount,
    required this.minAccessCount,
    required this.estimatedHitRate,
  });

  /// Gets the hit rate as a percentage
  double get hitRatePercentage => estimatedHitRate * 100;

  @override
  String toString() {
    return 'CropCacheHitRate(entries: $totalEntries, hitRate: ${hitRatePercentage.toStringAsFixed(1)}%, '
        'avgAccess: ${averageAccessCount.toStringAsFixed(1)})';
  }
}
