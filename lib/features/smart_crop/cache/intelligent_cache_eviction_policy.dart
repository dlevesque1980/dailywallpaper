import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'crop_cache_database.dart';
import 'intelligent_cache_models.dart';

class IntelligentCacheEvictionPolicy {
  final CropCacheDatabase _database;

  IntelligentCacheEvictionPolicy(this._database);

  /// Optimizes cache by removing low-value entries
  Future<CacheOptimizationResult> optimizeCache() async {
    try {
      final db = await _database.database;
      int removedEntries = 0;

      // Remove entries with very low access counts that are old
      final lowValueResult = await db.delete(
        CropCacheDatabase.tableName,
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
        FROM ${CropCacheDatabase.tableName} 
        GROUP BY image_url, target_width, target_height
        HAVING COUNT(*) > 1
      ''');

      for (final row in duplicatesResult) {
        final ids = (row['ids'] as String).split(',').map(int.parse).toList();
        final maxAccess = row['max_access'] as int;

        // Keep the entry with highest access count, remove others
        final keepResult = await db.query(
          CropCacheDatabase.tableName,
          where: 'id IN (${ids.join(',')}) AND access_count = ?',
          whereArgs: [maxAccess],
          limit: 1,
        );

        if (keepResult.isNotEmpty) {
          final keepId = keepResult.first['id'] as int;
          ids.remove(keepId);

          for (final id in ids) {
            await db.delete(CropCacheDatabase.tableName,
                where: 'id = ?', whereArgs: [id]);
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

  /// Gets cache effectiveness metrics
  Future<CacheEffectivenessMetrics> getEffectivenessMetrics() async {
    try {
      final db = await _database.database;

      // Calculate hit rate based on access patterns
      final hitRateResult = await db.rawQuery('''
        SELECT 
          COUNT(*) as total_entries,
          SUM(CASE WHEN access_count > 1 THEN 1 ELSE 0 END) as hit_entries,
          AVG(access_count) as avg_access,
          SUM(access_count) as total_accesses
        FROM ${CropCacheDatabase.tableName}
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
        FROM ${CropCacheDatabase.tableName}
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
}
