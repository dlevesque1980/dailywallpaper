import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:crypto/crypto.dart';

import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';
import 'crop_cache_database.dart';
import 'crop_cache_entry.dart';

/// Manager for crop coordinate caching with database persistence
class CropCacheManager {
  static final CropCacheManager _instance = CropCacheManager._internal();
  static CropCacheDatabase? _database;
  
  factory CropCacheManager() => _instance;
  
  CropCacheManager._internal();

  /// Gets the database instance
  CropCacheDatabase get _db {
    _database ??= CropCacheDatabase();
    return _database!;
  }

  /// Generates a cache key from image URL, target size, and settings
  String generateCacheKey(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
  ) {
    final settingsHash = _generateSettingsHash(settings);
    final sizeString = '${targetSize.width.toInt()}x${targetSize.height.toInt()}';
    final keyString = '${imageUrl}_${sizeString}_$settingsHash';
    
    // Create a hash of the key string for consistent length
    final bytes = utf8.encode(keyString);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Generates a hash for crop settings to detect changes
  String _generateSettingsHash(CropSettings settings) {
    final settingsMap = {
      'aggressiveness': settings.aggressiveness.index,
      'enableRuleOfThirds': settings.enableRuleOfThirds,
      'enableEntropyAnalysis': settings.enableEntropyAnalysis,
      'enableEdgeDetection': settings.enableEdgeDetection,
      'enableCenterWeighting': settings.enableCenterWeighting,
      'maxProcessingTime': settings.maxProcessingTime.inMilliseconds,
    };
    
    final settingsString = json.encode(settingsMap);
    final bytes = utf8.encode(settingsString);
    final digest = sha256.convert(bytes);
    return digest.toString().substring(0, 16); // Use first 16 chars
  }

  /// Gets cached crop coordinates
  Future<CropCoordinates?> getCachedCrop(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    try {
      final cacheKey = generateCacheKey(imageUrl, targetSize, settings);
      final entry = await _db.getByCacheKey(cacheKey);
      
      if (entry == null) return null;
      
      // Check if entry is expired
      if (entry.isExpired()) {
        await _db.delete(entry.id!);
        return null;
      }
      
      // Verify settings haven't changed
      final currentSettingsHash = _generateSettingsHash(settings);
      if (entry.settingsHash != currentSettingsHash) {
        await _db.delete(entry.id!);
        return null;
      }
      
      return entry.coordinates;
      
    } catch (e) {
      // Log error but don't throw - cache misses should be graceful
      return null;
    }
  }

  /// Caches crop coordinates
  Future<bool> cacheCrop(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
    CropCoordinates coordinates,
  ) async {
    try {
      final cacheKey = generateCacheKey(imageUrl, targetSize, settings);
      final settingsHash = _generateSettingsHash(settings);
      
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
      // Log error but don't throw - cache failures shouldn't break the app
      return false;
    }
  }

  /// Gets all cached crops for an image URL
  Future<List<CropCacheEntry>> getCachedCropsForImage(String imageUrl) async {
    try {
      return await _db.getByImageUrl(imageUrl);
    } catch (e) {
      return [];
    }
  }

  /// Invalidates cache entries for a specific image URL
  Future<int> invalidateImageCache(String imageUrl) async {
    try {
      return await _db.deleteByImageUrl(imageUrl);
    } catch (e) {
      return 0;
    }
  }

  /// Invalidates cache entries with old settings
  Future<int> invalidateSettingsCache(CropSettings newSettings) async {
    try {
      final newSettingsHash = _generateSettingsHash(newSettings);
      final db = await _db.database;
      
      // Delete entries with different settings hash
      return await db.delete(
        'crop_cache',
        where: 'settings_hash != ?',
        whereArgs: [newSettingsHash],
      );
    } catch (e) {
      return 0;
    }
  }

  /// Clears all cached crops
  Future<int> clearCache() async {
    try {
      return await _db.clear();
    } catch (e) {
      return 0;
    }
  }

  /// Gets cache statistics
  Future<CropCacheStats> getStats() async {
    try {
      return await _db.getStats();
    } catch (e) {
      return const CropCacheStats(
        totalEntries: 0,
        totalSizeBytes: 0,
        averageAccessCount: 0.0,
      );
    }
  }

  /// Performs cache maintenance (cleanup and optimization)
  Future<CropCacheMaintenanceResult> performMaintenance({
    Duration ttl = const Duration(days: 7),
    int maxEntries = 1000,
  }) async {
    return await _db.performMaintenance(ttl: ttl, maxEntries: maxEntries);
  }

  /// Preloads cache for common screen sizes
  Future<void> preloadCommonSizes(
    String imageUrl,
    ui.Image sourceImage,
    CropSettings settings,
    Future<CropCoordinates> Function(ui.Size) analyzer,
  ) async {
    // Common screen aspect ratios and sizes
    final commonSizes = [
      const ui.Size(1080, 1920), // 9:16 (common phone)
      const ui.Size(1440, 2560), // 9:16 (high-res phone)
      const ui.Size(1080, 2340), // 18.5:9 (modern phone)
      const ui.Size(1200, 1920), // 10:16 (tablet portrait)
      const ui.Size(1920, 1200), // 16:10 (tablet landscape)
      const ui.Size(2560, 1440), // 16:9 (landscape)
    ];

    for (final size in commonSizes) {
      try {
        // Check if already cached
        final cached = await getCachedCrop(imageUrl, size, settings);
        if (cached != null) continue;
        
        // Analyze and cache
        final coordinates = await analyzer(size);
        await cacheCrop(imageUrl, size, settings, coordinates);
        
        // Small delay to avoid overwhelming the system
        await Future.delayed(const Duration(milliseconds: 100));
        
      } catch (e) {
        // Continue with other sizes if one fails
        continue;
      }
    }
  }

  /// Gets cache hit rate statistics
  Future<CropCacheHitRate> getHitRateStats() async {
    try {
      final db = await _db.database;
      
      // This is a simplified hit rate calculation
      // In a real implementation, you'd track hits/misses separately
      final result = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_entries,
          AVG(access_count) as avg_access_count,
          MAX(access_count) as max_access_count,
          MIN(access_count) as min_access_count
        FROM crop_cache
      ''');
      
      final row = result.first;
      final totalEntries = row['total_entries'] as int;
      final avgAccessCount = (row['avg_access_count'] as double?) ?? 0.0;
      final maxAccessCount = (row['max_access_count'] as int?) ?? 0;
      final minAccessCount = (row['min_access_count'] as int?) ?? 0;
      
      // Estimate hit rate based on access patterns
      // Entries with access_count > 1 indicate cache hits
      final hitResult = await db.rawQuery('''
        SELECT COUNT(*) as hit_entries
        FROM crop_cache 
        WHERE access_count > 1
      ''');
      
      final hitEntries = hitResult.first['hit_entries'] as int;
      final estimatedHitRate = totalEntries > 0 ? hitEntries / totalEntries : 0.0;
      
      return CropCacheHitRate(
        totalEntries: totalEntries,
        averageAccessCount: avgAccessCount,
        maxAccessCount: maxAccessCount,
        minAccessCount: minAccessCount,
        estimatedHitRate: estimatedHitRate,
      );
      
    } catch (e) {
      return const CropCacheHitRate(
        totalEntries: 0,
        averageAccessCount: 0.0,
        maxAccessCount: 0,
        minAccessCount: 0,
        estimatedHitRate: 0.0,
      );
    }
  }

  /// Optimizes cache by removing duplicate or similar entries
  Future<int> optimizeCache() async {
    try {
      final db = await _db.database;
      
      // Find and remove duplicate cache keys (shouldn't happen but just in case)
      final duplicatesResult = await db.rawQuery('''
        SELECT cache_key, COUNT(*) as count, MIN(id) as keep_id
        FROM crop_cache 
        GROUP BY cache_key 
        HAVING COUNT(*) > 1
      ''');
      
      int deletedCount = 0;
      
      for (final row in duplicatesResult) {
        final cacheKey = row['cache_key'] as String;
        final keepId = row['keep_id'] as int;
        
        // Delete all but the oldest entry for this cache key
        final deleted = await db.delete(
          'crop_cache',
          where: 'cache_key = ? AND id != ?',
          whereArgs: [cacheKey, keepId],
        );
        
        deletedCount += deleted;
      }
      
      return deletedCount;
      
    } catch (e) {
      return 0;
    }
  }

  /// Closes the cache manager and database connection
  Future<void> close() async {
    await _db.close();
    _database = null;
  }
}

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