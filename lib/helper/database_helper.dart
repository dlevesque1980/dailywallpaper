import 'dart:async';

import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/helper/datetime_helper.dart';
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
    print("Created tables");
  }

  Future<bool> insertImage(ImageItem image) async {
    var theDb = await db;
    if (theDb == null) return false;

    var id = await theDb.transaction((txn) async {
      var id = await txn.rawInsert(
          'INSERT INTO DailyImages(Url, Source, Description, StartTime, EndTime, ImageIdent, TriggerUrl, Copyright) VALUES(?,?,?,?,?,?,?,?)',
          [image.url, image.source, image.description, image.startTime.toString(), image.endTime.toString(), image.imageIdent, image.triggerUrl, image.copyright]);
      return id;
    });
    return id > 0;
  }

  Future<ImageItem?> getCurrentImage(String imageIdent) async {
    var theDb = await db;
    if (theDb == null){
      return null;
    }

    List<Map> list = await theDb.rawQuery("SELECT * FROM DailyImages where datetime('now')>=startTime and datetime('now')<=endTime and ImageIdent='$imageIdent'");
    if (list.isEmpty) return null;

    var image = ImageItem.fromMap(list.first);
    return image;
  }

  /// Get historical images (for history screen)
  Future<List<ImageItem>> getHistoricalImages({int limit = 30}) async {
    var theDb = await db;
    if (theDb == null) return [];

    List<Map> list = await theDb.rawQuery(
      "SELECT * FROM DailyImages ORDER BY StartTime DESC LIMIT ?", 
      [limit]
    );
    
    return list.map((map) => ImageItem.fromMap(map)).toList();
  }

  /// Clean up old images (keep only last 30 days)
  Future<void> cleanupOldImages({int daysToKeep = 30}) async {
    var theDb = await db;
    if (theDb == null) return;

    await theDb.rawDelete(
      "DELETE FROM DailyImages WHERE StartTime < datetime('now', '-$daysToKeep days')"
    );
  }

  /// Get images for a specific date
  Future<List<ImageItem>> getImagesForDate(DateTime date) async {
    var theDb = await db;
    if (theDb == null) return [];

    var startOfDay = DateTimeHelper.startDayDate(date);
    var endOfDay = startOfDay.add(Duration(days: 1));

    List<Map> list = await theDb.rawQuery(
      "SELECT * FROM DailyImages WHERE StartTime >= ? AND StartTime < ? ORDER BY id",
      [startOfDay.toString(), endOfDay.toString()]
    );
    
    return list.map((map) => ImageItem.fromMap(map)).toList();
  }

  /// Delete image by identifier
  Future<void> deleteImageByIdent(String imageIdent) async {
    var theDb = await db;
    if (theDb == null) return;

    await theDb.rawDelete(
      "DELETE FROM DailyImages WHERE ImageIdent = ?",
      [imageIdent]
    );
  }
}
