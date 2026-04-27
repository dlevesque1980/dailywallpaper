import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

void main() {
  group('History Page Final Integration Tests', () {
    late DatabaseHelper databaseHelper;

    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      databaseHelper = DatabaseHelper();
    });

    setUp(() async {
      // Initialize database for each test and clear previous test data
      final db = await databaseHelper.db;
      await db!.delete('DailyImages');
    });

    test('Database integration validation', () async {
      // Test that all required database methods work correctly
      final testImage = ImageItem(
        'test',
        'https://example.com/db_test.jpg',
        'Testing database integration',
        DateTime.now(),
        DateTime.now().add(const Duration(hours: 23, minutes: 59)),
        'db_test_image',
        'https://example.com/trigger.jpg',
        'Database Test Copyright',
      );

      await databaseHelper.insertImage(testImage);

      // Test getAvailableDates method
      final availableDates = await databaseHelper.getAvailableDates();
      expect(availableDates, isNotEmpty);
      expect(availableDates.first.day, equals(DateTime.now().day));

      // Test getImagesForDate method
      final imagesForToday =
          await databaseHelper.getImagesForDate(DateTime.now());
      expect(imagesForToday, isNotEmpty);
      expect(imagesForToday.first.description,
          equals('Testing database integration'));

      // Test getImageCountByDate method
      final imageCounts = await databaseHelper.getImageCountByDate();
      expect(imageCounts, isNotEmpty);
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      expect(imageCounts[todayMidnight], equals(1));
    });

    test('Performance validation with large dataset', () async {
      // Create a large dataset to test performance
      final largeDataset = List.generate(
          100,
          (index) => ImageItem(
                'test',
                'https://example.com/perf_image_$index.jpg',
                'Performance testing image $index',
                DateTime.now().subtract(Duration(days: index % 30)),
                DateTime.now()
                    .subtract(Duration(days: index % 30))
                    .add(const Duration(hours: 23, minutes: 59)),
                'perf_test_image_$index',
                'https://example.com/trigger$index.jpg',
                'Performance Test Copyright $index',
              ));

      final stopwatch = Stopwatch()..start();

      // Insert all images
      for (final image in largeDataset) {
        await databaseHelper.insertImage(image);
      }

      stopwatch.stop();

      // Verify insertion performance is reasonable (less than 5 seconds for 100 images)
      expect(stopwatch.elapsedMilliseconds, lessThan(5000));

      // Test query performance
      stopwatch.reset();
      stopwatch.start();

      final availableDates = await databaseHelper.getAvailableDates();
      final imageCounts = await databaseHelper.getImageCountByDate();

      stopwatch.stop();

      // Verify query performance is reasonable (less than 1 second)
      expect(stopwatch.elapsedMilliseconds, lessThan(1000));
      expect(availableDates, isNotEmpty);
      expect(imageCounts, isNotEmpty);
    });
  });
}
