/// Cache statistics
class CropCacheStats {
  final int totalEntries;
  final int totalSizeBytes;
  final DateTime? oldestEntry;
  final DateTime? newestEntry;
  final double averageAccessCount;

  const CropCacheStats({
    required this.totalEntries,
    required this.totalSizeBytes,
    this.oldestEntry,
    this.newestEntry,
    required this.averageAccessCount,
  });

  /// Gets the cache size in MB
  double get totalSizeMB => totalSizeBytes / (1024 * 1024);

  /// Gets the age of the cache (time span from oldest to newest)
  Duration? get cacheAge {
    if (oldestEntry == null || newestEntry == null) return null;
    return newestEntry!.difference(oldestEntry!);
  }

  @override
  String toString() {
    return 'CropCacheStats(entries: $totalEntries, size: ${totalSizeMB.toStringAsFixed(2)}MB, '
        'avgAccess: ${averageAccessCount.toStringAsFixed(1)}, age: ${cacheAge?.inDays ?? 0}d)';
  }
}

/// Result of cache maintenance operation
class CropCacheMaintenanceResult {
  final int expiredEntriesDeleted;
  final int lruEntriesEvicted;
  final bool success;
  final String? error;

  const CropCacheMaintenanceResult({
    required this.expiredEntriesDeleted,
    required this.lruEntriesEvicted,
    required this.success,
    this.error,
  });

  int get totalEntriesDeleted => expiredEntriesDeleted + lruEntriesEvicted;

  @override
  String toString() {
    return 'CropCacheMaintenanceResult(success: $success, expired: $expiredEntriesDeleted, '
        'lru: $lruEntriesEvicted, total: $totalEntriesDeleted)';
  }
}

/// Exception thrown by cache operations
class CropCacheException implements Exception {
  final String message;

  const CropCacheException(this.message);

  @override
  String toString() => 'CropCacheException: $message';
}
