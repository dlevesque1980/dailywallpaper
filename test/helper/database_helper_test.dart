import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

void main() {
  late DatabaseHelper databaseHelper;

  setUpAll(() {
    // Initialize FFI
    sqfliteFfiInit();
    // Change the default factory for unit testing calls for SQFlite
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    databaseHelper = DatabaseHelper();
    // Clean up any existing data
    var db = await databaseHelper.db;
    if (db != null) {
      await db.delete('DailyImages');
    }
  });

  group('DatabaseHelper History Functionality', () {
    test('getAvailableDates returns empty list when no images exist', () async {
      final dates = await databaseHelper.getAvailableDates();
      expect(dates, isEmpty);
    });

    test('getImageCountByDate returns empty map when no images exist',
        () async {
      final counts = await databaseHelper.getImageCountByDate();
      expect(counts, isEmpty);
    });

    test('getImagesForDate returns empty list when no images exist for date',
        () async {
      final date = DateTime(2024, 1, 15);
      final images = await databaseHelper.getImagesForDate(date);
      expect(images, isEmpty);
    });

    test('getAvailableDates returns correct dates after inserting images',
        () async {
      // Insert test images for different dates
      final date1 = DateTime(2024, 1, 15, 10, 0);
      final date2 = DateTime(2024, 1, 16, 10, 0);
      final date3 = DateTime(2024, 1, 15, 14, 0); // Same date as date1

      final image1 = ImageItem(
          'test_source',
          'https://example.com/image1.jpg',
          'Test image 1',
          date1,
          date1.add(Duration(hours: 1)),
          'test_id_1',
          'https://example.com/trigger1',
          'Test copyright 1');

      final image2 = ImageItem(
          'test_source',
          'https://example.com/image2.jpg',
          'Test image 2',
          date2,
          date2.add(Duration(hours: 1)),
          'test_id_2',
          'https://example.com/trigger2',
          'Test copyright 2');

      final image3 = ImageItem(
          'test_source',
          'https://example.com/image3.jpg',
          'Test image 3',
          date3,
          date3.add(Duration(hours: 1)),
          'test_id_3',
          'https://example.com/trigger3',
          'Test copyright 3');

      await databaseHelper.insertImage(image1);
      await databaseHelper.insertImage(image2);
      await databaseHelper.insertImage(image3);

      final availableDates = await databaseHelper.getAvailableDates();

      // Should return 2 unique dates, ordered by date DESC
      expect(availableDates.length, 2);
      expect(availableDates[0], DateTime(2024, 1, 16));
      expect(availableDates[1], DateTime(2024, 1, 15));
    });

    test('getImageCountByDate returns correct counts', () async {
      // Insert test images for different dates
      final date1 = DateTime(2024, 1, 15, 10, 0);
      final date2 = DateTime(2024, 1, 16, 10, 0);
      final date3 = DateTime(2024, 1, 15, 14, 0); // Same date as date1

      final image1 = ImageItem(
          'test_source',
          'https://example.com/image1.jpg',
          'Test image 1',
          date1,
          date1.add(Duration(hours: 1)),
          'test_id_1',
          'https://example.com/trigger1',
          'Test copyright 1');

      final image2 = ImageItem(
          'test_source',
          'https://example.com/image2.jpg',
          'Test image 2',
          date2,
          date2.add(Duration(hours: 1)),
          'test_id_2',
          'https://example.com/trigger2',
          'Test copyright 2');

      final image3 = ImageItem(
          'test_source',
          'https://example.com/image3.jpg',
          'Test image 3',
          date3,
          date3.add(Duration(hours: 1)),
          'test_id_3',
          'https://example.com/trigger3',
          'Test copyright 3');

      await databaseHelper.insertImage(image1);
      await databaseHelper.insertImage(image2);
      await databaseHelper.insertImage(image3);

      final imageCounts = await databaseHelper.getImageCountByDate();

      // Should return counts for 2 dates
      expect(imageCounts.length, 2);
      expect(imageCounts[DateTime(2024, 1, 15)], 2); // 2 images on Jan 15
      expect(imageCounts[DateTime(2024, 1, 16)], 1); // 1 image on Jan 16
    });

    test('getImagesForDate returns correct images for specific date', () async {
      // Insert test images for different dates
      final date1 = DateTime(2024, 1, 15, 10, 0);
      final date2 = DateTime(2024, 1, 16, 10, 0);
      final date3 = DateTime(2024, 1, 15, 14, 0); // Same date as date1

      final image1 = ImageItem(
          'test_source',
          'https://example.com/image1.jpg',
          'Test image 1',
          date1,
          date1.add(Duration(hours: 1)),
          'test_id_1',
          'https://example.com/trigger1',
          'Test copyright 1');

      final image2 = ImageItem(
          'test_source',
          'https://example.com/image2.jpg',
          'Test image 2',
          date2,
          date2.add(Duration(hours: 1)),
          'test_id_2',
          'https://example.com/trigger2',
          'Test copyright 2');

      final image3 = ImageItem(
          'test_source',
          'https://example.com/image3.jpg',
          'Test image 3',
          date3,
          date3.add(Duration(hours: 1)),
          'test_id_3',
          'https://example.com/trigger3',
          'Test copyright 3');

      await databaseHelper.insertImage(image1);
      await databaseHelper.insertImage(image2);
      await databaseHelper.insertImage(image3);

      // Test getting images for Jan 15
      final imagesJan15 =
          await databaseHelper.getImagesForDate(DateTime(2024, 1, 15));
      expect(imagesJan15.length, 2);
      expect(imagesJan15.any((img) => img.imageIdent == 'test_id_1'), true);
      expect(imagesJan15.any((img) => img.imageIdent == 'test_id_3'), true);

      // Test getting images for Jan 16
      final imagesJan16 =
          await databaseHelper.getImagesForDate(DateTime(2024, 1, 16));
      expect(imagesJan16.length, 1);
      expect(imagesJan16.first.imageIdent, 'test_id_2');

      // Test getting images for a date with no images
      final imagesJan17 =
          await databaseHelper.getImagesForDate(DateTime(2024, 1, 17));
      expect(imagesJan17, isEmpty);
    });

    test('methods handle edge cases correctly', () async {
      // Test with images spanning midnight
      final lateEvening = DateTime(2024, 1, 15, 23, 30);
      final earlyMorning = DateTime(2024, 1, 16, 0, 30);

      final image1 = ImageItem(
          'test_source',
          'https://example.com/image1.jpg',
          'Test image 1',
          lateEvening,
          lateEvening.add(Duration(hours: 1)),
          'test_id_1',
          'https://example.com/trigger1',
          'Test copyright 1');

      final image2 = ImageItem(
          'test_source',
          'https://example.com/image2.jpg',
          'Test image 2',
          earlyMorning,
          earlyMorning.add(Duration(hours: 1)),
          'test_id_2',
          'https://example.com/trigger2',
          'Test copyright 2');

      await databaseHelper.insertImage(image1);
      await databaseHelper.insertImage(image2);

      final availableDates = await databaseHelper.getAvailableDates();
      expect(availableDates.length, 2);

      final imageCounts = await databaseHelper.getImageCountByDate();
      expect(imageCounts[DateTime(2024, 1, 15)], 1);
      expect(imageCounts[DateTime(2024, 1, 16)], 1);

      final imagesJan15 =
          await databaseHelper.getImagesForDate(DateTime(2024, 1, 15));
      expect(imagesJan15.length, 1);
      expect(imagesJan15.first.imageIdent, 'test_id_1');

      final imagesJan16 =
          await databaseHelper.getImagesForDate(DateTime(2024, 1, 16));
      expect(imagesJan16.length, 1);
      expect(imagesJan16.first.imageIdent, 'test_id_2');
    });
  });
}
