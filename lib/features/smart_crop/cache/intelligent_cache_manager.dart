import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';

import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';

import 'crop_cache_database.dart';
import 'crop_cache_entry.dart';
import 'crop_cache_dao.dart';
import 'intelligent_cache_models.dart';
import 'intelligent_cache_eviction_policy.dart';

/// Enhanced cache manager with analyzer-specific caching and intelligent features
class IntelligentCacheManager {
  static final IntelligentCacheManager _instance =
      IntelligentCacheManager._internal();
  static CropCacheDatabase? _database;
  static CropCacheDao? _cacheDao;
  static IntelligentCacheEvictionPolicy? _evictionPolicy;

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

  /// Gets the DAO instance
  CropCacheDao get _dao {
    _cacheDao ??= CropCacheDao(_db);
    return _cacheDao!;
  }

  /// Gets the eviction policy instance
  IntelligentCacheEvictionPolicy get _policy {
    _evictionPolicy ??= IntelligentCacheEvictionPolicy(_db);
    return _evictionPolicy!;
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
      final entry = await _dao.getByCacheKey(cacheKey);

      if (entry == null) return null;

      // Check if entry is expired
      if (entry.isExpired()) {
        await _dao.delete(entry.id!);
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

      await _dao.insert(entry);
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
        CropCacheDatabase.tableName,
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
        FROM ${CropCacheDatabase.tableName}
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
    return await _policy.optimizeCache();
  }

  /// Preloads cache for frequently used combinations
  Future<void> preloadFrequentCombinations() async {
    try {
      final db = await _db.database;

      // Find most frequently accessed image URLs
      await db.rawQuery('''
        SELECT image_url, SUM(access_count) as total_access
        FROM ${CropCacheDatabase.tableName}
        GROUP BY image_url
        ORDER BY total_access DESC
        LIMIT 10
      ''');

      // Find most used analyzer combinations
      await db.rawQuery('''
        SELECT SUBSTR(cache_key, INSTR(cache_key, '_') + 1) as pattern,
               COUNT(*) as usage_count
        FROM ${CropCacheDatabase.tableName}
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
    return await _policy.getEffectivenessMetrics();
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
