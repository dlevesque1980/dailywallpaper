import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dailywallpaper/features/smart_crop/cache/crop_cache_dao.dart';
import 'package:dailywallpaper/features/smart_crop/cache/crop_cache_database.dart';
import 'package:dailywallpaper/features/smart_crop/cache/crop_cache_entry.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_coordinates.dart';

class MockCropCacheDatabase extends Mock implements CropCacheDatabase {}

class MockDatabase extends Mock implements Database {}

void main() {
  late MockCropCacheDatabase mockDbWrapper;
  late MockDatabase mockDb;
  late CropCacheDao dao;

  setUp(() {
    mockDbWrapper = MockCropCacheDatabase();
    mockDb = MockDatabase();
    when(() => mockDbWrapper.database).thenAnswer((_) async => mockDb);
    dao = CropCacheDao(mockDbWrapper);
  });

  group('CropCacheDao', () {
    final testEntry = CropCacheEntry(
      cacheKey: 'test_key',
      imageUrl: 'test_url',
      coordinates: const CropCoordinates(
        x: 0.1,
        y: 0.1,
        width: 0.8,
        height: 0.8,
        confidence: 0.9,
        strategy: 'test',
      ),
      createdAt: DateTime.now(),
      lastAccessedAt: DateTime.now(),
      accessCount: 1,
      targetWidth: 1080,
      targetHeight: 1920,
      settingsHash: 'test_hash',
    );

    test('insert adds entry to database', () async {
      when(() => mockDb.insert(
            any(),
            any(),
            conflictAlgorithm: any(named: 'conflictAlgorithm'),
          )).thenAnswer((_) async => 1);

      final result = await dao.insert(testEntry);

      expect(result, 1);
      verify(() => mockDb.insert(
            CropCacheDatabase.tableName,
            testEntry.toMap(),
            conflictAlgorithm: ConflictAlgorithm.replace,
          )).called(1);
    });

    test('delete removes entry by id', () async {
      when(() => mockDb.delete(
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 1);

      final result = await dao.delete(1);

      expect(result, 1);
      verify(() => mockDb.delete(
            CropCacheDatabase.tableName,
            where: 'id = ?',
            whereArgs: [1],
          )).called(1);
    });

    test('deleteExpired removes old entries', () async {
      when(() => mockDb.delete(
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 5);

      final result = await dao.deleteExpired(ttl: const Duration(days: 7));

      expect(result, 5);
      verify(() => mockDb.delete(
            CropCacheDatabase.tableName,
            where: 'created_at < ?',
            whereArgs: any(named: 'whereArgs'),
          )).called(1);
    });
  });
}
