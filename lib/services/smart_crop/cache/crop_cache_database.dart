import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'crop_cache_entry.dart';

/// Database manager for crop cache entries
class CropCacheDatabase {
  static const String _databaseName = 'crop_cache.db';
  static const int _databaseVersion = 2;
  static const String _tableName = 'crop_cache';

  static Database? _database;
  static final CropCacheDatabase _instance = CropCacheDatabase._internal();

  /// Override database path for testing (set before first use)
  @visibleForTesting
  static String? testDatabasePath;

  factory CropCacheDatabase() => _instance;

  CropCacheDatabase._internal();

  /// Gets the database instance, creating it if necessary
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initializes the database
  Future<Database> _initDatabase() async {
    final String path;
    if (testDatabasePath != null) {
      path = testDatabasePath!;
    } else {
      final documentsDirectory = await getDatabasesPath();
      path = join(documentsDirectory, _databaseName);
    }

    return await openDatabase(
      path,
      version: _databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  /// Creates the database tables
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $_tableName (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        cache_key TEXT NOT NULL UNIQUE,
        image_url TEXT NOT NULL,
        target_width REAL NOT NULL,
        target_height REAL NOT NULL,
        settings_hash TEXT NOT NULL,
        crop_x REAL NOT NULL,
        crop_y REAL NOT NULL,
        crop_width REAL NOT NULL,
        crop_height REAL NOT NULL,
        crop_confidence REAL NOT NULL,
        crop_strategy TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        last_accessed_at INTEGER NOT NULL,
        access_count INTEGER NOT NULL DEFAULT 1
      )
    ''');

    // Create indexes for better performance
    await db.execute('''
      CREATE INDEX idx_cache_key ON $_tableName (cache_key)
    ''');

    await db.execute('''
      CREATE INDEX idx_image_url ON $_tableName (image_url)
    ''');

    await db.execute('''
      CREATE INDEX idx_created_at ON $_tableName (created_at)
    ''');

    await db.execute('''
      CREATE INDEX idx_last_accessed_at ON $_tableName (last_accessed_at)
    ''');

    await _createMlSubjectCacheTable(db);
  }

  /// Creates the ml_subject_cache table and its index
  Future<void> _createMlSubjectCacheTable(Database db) async {
    await db.execute('''
      CREATE TABLE ml_subject_cache (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        image_url TEXT NOT NULL UNIQUE,
        subject_x REAL NOT NULL,
        subject_y REAL NOT NULL,
        subject_width REAL NOT NULL,
        subject_height REAL NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_ml_cache_image_url ON ml_subject_cache (image_url)
    ''');
  }

  /// Handles database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMlSubjectCacheTable(db);
    }
  }

  /// Inserts a new cache entry
  Future<int> insert(CropCacheEntry entry) async {
    final db = await database;

    try {
      return await db.insert(
        _tableName,
        entry.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    } catch (e) {
      throw CropCacheException('Failed to insert cache entry: $e');
    }
  }

  /// Gets a cache entry by cache key
  Future<CropCacheEntry?> getByCacheKey(String cacheKey) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
        limit: 1,
      );

      if (maps.isEmpty) return null;

      final entry = CropCacheEntry.fromMap(maps.first);

      // Update access information
      await _updateAccess(db, entry);

      return entry.copyWithAccess();
    } catch (e) {
      throw CropCacheException('Failed to get cache entry: $e');
    }
  }

  /// Gets all cache entries for an image URL
  Future<List<CropCacheEntry>> getByImageUrl(String imageUrl) async {
    final db = await database;

    try {
      final List<Map<String, dynamic>> maps = await db.query(
        _tableName,
        where: 'image_url = ?',
        whereArgs: [imageUrl],
        orderBy: 'last_accessed_at DESC',
      );

      return maps.map((map) => CropCacheEntry.fromMap(map)).toList();
    } catch (e) {
      throw CropCacheException('Failed to get cache entries by image URL: $e');
    }
  }

  /// Updates the access information for a cache entry
  Future<void> _updateAccess(Database db, CropCacheEntry entry) async {
    await db.update(
      _tableName,
      {
        'last_accessed_at': DateTime.now().millisecondsSinceEpoch,
        'access_count': entry.accessCount + 1,
      },
      where: 'id = ?',
      whereArgs: [entry.id],
    );
  }

  /// Updates a cache entry
  Future<int> update(CropCacheEntry entry) async {
    final db = await database;

    try {
      return await db.update(
        _tableName,
        entry.toMap(),
        where: 'id = ?',
        whereArgs: [entry.id],
      );
    } catch (e) {
      throw CropCacheException('Failed to update cache entry: $e');
    }
  }

  /// Deletes a cache entry by ID
  Future<int> delete(int id) async {
    final db = await database;

    try {
      return await db.delete(
        _tableName,
        where: 'id = ?',
        whereArgs: [id],
      );
    } catch (e) {
      throw CropCacheException('Failed to delete cache entry: $e');
    }
  }

  /// Deletes cache entries by cache key
  Future<int> deleteByCacheKey(String cacheKey) async {
    final db = await database;

    try {
      return await db.delete(
        _tableName,
        where: 'cache_key = ?',
        whereArgs: [cacheKey],
      );
    } catch (e) {
      throw CropCacheException('Failed to delete cache entry by key: $e');
    }
  }

  /// Deletes all cache entries for an image URL
  Future<int> deleteByImageUrl(String imageUrl) async {
    final db = await database;

    try {
      return await db.delete(
        _tableName,
        where: 'image_url = ?',
        whereArgs: [imageUrl],
      );
    } catch (e) {
      throw CropCacheException(
          'Failed to delete cache entries by image URL: $e');
    }
  }

  /// Deletes expired cache entries
  Future<int> deleteExpired({Duration ttl = const Duration(days: 7)}) async {
    final db = await database;
    final cutoffTime = DateTime.now().subtract(ttl).millisecondsSinceEpoch;

    try {
      return await db.delete(
        _tableName,
        where: 'created_at < ?',
        whereArgs: [cutoffTime],
      );
    } catch (e) {
      throw CropCacheException('Failed to delete expired cache entries: $e');
    }
  }

  /// Performs LRU eviction to keep cache size under limit
  Future<int> evictLRU({int maxEntries = 1000}) async {
    final db = await database;

    try {
      // Use a more efficient approach with batched deletion to avoid blocking
      return await _evictLRUBatched(db, maxEntries);
    } catch (e) {
      throw CropCacheException('Failed to perform LRU eviction: $e');
    }
  }

  /// Performs LRU eviction using batched deletion to avoid blocking
  Future<int> _evictLRUBatched(Database db, int maxEntries) async {
    const batchSize = 50; // Delete in small batches to avoid blocking
    int totalDeleted = 0;

    // Limit iterations to prevent infinite loops
    for (int iteration = 0; iteration < 100; iteration++) {
      // Check current entry count efficiently
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      final currentCount = countResult.first['count'] as int;

      if (currentCount <= maxEntries) break;

      // Delete a small batch of oldest entries
      final batchToDelete = ((currentCount - maxEntries).clamp(1, batchSize));

      // Use a more efficient deletion approach
      final deleted = await db.rawDelete('''
        DELETE FROM $_tableName 
        WHERE id IN (
          SELECT id FROM $_tableName 
          ORDER BY last_accessed_at ASC 
          LIMIT ?
        )
      ''', [batchToDelete]);

      totalDeleted += deleted;

      // If no entries were deleted, break to avoid infinite loop
      if (deleted == 0) break;

      // Add a small delay between batches to prevent blocking the UI
      if (iteration % 10 == 9) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    return totalDeleted;
  }

  /// Gets cache statistics
  Future<CropCacheStats> getStats() async {
    final db = await database;

    try {
      // Get total count
      final countResult =
          await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      final totalEntries = countResult.first['count'] as int;

      // Get total size (approximate)
      final sizeResult = await db.rawQuery(
          'SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()');
      final totalSizeBytes = sizeResult.first['size'] as int;

      // Get oldest and newest entries
      DateTime? oldestEntry, newestEntry;
      if (totalEntries > 0) {
        final oldestResult = await db.query(
          _tableName,
          columns: ['created_at'],
          orderBy: 'created_at ASC',
          limit: 1,
        );
        oldestEntry = DateTime.fromMillisecondsSinceEpoch(
            oldestResult.first['created_at'] as int);

        final newestResult = await db.query(
          _tableName,
          columns: ['created_at'],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        newestEntry = DateTime.fromMillisecondsSinceEpoch(
            newestResult.first['created_at'] as int);
      }

      // Get average access count
      final avgAccessResult = await db
          .rawQuery('SELECT AVG(access_count) as avg_access FROM $_tableName');
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

  /// Clears all cache entries
  Future<int> clear() async {
    final db = await database;

    try {
      // For very large tables, use batched deletion to avoid blocking
      return await _clearBatched(db);
    } catch (e) {
      throw CropCacheException('Failed to clear cache: $e');
    }
  }

  /// Clears cache using batched deletion to avoid blocking
  Future<int> _clearBatched(Database db) async {
    const batchSize = 1000; // Delete in batches
    int totalDeleted = 0;

    // First, try a simple delete for small tables
    final countResult =
        await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    final totalCount = countResult.first['count'] as int;

    if (totalCount <= batchSize) {
      // Small table, delete all at once
      return await db.delete(_tableName);
    }

    // Large table, delete in batches
    for (int iteration = 0; iteration < 1000; iteration++) {
      // Limit iterations
      final deleted = await db.rawDelete('''
        DELETE FROM $_tableName 
        WHERE id IN (
          SELECT id FROM $_tableName 
          LIMIT ?
        )
      ''', [batchSize]);

      totalDeleted += deleted;

      // If no entries were deleted, we're done
      if (deleted == 0) break;

      // Add a small delay between batches to prevent blocking
      if (iteration % 10 == 9) {
        await Future.delayed(const Duration(milliseconds: 1));
      }
    }

    return totalDeleted;
  }

  /// Closes the database connection
  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Resets the singleton database instance (for testing only)
  @visibleForTesting
  static Future<void> resetForTesting() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  /// Performs database maintenance (cleanup expired entries and LRU eviction)
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
