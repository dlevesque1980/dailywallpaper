import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';

import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter/services.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );

    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('DatabaseHelper Cleanup', () {
    test('cleanupOldFilesAndReferences nullifies paths but keeps CropResultJson', () async {
      final dbHelper = DatabaseHelper();
      final db = await dbHelper.db;
      
      // Clean up before test
      await db!.execute("DELETE FROM DailyImages");

      // Insert an image that is older than 2 days
      final oldDate = DateTime.now().subtract(const Duration(days: 3)).toIso8601String();
      await db.execute('''
        INSERT INTO DailyImages (ImageIdent, StartTime, EndTime, LocalSourcePath, LocalProcessedPath, CropResultJson)
        VALUES ('test_old_image', '$oldDate', '$oldDate', '/tmp/source.jpg', '/tmp/processed.png', '{"bestCrop":{"x":0,"y":0,"width":1,"height":1,"confidence":1,"strategy":"test"}}')
      ''');

      // Act
      await dbHelper.cleanupOldFilesAndReferences(daysToKeepFiles: 2);

      // Assert
      final result = await db.query('DailyImages', where: "ImageIdent = 'test_old_image'");
      expect(result.length, 1);
      
      final row = result.first;
      expect(row['LocalSourcePath'], isNull);
      expect(row['LocalProcessedPath'], isNull);
      expect(row['CropResultJson'], isNotNull);
      expect(row['CropResultJson'], contains('bestCrop'));
    });
  });
}
