import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Database connection manager for crop cache
class CropCacheDatabase {
  static const String databaseName = 'crop_cache.db';
  static const int databaseVersion = 2;
  static const String tableName = 'crop_cache';

  static Database? _database;
  static final CropCacheDatabase _instance = CropCacheDatabase._internal();

  @visibleForTesting
  static String? testDatabasePath;

  factory CropCacheDatabase() => _instance;

  CropCacheDatabase._internal();

  Future<Database> get database async {
    _database ??= await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    final String path;
    if (testDatabasePath != null) {
      path = testDatabasePath!;
    } else {
      final documentsDirectory = await getDatabasesPath();
      path = join(documentsDirectory, databaseName);
    }

    return await openDatabase(
      path,
      version: databaseVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE $tableName (
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

    await db.execute('CREATE INDEX idx_cache_key ON $tableName (cache_key)');
    await db.execute('CREATE INDEX idx_image_url ON $tableName (image_url)');
    await db.execute('CREATE INDEX idx_created_at ON $tableName (created_at)');
    await db.execute('CREATE INDEX idx_last_accessed_at ON $tableName (last_accessed_at)');

    await _createMlSubjectCacheTable(db);
  }

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

    await db.execute('CREATE INDEX idx_ml_cache_image_url ON ml_subject_cache (image_url)');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await _createMlSubjectCacheTable(db);
    }
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }

  @visibleForTesting
  static Future<void> resetForTesting() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
