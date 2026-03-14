import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailywallpaper/helper/database_helper.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/bloc/history_bloc.dart';

void main() {
  group('History Performance Tests', () {
    late DatabaseHelper dbHelper;
    late HistoryBloc historyBloc;

    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    setUp(() async {
      dbHelper = DatabaseHelper();
      historyBloc = HistoryBloc();

      // Clear any existing data
      final db = await dbHelper.db;
      if (db != null) {
        await db.delete('DailyImages');
      }
    });

    tearDown(() async {
      historyBloc.dispose();
      final db = await dbHelper.db;
      if (db != null) {
        await db.close();
      }
    });

    group('Large Dataset Performance', () {
      test('should handle 30 days of historical data efficiently', () async {
        // Generate 30 days of test data (3 images per day)
        final testImages = <ImageItem>[];
        final now = DateTime.now();

        for (int day = 0; day < 30; day++) {
          final date = now.subtract(Duration(days: day));

          for (int imageIndex = 0; imageIndex < 3; imageIndex++) {
            testImages.add(_createTestImage(
              date: date,
              index: imageIndex,
              source: ['bing', 'nasa', 'pexels'][imageIndex],
            ));
          }
        }

        // Batch insert all images
        final stopwatch = Stopwatch()..start();
        final insertResult = await dbHelper.insertImagesBatch(testImages);
        stopwatch.stop();

        expect(insertResult, isTrue);
        expect(stopwatch.elapsedMilliseconds,
            lessThan(5000)); // Should complete in under 5 seconds
        print(
            'Batch insert of ${testImages.length} images took ${stopwatch.elapsedMilliseconds}ms');

        // Test loading available dates
        final datesStopwatch = Stopwatch()..start();
        final availableDates = await dbHelper.getAvailableDates();
        datesStopwatch.stop();

        expect(availableDates.length, equals(30));
        expect(datesStopwatch.elapsedMilliseconds,
            lessThan(1000)); // Should be fast
        print(
            'Loading available dates took ${datesStopwatch.elapsedMilliseconds}ms');

        // Test loading images for a specific date
        final imagesStopwatch = Stopwatch()..start();
        final todayImages = await dbHelper.getImagesForDate(now);
        imagesStopwatch.stop();

        expect(todayImages.length, equals(3));
        expect(imagesStopwatch.elapsedMilliseconds,
            lessThan(500)); // Should be very fast
        print(
            'Loading images for specific date took ${imagesStopwatch.elapsedMilliseconds}ms');
      });

      test('should handle 100 days of historical data with pagination',
          () async {
        // Generate 100 days of test data (5 images per day)
        final testImages = <ImageItem>[];
        final now = DateTime.now();

        for (int day = 0; day < 100; day++) {
          final date = now.subtract(Duration(days: day));

          for (int imageIndex = 0; imageIndex < 5; imageIndex++) {
            testImages.add(_createTestImage(
              date: date,
              index: imageIndex,
              source: 'test_source_$imageIndex',
            ));
          }
        }

        // Batch insert all images
        final insertResult = await dbHelper.insertImagesBatch(testImages);
        expect(insertResult, isTrue);

        // Test paginated loading
        final paginationStopwatch = Stopwatch()..start();
        final firstPage =
            await dbHelper.getImagesForDatePaginated(now, limit: 3, offset: 0);
        final secondPage =
            await dbHelper.getImagesForDatePaginated(now, limit: 3, offset: 3);
        paginationStopwatch.stop();

        expect(firstPage.length, equals(3));
        expect(secondPage.length, equals(2)); // Only 5 images total for today
        expect(paginationStopwatch.elapsedMilliseconds, lessThan(1000));
        print(
            'Paginated loading took ${paginationStopwatch.elapsedMilliseconds}ms');

        // Test database statistics
        final statsStopwatch = Stopwatch()..start();
        final stats = await dbHelper.getDatabaseStats();
        statsStopwatch.stop();

        expect(stats['total_images'], equals(500)); // 100 days * 5 images
        expect(stats['database_size_mb'], isNotNull);
        expect(statsStopwatch.elapsedMilliseconds, lessThan(1000));
        print('Database stats: ${stats}');
        print(
            'Getting database stats took ${statsStopwatch.elapsedMilliseconds}ms');
      });

      test('should efficiently check for image existence', () async {
        // Insert images for specific dates
        final testDates = [
          DateTime.now(),
          DateTime.now().subtract(Duration(days: 1)),
          DateTime.now().subtract(Duration(days: 5)),
        ];

        for (final date in testDates) {
          await dbHelper.insertImage(_createTestImage(date: date, index: 0));
        }

        // Test existence checks
        final existenceStopwatch = Stopwatch()..start();

        final hasToday = await dbHelper.hasImagesForDate(DateTime.now());
        final hasYesterday = await dbHelper
            .hasImagesForDate(DateTime.now().subtract(Duration(days: 1)));
        final hasTwoDaysAgo = await dbHelper
            .hasImagesForDate(DateTime.now().subtract(Duration(days: 2)));

        existenceStopwatch.stop();

        expect(hasToday, isTrue);
        expect(hasYesterday, isTrue);
        expect(hasTwoDaysAgo, isFalse);
        expect(existenceStopwatch.elapsedMilliseconds, lessThan(500));
        print(
            'Existence checks took ${existenceStopwatch.elapsedMilliseconds}ms');
      });
    });

    group('HistoryBloc Performance', () {
      test('should cache and reuse loaded images efficiently', () async {
        // Insert test data
        final testImages = <ImageItem>[];
        final testDate = DateTime.now();

        for (int i = 0; i < 5; i++) {
          testImages.add(_createTestImage(date: testDate, index: i));
        }

        await dbHelper.insertImagesBatch(testImages);

        // Initialize bloc
        await historyBloc.initialize();

        // First load (should hit database)
        final firstLoadStopwatch = Stopwatch()..start();
        historyBloc.selectDate.add(testDate);

        // Wait for the stream to emit
        final firstState = await historyBloc.results.first;
        firstLoadStopwatch.stop();

        expect(firstState.images.length, equals(5));
        expect(firstState.isLoading, isFalse);
        print('First load took ${firstLoadStopwatch.elapsedMilliseconds}ms');

        // Second load (should use cache)
        final secondLoadStopwatch = Stopwatch()..start();
        historyBloc.selectDate.add(testDate);

        final secondState =
            await historyBloc.results.timeout(Duration(seconds: 5)).first;
        secondLoadStopwatch.stop();

        expect(secondState.images.length, equals(5));
        expect(secondState.isLoading, isFalse);
        print(
            'Second load (cached) took ${secondLoadStopwatch.elapsedMilliseconds}ms');

        // Cache should make second load faster or at least not significantly slower
        expect(secondLoadStopwatch.elapsedMilliseconds,
            lessThanOrEqualTo(firstLoadStopwatch.elapsedMilliseconds * 2));

        // Check performance stats
        final stats = historyBloc.getPerformanceStats();
        expect(stats['cache_entries'], greaterThan(0));
        expect(stats['average_load_time'], greaterThan(0));
        print('Performance stats: $stats');
      });

      test('should handle rapid date switching without memory leaks', () async {
        // Insert test data for multiple dates
        final testDates = <DateTime>[];
        for (int day = 0; day < 10; day++) {
          final date = DateTime.now().subtract(Duration(days: day));
          testDates.add(date);

          for (int i = 0; i < 3; i++) {
            await dbHelper.insertImage(_createTestImage(date: date, index: i));
          }
        }

        await historyBloc.initialize();

        // Rapidly switch between dates
        final rapidSwitchStopwatch = Stopwatch()..start();

        for (int i = 0; i < 20; i++) {
          final randomDate = testDates[Random().nextInt(testDates.length)];
          historyBloc.selectDate.add(randomDate);

          // Wait a bit to simulate user interaction
          await Future.delayed(Duration(milliseconds: 50));
        }

        rapidSwitchStopwatch.stop();

        // Wait for final state
        final finalState = await historyBloc.results.first;
        expect(finalState.images.length, equals(3));

        print(
            'Rapid date switching (20 switches) took ${rapidSwitchStopwatch.elapsedMilliseconds}ms');

        // Check that cache doesn't grow unbounded
        final stats = historyBloc.getPerformanceStats();
        expect(stats['cache_entries'],
            lessThanOrEqualTo(10)); // Should not exceed number of test dates
        print('Final cache entries: ${stats['cache_entries']}');
      });

      test('should clear expired cache entries', () async {
        // Insert test data
        final testDate = DateTime.now();
        await dbHelper.insertImage(_createTestImage(date: testDate, index: 0));

        await historyBloc.initialize();

        // Load data to populate cache
        historyBloc.selectDate.add(testDate);
        await historyBloc.results.first;

        // Verify cache is populated
        var stats = historyBloc.getPerformanceStats();
        expect(stats['cache_entries'], greaterThan(0));

        // Clear cache manually (simulating expiry)
        historyBloc.clearCache();

        // Verify cache is cleared
        stats = historyBloc.getPerformanceStats();
        expect(stats['cache_entries'], equals(0));
        print('Cache cleared successfully');
      });
    });

    group('Memory Usage Tests', () {
      test('should not accumulate excessive memory with large datasets',
          () async {
        // This test verifies that memory usage doesn't grow unbounded
        // In a real app, you'd use more sophisticated memory monitoring

        // Insert a large dataset
        final testImages = <ImageItem>[];
        for (int day = 0; day < 50; day++) {
          final date = DateTime.now().subtract(Duration(days: day));
          for (int i = 0; i < 10; i++) {
            testImages.add(_createTestImage(date: date, index: i));
          }
        }

        await dbHelper.insertImagesBatch(testImages);
        await historyBloc.initialize();

        // Load data for multiple dates
        final dates = <DateTime>[];
        for (int day = 0; day < 10; day++) {
          dates.add(DateTime.now().subtract(Duration(days: day)));
        }

        for (final date in dates) {
          historyBloc.selectDate.add(date);
          await historyBloc.results.first;
        }

        // Check that cache size is reasonable
        final stats = historyBloc.getPerformanceStats();
        expect(stats['cache_entries'],
            lessThanOrEqualTo(15)); // Should not cache everything

        // Verify database stats
        final dbStats = await dbHelper.getDatabaseStats();
        expect(dbStats['total_images'], equals(500));
        print('Database size: ${dbStats['database_size_mb']} MB');
        print('Cache entries: ${stats['cache_entries']}');
      });
    });
  });
}

/// Helper function to create test images
ImageItem _createTestImage({
  required DateTime date,
  required int index,
  String source = 'test',
}) {
  final startTime = DateTime(date.year, date.month, date.day, 8, 0, 0);
  final endTime = startTime.add(Duration(hours: 16));

  return ImageItem(
    source,
    'https://example.com/test_image_${date.millisecondsSinceEpoch}_$index.jpg',
    'Test image $index for ${date.toIso8601String().split('T')[0]}',
    startTime,
    endTime,
    '${source}_${date.millisecondsSinceEpoch}_$index',
    'https://example.com/trigger_$index',
    'Test copyright $index',
  );
}
