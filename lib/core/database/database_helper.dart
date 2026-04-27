import 'dart:async';

import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

class DatabaseHelper {
  static final DatabaseHelper _instance = new DatabaseHelper.internal();
  factory DatabaseHelper() => _instance;

  static Database? _db;

  Future<Database?> get db async {
    _db = await initDb();
    return _db;
  }

  DatabaseHelper.internal();

  initDb() async {
    var databasesPath = await getDatabasesPath();
    String path = join(databasesPath, "wallpaper.db");

    var database = await openDatabase(path, version: 1, onCreate: _onCreate);

    return database;
  }

  void _onCreate(Database db, int version) async {
    // When creating the db, create the table
    await db.execute(
        "CREATE TABLE DailyImages (id INTEGER PRIMARY KEY, Source TEXT, Url TEXT, Description text, StartTime TEXT, EndTime TEXT, ImageIdent TEXT, TriggerUrl TEXT, Copyright TEXT)");

    // Create indexes for better performance on history queries
    await db.execute("CREATE INDEX idx_start_time ON DailyImages(StartTime)");
    await db.execute("CREATE INDEX idx_image_ident ON DailyImages(ImageIdent)");
    await db.execute(
        "CREATE INDEX idx_date_start_time ON DailyImages(date(StartTime))");

    print("Created tables and indexes");
  }

  Future<bool> insertImage(ImageItem image) async {
    var theDb = await db;
    if (theDb == null) return false;

    var id = await theDb.transaction((txn) async {
      var id = await txn.rawInsert(
          'INSERT INTO DailyImages(Url, Source, Description, StartTime, EndTime, ImageIdent, TriggerUrl, Copyright) VALUES(?,?,?,?,?,?,?,?)',
          [
            image.url,
            image.source,
            image.description,
            image.startTime.toString(),
            image.endTime.toString(),
            image.imageIdent,
            image.triggerUrl,
            image.copyright
          ]);
      return id;
    });
    return id > 0;
  }

  Future<ImageItem?> getCurrentImage(String imageIdent) async {
    var theDb = await db;
    if (theDb == null) {
      return null;
    }

    List<Map> list = await theDb.rawQuery(
        "SELECT * FROM DailyImages where datetime('now')>=startTime and datetime('now')<=endTime and ImageIdent='$imageIdent'");
    if (list.isEmpty) return null;

    var image = ImageItem.fromMap(list.first);
    return image;
  }

  /// Get historical images (for history screen)
  Future<List<ImageItem>> getHistoricalImages({int limit = 30}) async {
    var theDb = await db;
    if (theDb == null) return [];

    List<Map> list = await theDb.rawQuery(
        "SELECT * FROM DailyImages ORDER BY StartTime DESC LIMIT ?", [limit]);

    return list.map((map) => ImageItem.fromMap(map)).toList();
  }

  /// Clean up old images (keep only last 30 days)
  Future<void> cleanupOldImages({int daysToKeep = 30}) async {
    var theDb = await db;
    if (theDb == null) return;

    await theDb.rawDelete(
        "DELETE FROM DailyImages WHERE StartTime < datetime('now', '-$daysToKeep days')");
  }

  /// Get images for a specific date
  Future<List<ImageItem>> getImagesForDate(DateTime date) async {
    var theDb = await db;
    if (theDb == null) return [];

    var startOfDay = DateTimeHelper.startDayDate(date);
    var endOfDay = startOfDay.add(Duration(days: 1));

    List<Map> list = await theDb.rawQuery(
        "SELECT * FROM DailyImages WHERE StartTime >= ? AND StartTime < ? ORDER BY id",
        [startOfDay.toString(), endOfDay.toString()]);

    return list.map((map) => ImageItem.fromMap(map)).toList();
  }

  /// Delete image by identifier
  Future<void> deleteImageByIdent(String imageIdent) async {
    var theDb = await db;
    if (theDb == null) return;

    await theDb.rawDelete(
        "DELETE FROM DailyImages WHERE ImageIdent = ?", [imageIdent]);
  }

  /// Get all dates that have stored images
  Future<List<DateTime>> getAvailableDates() async {
    var theDb = await db;
    if (theDb == null) return [];

    List<Map> list = await theDb.rawQuery(
        "SELECT DISTINCT date(StartTime) as date FROM DailyImages ORDER BY date DESC");

    return list.map((map) => DateTime.parse(map['date'])).toList();
  }

  /// Get image count by date for optimization purposes
  Future<Map<DateTime, int>> getImageCountByDate() async {
    var theDb = await db;
    if (theDb == null) return {};

    List<Map> list = await theDb.rawQuery(
        "SELECT date(StartTime) as date, COUNT(*) as count FROM DailyImages GROUP BY date(StartTime) ORDER BY date DESC");

    Map<DateTime, int> result = {};
    for (var map in list) {
      DateTime date = DateTime.parse(map['date']);
      int count = map['count'];
      result[date] = count;
    }

    return result;
  }

  /// Get images for a specific date with pagination for lazy loading
  Future<List<ImageItem>> getImagesForDatePaginated(
    DateTime date, {
    int limit = 10,
    int offset = 0,
  }) async {
    var theDb = await db;
    if (theDb == null) return [];

    var startOfDay = DateTimeHelper.startDayDate(date);
    var endOfDay = startOfDay.add(Duration(days: 1));

    List<Map> list = await theDb.rawQuery(
        "SELECT * FROM DailyImages WHERE StartTime >= ? AND StartTime < ? ORDER BY id LIMIT ? OFFSET ?",
        [startOfDay.toString(), endOfDay.toString(), limit, offset]);

    return list.map((map) => ImageItem.fromMap(map)).toList();
  }

  /// Batch insert multiple images for better performance
  Future<bool> insertImagesBatch(List<ImageItem> images) async {
    var theDb = await db;
    if (theDb == null) return false;

    try {
      await theDb.transaction((txn) async {
        final batch = txn.batch();

        for (final image in images) {
          batch.rawInsert(
              'INSERT INTO DailyImages(Url, Source, Description, StartTime, EndTime, ImageIdent, TriggerUrl, Copyright) VALUES(?,?,?,?,?,?,?,?)',
              [
                image.url,
                image.source,
                image.description,
                image.startTime.toString(),
                image.endTime.toString(),
                image.imageIdent,
                image.triggerUrl,
                image.copyright
              ]);
        }

        await batch.commit(noResult: true);
      });
      return true;
    } catch (e) {
      print('Error in batch insert: $e');
      return false;
    }
  }

  /// Get available dates with count information for optimization
  Future<List<Map<String, dynamic>>> getAvailableDatesWithCount() async {
    var theDb = await db;
    if (theDb == null) return [];

    List<Map> list = await theDb.rawQuery(
        "SELECT date(StartTime) as date, COUNT(*) as count FROM DailyImages GROUP BY date(StartTime) ORDER BY date DESC");

    return list
        .map((map) => {
              'date': DateTime.parse(map['date']),
              'count': map['count'] as int,
            })
        .toList();
  }

  /// Check if images exist for a specific date (lightweight check)
  Future<bool> hasImagesForDate(DateTime date) async {
    var theDb = await db;
    if (theDb == null) return false;

    var startOfDay = DateTimeHelper.startDayDate(date);
    var endOfDay = startOfDay.add(Duration(days: 1));

    List<Map> list = await theDb.rawQuery(
        "SELECT 1 FROM DailyImages WHERE StartTime >= ? AND StartTime < ? LIMIT 1",
        [startOfDay.toString(), endOfDay.toString()]);

    return list.isNotEmpty;
  }

  /// Get database statistics for performance monitoring
  Future<Map<String, dynamic>> getDatabaseStats() async {
    var theDb = await db;
    if (theDb == null) return {};

    try {
      // Get total image count
      final totalCountResult =
          await theDb.rawQuery("SELECT COUNT(*) as count FROM DailyImages");
      final totalCount = totalCountResult.first['count'] as int;

      // Get date range
      final dateRangeResult = await theDb.rawQuery(
          "SELECT MIN(date(StartTime)) as min_date, MAX(date(StartTime)) as max_date FROM DailyImages");

      final minDate = dateRangeResult.first['min_date'];
      final maxDate = dateRangeResult.first['max_date'];

      // Get database size (approximate)
      final sizeResult = await theDb.rawQuery("PRAGMA page_count");
      final pageCount = sizeResult.first['page_count'] as int;
      final pageSizeResult = await theDb.rawQuery("PRAGMA page_size");
      final pageSize = pageSizeResult.first['page_size'] as int;
      final dbSizeBytes = pageCount * pageSize;

      return {
        'total_images': totalCount,
        'min_date': minDate,
        'max_date': maxDate,
        'database_size_bytes': dbSizeBytes,
        'database_size_mb': (dbSizeBytes / (1024 * 1024)).toStringAsFixed(2),
      };
    } catch (e) {
      print('Error getting database stats: $e');
      return {};
    }
  }
}
