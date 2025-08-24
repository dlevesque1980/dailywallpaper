import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'crop_cache_entry.dart';

/// Database manager for crop cache entries
class CropCacheDatabase {
  static const String _databaseName = 'crop_cache.db';
  static const int _databaseVersion = 1;
  static const String _tableName = 'crop_cache';
  
  static Database? _database;
  static final CropCacheDatabase _instance = CropCacheDatabase._internal();
  
  factory CropCacheDatabase() => _instance;
  
  CropCacheDatabase._internal();

  /// Gets the database instance, creating it if necessary
  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  /// Initializes the database
  Future<Database> _initDatabase() async {
    final documentsDirectory = await getDatabasesPath();
    final path = join(documentsDirectory, _databaseName);
    
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
  }

  /// Handles database upgrades
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Handle future schema migrations here
    if (oldVersion < 2) {
      // Example: Add new columns or tables
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
      throw CropCacheException('Failed to delete cache entries by image URL: $e');
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
      // Get current count
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      final currentCount = countResult.first['count'] as int;
      
      if (currentCount <= maxEntries) return 0;
      
      // Calculate how many entries to remove
      final entriesToRemove = currentCount - maxEntries;
      
      // Get the oldest entries by last access time
      final oldestEntries = await db.query(
        _tableName,
        columns: ['id'],
        orderBy: 'last_accessed_at ASC',
        limit: entriesToRemove,
      );
      
      if (oldestEntries.isEmpty) return 0;
      
      // Delete the oldest entries
      final idsToDelete = oldestEntries.map((entry) => entry['id']).join(',');
      return await db.rawDelete('DELETE FROM $_tableName WHERE id IN ($idsToDelete)');
      
    } catch (e) {
      throw CropCacheException('Failed to perform LRU eviction: $e');
    }
  }

  /// Gets cache statistics
  Future<CropCacheStats> getStats() async {
    final db = await database;
    
    try {
      // Get total count
      final countResult = await db.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
      final totalEntries = countResult.first['count'] as int;
      
      // Get total size (approximate)
      final sizeResult = await db.rawQuery('SELECT page_count * page_size as size FROM pragma_page_count(), pragma_page_size()');
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
        oldestEntry = DateTime.fromMillisecondsSinceEpoch(oldestResult.first['created_at'] as int);
        
        final newestResult = await db.query(
          _tableName,
          columns: ['created_at'],
          orderBy: 'created_at DESC',
          limit: 1,
        );
        newestEntry = DateTime.fromMillisecondsSinceEpoch(newestResult.first['created_at'] as int);
      }
      
      // Get average access count
      final avgAccessResult = await db.rawQuery('SELECT AVG(access_count) as avg_access FROM $_tableName');
      final avgAccessCount = (avgAccessResult.first['avg_access'] as double?) ?? 0.0;
      
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
      return await db.delete(_tableName);
    } catch (e) {
      throw CropCacheException('Failed to clear cache: $e');
    }
  }

  /// Closes the database connection
  Future<void> close() async {
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