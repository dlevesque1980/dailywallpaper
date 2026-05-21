import 'package:sqflite/sqflite.dart';
import 'crop_cache_entry.dart';
import 'crop_cache_models.dart';
import 'crop_cache_database.dart';

class CropCacheDao {
  final CropCacheDatabase _database;

  CropCacheDao(this._database);

  Future<int> insert(CropCacheEntry entry) async {
    final db = await _database.database;
    try {
      return await db.insert(
        CropCacheDatabase.tableName,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CropCacheException('Failed to insert cache entry: $e');
    }
  }

  Future<CropCacheEntry?> getByCacheKey(String cacheKey) async {
    final db = await _database.database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        CropCacheDatabase.tableName,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );
      if (maps.isEmpty) return null;
      final entry = CropCacheEntry.fromMap(maps.first);
      await _updateAccess(db, entry);
      return entry.copyWithAccess();
    } catch (e) {
      throw CropCacheException('Failed to get cache entry: $e');
    }
  }

  Future<List<CropCacheEntry>> getByImageUrl(String imageUrl) async {
    final db = await _database.database;
    try {
      final List<Map<String, dynamic>> maps = await db.query(
        CropCacheDatabase.tableName,
        where: 'image_url = ?',
        whereArgs: [imageUrl],
        orderBy: 'last_accessed_at DESC',
      );
      return maps.map((map) => CropCacheEntry.fromMap(map)).toList();
    } catch (e) {
      throw CropCacheException('Failed to get cache entries by image URL: $e');
    }
  }

  Future<void> _updateAccess(Database db, CropCacheEntry entry) async {
    await db.update(
      CropCacheDatabase.tableName,
      {
        'last_accessed_at': DateTime.now().millisecondsSinceEpoch,
        'access_count': entry.accessCount + 1,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  Future<int> update(CropCacheEntry entry) async {
    final db = await _database.database;
    try {
      return await db.update(
        CropCacheDatabase.tableName,
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    } catch (e) {
      throw CropCacheException('Failed to update cache entry: $e');
    }
  }

  Future<int> delete(int id) async {
    final db = await _database.database;
    try {
      return await db.delete(
        CropCacheDatabase.tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CropCacheException('Failed to delete cache entry: $e');
    }
  }

  Future<int> deleteByCacheKey(String cacheKey) async {
    final db = await _database.database;
    try {
      return await db.delete(
        CropCacheDatabase.tableName,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );
    } catch (e) {
      throw CropCacheException('Failed to delete cache entry by key: $e');
    }
  }

  Future<int> deleteByImageUrl(String imageUrl) async {
    final db = await _database.database;
    try {
      return await db.delete(
        CropCacheDatabase.tableName,
        where: 'image_url = ?',
        whereArgs: [imageUrl],
      );
    } catch (e) {
      throw CropCacheException(
          'Failed to delete cache entries by image URL: $e');
    }
  }

  Future<int> deleteExpired({Duration ttl = const Duration(days: 7)}) async {
    final db = await _database.database;
    final cutoffTime = DateTime.now().subtract(ttl).millisecondsSinceEpoch;
    try {
      return await db.delete(
        CropCacheDatabase.tableName,
        where: 'created_at < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      throw CropCacheException('Failed to delete expired cache entries: $e');
    }
  }

  Future<int> evictLRU({int maxEntries = 1000}) async {
    final db = await _database.database;
    try {
      return await _evictLRUBatched(db, maxEntries);
    } catch (e) {
      throw CropCacheException('Failed to perform LRU eviction: $e');
    }
  }

  Future<int> _evictLRUBatched(Database db, int maxEntries) async {
    const batchSize = 50;
    int totalDeleted = 0;
    for (int iteration = 0; iteration < 100; iteration++) {
      final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM ${CropCacheDatabase.tableName}');
      final currentCount = countResult.first['count'] as int;
      if (currentCount <= maxEntries) break;
      final batchToDelete = ((currentCount - maxEntries).clamp(1, batchSize));
      final deleted = await db.rawDelete('''
        DELETE FROM ${CropCacheDatabase.tableName} 
        WHERE id IN (
          SELECT id FROM ${CropCacheDatabase.tableName} 
          ORDER BY last_accessed_at ASC 
          LIMIT ?
        )
      ''', [batchToDelete]);
      totalDeleted += deleted;
      if (deleted == 0) break;
      if (iteration % 10 == 9) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }
    return totalDeleted;
  }

  Future<CropCacheStats> getStats() async {
    final db = await _database.database;
    try {
      final countResult = await db.rawQuery(
          'SELECT COUNT(*) as count FROM ${CropCacheDatabase.tableName}');
      final totalEntries = countResult.first['count'] as int;

      final sizeResult = await db.rawQuery(
          'SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()');
      final totalSizeBytes = sizeResult.first['size'] as int;

      DateTime? oldestEntry, newestEntry;
      if (totalEntries > 0) {
        final oldestResult = await db.query(
          CropCacheDatabase.tableName,
          columns: ['created_at'],
          orderBy: 'created_at ASC',
          limit: 1,
        );
        oldestEntry = DateTime.fromMillisecondsSinceEpoch(
            oldestResult.first['created_at'] as int);

        final newestResult = await db.query(
          CropCacheDatabase.tableName,
          columns: ['created_at'],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        newestEntry = DateTime.fromMillisecondsSinceEpoch(
            newestResult.first['created_at'] as int);
      }

      final avgAccessResult = await db.rawQuery(
          'SELECT AVG(access_count) as avg_access FROM ${CropCacheDatabase.tableName}');
      final avgAccessCount =
          (avgAccessResult.first['avg_access'] as double?) ?? 0.0;

      return CropCacheStats(
        totalEntries: totalEntries,
        totalSizeBytes: totalSizeBytes,
        oldestEntry: oldestEntry,
        newestEntry: newestEntry,
        averageAccessCount: avgAccessCount,
      );
    } catch (e) {
      throw CropCacheException('Failed to get cache statistics: $e');
    }
  }

  Future<int> clear() async {
    final db = await _database.database;
    try {
      return await _clearBatched(db);
    } catch (e) {
      throw CropCacheException('Failed to clear cache: $e');
    }
  }

  Future<int> _clearBatched(Database db) async {
    const batchSize = 1000;
    int totalDeleted = 0;
    final countResult = await db.rawQuery(
        'SELECT COUNT(*) as count FROM ${CropCacheDatabase.tableName}');
    final totalCount = countResult.first['count'] as int;

    if (totalCount <= batchSize) {
      return await db.delete(CropCacheDatabase.tableName);
    }

    for (int iteration = 0; iteration < 1000; iteration++) {
      final deleted = await db.rawDelete('''
        DELETE FROM ${CropCacheDatabase.tableName} 
        WHERE id IN (
          SELECT id FROM ${CropCacheDatabase.tableName} 
          LIMIT ?
        )
      ''', [batchSize]);
      totalDeleted += deleted;
      if (deleted == 0) break;
      if (iteration % 10 == 9) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }
    return totalDeleted;
  }

  Future<CropCacheMaintenanceResult> performMaintenance({
    Duration ttl = const Duration(days: 7),
    int maxEntries = 1000,
  }) async {
    try {
      final expiredDeleted = await deleteExpired(ttl: ttl);
      final lruEvicted = await evictLRU(maxEntries: maxEntries);
      return CropCacheMaintenanceResult(
        expiredEntriesDeleted: expiredDeleted,
        lruEntriesEvicted: lruEvicted,
        success: true,
      );
    } catch (e) {
      return CropCacheMaintenanceResult(
        expiredEntriesDeleted: 0,
        lruEntriesEvicted: 0,
        success: false,
        error: e.toString(),
      );
    }
  }
}
