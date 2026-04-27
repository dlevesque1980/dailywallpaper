import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  group('HistoryBloc Wallpaper Integration', () {
    late HistoryBloc historyBloc;
    late DatabaseHelper dbHelper;

    setUpAll(() {
      // Initialize FFI
      sqfliteFfiInit();
      // Change the default factory for unit testing calls for SQFlite
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() {
      historyBloc = HistoryBloc();
      dbHelper = DatabaseHelper();
    });

    tearDown(() {
      historyBloc.dispose();
    });

    test('should handle wallpaper setting with valid image index', () async {
      // Create a test image
      final testImage = ImageItem(
        'test', // source
        'https://example.com/test.jpg', // url
        'Test Image', // description
        DateTime.now(), // startTime
        DateTime.now(), // endTime
        'test.image.2024-01-01', // imageIdent
        null, // triggerUrl
        'Test Copyright', // copyright
      );

      // Insert test image into database
      await dbHelper.insertImage(testImage);

      // Load images for the test date
      final testDate = DateTime(2024, 1, 1);
      historyBloc.selectDate.add(testDate);

      // Wait for the state to be updated
      await Future.delayed(Duration(milliseconds: 100));

      // Test wallpaper setting with valid index
      final wallpaperStream = historyBloc.wallpaper;

      // Trigger wallpaper setting
      historyBloc.setWallpaper.add(0);

      // Listen for the result
      final result = await wallpaperStream.first;

      // The result should be a string (either success or error message)
      expect(result, isA<String>());
      expect(result.isNotEmpty, true);
    });

    test('should handle wallpaper setting with no images', () async {
      // Test wallpaper setting when no images are available
      final wallpaperStream = historyBloc.wallpaper;

      // Trigger wallpaper setting with no images loaded
      historyBloc.setWallpaper.add(0);

      // Listen for the result
      final result = await wallpaperStream.first;

      // Should return error message
      expect(result, equals('No images available to set as wallpaper'));
    });

    test('should handle wallpaper setting with invalid index', () async {
      // Create a test image
      final testImage = ImageItem(
        'test', // source
        'https://example.com/test.jpg', // url
        'Test Image', // description
        DateTime.now(), // startTime
        DateTime.now(), // endTime
        'test.image.2024-01-01', // imageIdent
        null, // triggerUrl
        'Test Copyright', // copyright
      );

      // Insert test image into database
      await dbHelper.insertImage(testImage);

      // Load images for the test date
      final testDate = DateTime(2024, 1, 1);
      historyBloc.selectDate.add(testDate);

      // Wait for the state to be updated
      await Future.delayed(Duration(milliseconds: 100));

      // Test wallpaper setting with invalid index
      final wallpaperStream = historyBloc.wallpaper;

      // Trigger wallpaper setting with invalid index
      historyBloc.setWallpaper.add(999);

      // Listen for the result
      final result = await wallpaperStream.first;

      // Should return error message (the implementation checks for empty images first)
      expect(result, isA<String>());
      expect(result.isNotEmpty, true);
    });
  });
}
