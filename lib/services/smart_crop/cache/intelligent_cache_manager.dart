import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';

import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';

import 'crop_cache_database.dart';
import 'crop_cache_entry.dart';

/// Enhanced cache manager with analyzer-specific caching and intelligent features
class IntelligentCacheManager {
  static final IntelligentCacheManager _instance =
      IntelligentCacheManager._internal();
  static CropCacheDatabase? _database;

  // Cache warming configuration
  static const List<ui.Size> _commonSizes = [
    ui.Size(1080, 1920), // 9:16 (common phone)
    ui.Size(1440, 2560), // 9:16 (high-res phone)
    ui.Size(1080, 2340), // 18.5:9 (modern phone)
    ui.Size(1200, 1920), // 10:16 (tablet portrait)
    ui.Size(1920, 1200), // 16:10 (tablet landscape)
    ui.Size(2560, 1440), // 16:9 (landscape)
  ];

  // Cache warming queue and processing
  final Set<String> _warmingQueue = <String>{};
  final Map<String, Completer<void>> _warmingCompleters = {};
  Timer? _warmingTimer;

  factory IntelligentCacheManager() => _instance;

  IntelligentCacheManager._internal();

  /// Gets the database instance
  CropCacheDatabase get _db {
    _database ??= CropCacheDatabase();
    return _database!;
  }

  /// Generates analyzer-specific cache key
  String generateAnalyzerCacheKey(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
    String analyzerName,
  ) {
    final analyzerSettings = <String, dynamic>{}; // Simplified for now
    final analyzerHash = _generateAnalyzerSettingsHash(analyzerSettings);
    final sizeString =
        '${targetSize.width.toInt()}x${targetSize.height.toInt()}';
    final keyString = '${imageUrl}_${sizeString}_${analyzerName}_$analyzerHash';

    final bytes = utf8.encode(keyString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates hash for analyzer-specific settings
  String _generateAnalyzerSettingsHash(Map<String, dynamic> analyzerSettings) {
    final settingsString = json.encode(analyzerSettings);
    final bytes = utf8.encode(settingsString);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16);
  }

  /// Gets cached result for specific analyzer
  Future<CropCoordinates?> getCachedAnalyzerResult(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
    String analyzerName,
  ) async {
    try {
      final cacheKey = generateAnalyzerCacheKey(
          imageUrl, targetSize, settings, analyzerName);
      final entry = await _db.getByCacheKey(cacheKey);

      if (entry == null) return null;

      // Check if entry is expired
      if (entry.isExpired()) {
        await _db.delete(entry.id!);
        return null;
      }

      return entry.coordinates;
    } catch (e) {
      return null;
    }
  }

  /// Caches analyzer-specific result
  Future<bool> cacheAnalyzerResult(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
    String analyzerName,
    CropCoordinates coordinates,
  ) async {
    try {
      final cacheKey = generateAnalyzerCacheKey(
          imageUrl, targetSize, settings, analyzerName);
      final analyzerSettings = <String, dynamic>{}; // Simplified for now
      final settingsHash = _generateAnalyzerSettingsHash(analyzerSettings);

      final entry = CropCacheEntry.create(
        cacheKey: cacheKey,
        imageUrl: imageUrl,
        targetWidth: targetSize.width,
        targetHeight: targetSize.height,
        settingsHash: settingsHash,
        coordinates: coordinates,
      );

      await _db.insert(entry);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Starts cache warming for an image
  Future<void> warmCache(
    String imageUrl,
    ui.Image sourceImage,
    CropSettings settings,
    Future<CropCoordinates> Function(ui.Size, String) analyzer,
    List<String> analyzerNames,
  ) async {
    if (_warmingQueue.contains(imageUrl)) {
      // Already warming, wait for completion
      final completer = _warmingCompleters[imageUrl];
      if (completer != null) {
        await completer.future;
      }
      return;
    }

    _warmingQueue.add(imageUrl);
    final completer = Completer<void>();
    _warmingCompleters[imageUrl] = completer;

    try {
      await _performCacheWarming(
          imageUrl, sourceImage, settings, analyzer, analyzerNames);
    } finally {
      _warmingQueue.remove(imageUrl);
      _warmingCompleters.remove(imageUrl);
      completer.complete();
    }
  }

  /// Performs actual cache warming
  Future<void> _performCacheWarming(
    String imageUrl,
    ui.Image sourceImage,
    CropSettings settings,
    Future<CropCoordinates> Function(ui.Size, String) analyzer,
    List<String> analyzerNames,
  ) async {
    for (final size in _commonSizes) {
      for (final analyzerName in analyzerNames) {
        try {
          // Check if already cached
          final cached = await getCachedAnalyzerResult(
              imageUrl, size, settings, analyzerName);
          if (cached != null) continue;

          // Analyze and cache
          final coordinates = await analyzer(size, analyzerName);
          await cacheAnalyzerResult(
              imageUrl, size, settings, analyzerName, coordinates);

          // Small delay to avoid overwhelming the system
          await Future.delayed(const Duration(milliseconds: 50));
        } catch (e) {
          // Continue with other combinations if one fails
          continue;
        }
      }
    }
  }

  /// Schedules cache warming with debouncing
  void scheduleWarmCache(
    String imageUrl,
    ui.Image sourceImage,
    CropSettings settings,
    Future<CropCoordinates> Function(ui.Size, String) analyzer,
    List<String> analyzerNames,
  ) {
    _warmingTimer?.cancel();
    _warmingTimer = Timer(const Duration(milliseconds: 500), () {
      warmCache(imageUrl, sourceImage, settings, analyzer, analyzerNames);
    });
  }

  /// Invalidates cache for specific analyzer
  Future<int> invalidateAnalyzerCache(String analyzerName) async {
    try {
      final db = await _db.database;

      // Find entries that contain the analyzer name in their cache key
      return await db.delete(
        'crop_cache',
        where: 'cache_key LIKE ?',
        whereArgs: ['%_${analyzerName}_%'],
      );
    } catch (e) {
      return 0;
    }
  }

  /// Gets cache statistics for specific analyzer
  Future<AnalyzerCacheStats> getAnalyzerStats(String analyzerName) async {
    try {
      final db = await _db.database;

      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_entries,
          AVG(access_count) as avg_access_count,
          MAX(access_count) as max_access_count,
          MIN(created_at) as oldest_entry,
          MAX(created_at) as newest_entry
        FROM crop_cache
        WHERE cache_key LIKE ?
      ''', ['%_${analyzerName}_%']);

      final row = result.first;
      final totalEntries = row['total_entries'] as int;
      final avgAccessCount = (row['avg_access_count'] as double?) ?? 0.0;
      final maxAccessCount = (row['max_access_count'] as int?) ?? 0;
      final oldestEntry = row['oldest_entry'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['oldest_entry'] as int)
          : null;
      final newestEntry = row['newest_entry'] != null
          ? DateTime.fromMillisecondsSinceEpoch(row['newest_entry'] as int)
          : null;

      return AnalyzerCacheStats(
        analyzerName: analyzerName,
        totalEntries: totalEntries,
        averageAccessCount: avgAccessCount,
        maxAccessCount: maxAccessCount,
        oldestEntry: oldestEntry,
        newestEntry: newestEntry,
      );
    } catch (e) {
      return AnalyzerCacheStats(
        analyzerName: analyzerName,
        totalEntries: 0,
        averageAccessCount: 0.0,
        maxAccessCount: 0,
        oldestEntry: null,
        newestEntry: null,
      );
    }
  }

  /// Optimizes cache by removing low-value entries
  Future<CacheOptimizationResult> optimizeCache() async {
    try {
      final db = await _db.database;
      int removedEntries = 0;

      // Remove entries with very low access counts that are old
      final lowValueResult = await db.delete(
        'crop_cache',
        where: 'access_count = 1 AND created_at < ?',
        whereArgs: [
          DateTime.now()
              .subtract(const Duration(days: 3))
              .millisecondsSinceEpoch
        ],
      );
      removedEntries += lowValueResult;

      // Remove duplicate entries (keep the most accessed one)
      final duplicatesResult = await db.rawQuery('''
        SELECT image_url, target_width, target_height, 
               COUNT(*) as count, 
               MAX(access_count) as max_access,
               GROUP_CONCAT(id) as ids
        FROM crop_cache 
        GROUP BY image_url, target_width, target_height
        HAVING COUNT(*) > 1
      ''');

      for (final row in duplicatesResult) {
        final ids = (row['ids'] as String).split(',').map(int.parse).toList();
        final maxAccess = row['max_access'] as int;

        // Keep the entry with highest access count, remove others
        final keepResult = await db.query(
          'crop_cache',
          where: 'id IN (${ids.join(',')}) AND access_count = ?',
          whereArgs: [maxAccess],
          limit: 1,
        );

        if (keepResult.isNotEmpty) {
          final keepId = keepResult.first['id'] as int;
          ids.remove(keepId);

          for (final id in ids) {
            await db.delete('crop_cache', where: 'id = ?', whereArgs: [id]);
            removedEntries++;
          }
        }
      }

      return CacheOptimizationResult(
        success: true,
        removedEntries: removedEntries,
        spaceSavedBytes: removedEntries * 1024, // Estimate
      );
    } catch (e) {
      return CacheOptimizationResult(
        success: false,
        removedEntries: 0,
        spaceSavedBytes: 0,
        error: e.toString(),
      );
    }
  }

  /// Preloads cache for frequently used combinations
  Future<void> preloadFrequentCombinations() async {
    try {
      final db = await _db.database;

      // Find most frequently accessed image URLs
      await db.rawQuery('''
        SELECT image_url, SUM(access_count) as total_access
        FROM crop_cache
        GROUP BY image_url
        ORDER BY total_access DESC
        LIMIT 10
      ''');

      // Find most used analyzer combinations
      await db.rawQuery('''
        SELECT SUBSTR(cache_key, INSTR(cache_key, '_') + 1) as pattern,
               COUNT(*) as usage_count
        FROM crop_cache
        GROUP BY pattern
        ORDER BY usage_count DESC
        LIMIT 5
      ''');

      // This would trigger preloading for these combinations
      // Implementation would depend on having access to the analyzer functions
    } catch (e) {
      // Silently handle errors in preloading
    }
  }

  /// Gets cache effectiveness metrics
  Future<CacheEffectivenessMetrics> getEffectivenessMetrics() async {
    try {
      final db = await _db.database;

      // Calculate hit rate based on access patterns
      final hitRateResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_entries,
          SUM(CASE WHEN access_count > 1 THEN 1 ELSE 0 END) as hit_entries,
          AVG(access_count) as avg_access,
          SUM(access_count) as total_accesses
        FROM crop_cache
      ''');

      final row = hitRateResult.first;
      final totalEntries = row['total_entries'] as int;
      final hitEntries = row['hit_entries'] as int;
      final avgAccess = (row['avg_access'] as double?) ?? 0.0;
      final totalAccesses = row['total_accesses'] as int;

      final hitRate = totalEntries > 0 ? hitEntries / totalEntries : 0.0;
      final accessEfficiency =
          totalEntries > 0 ? totalAccesses / totalEntries : 0.0;

      // Calculate cache age distribution
      final ageResult = await db.rawQuery('''
        SELECT 
          COUNT(CASE WHEN created_at > ? THEN 1 END) as recent_entries,
          COUNT(CASE WHEN created_at BETWEEN ? AND ? THEN 1 END) as medium_entries,
          COUNT(CASE WHEN created_at < ? THEN 1 END) as old_entries
        FROM crop_cache
      ''', [
        DateTime.now()
            .subtract(const Duration(hours: 24))
            .millisecondsSinceEpoch,
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch,
        DateTime.now()
            .subtract(const Duration(hours: 24))
            .millisecondsSinceEpoch,
        DateTime.now().subtract(const Duration(days: 7)).millisecondsSinceEpoch,
      ]);

      final ageRow = ageResult.first;
      final recentEntries = ageRow['recent_entries'] as int;
      final mediumEntries = ageRow['medium_entries'] as int;
      final oldEntries = ageRow['old_entries'] as int;

      return CacheEffectivenessMetrics(
        hitRate: hitRate,
        averageAccessCount: avgAccess,
        accessEfficiency: accessEfficiency,
        totalEntries: totalEntries,
        recentEntries: recentEntries,
        mediumAgeEntries: mediumEntries,
        oldEntries: oldEntries,
      );
    } catch (e) {
      return const CacheEffectivenessMetrics(
        hitRate: 0.0,
        averageAccessCount: 0.0,
        accessEfficiency: 0.0,
        totalEntries: 0,
        recentEntries: 0,
        mediumAgeEntries: 0,
        oldEntries: 0,
      );
    }
  }

  /// Closes the cache manager
  Future<void> close() async {
    _warmingTimer?.cancel();
    _warmingQueue.clear();
    _warmingCompleters.clear();
    await _db.close();
    _database = null;
  }
}

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
