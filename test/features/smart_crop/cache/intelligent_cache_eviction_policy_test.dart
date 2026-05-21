import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dailywallpaper/features/smart_crop/cache/intelligent_cache_eviction_policy.dart';
import 'package:dailywallpaper/features/smart_crop/cache/crop_cache_database.dart';

class MockCropCacheDatabase extends Mock implements CropCacheDatabase {}

class MockDatabase extends Mock implements Database {}

void main() {
  late MockCropCacheDatabase mockDbWrapper;
  late MockDatabase mockDb;
  late IntelligentCacheEvictionPolicy policy;

  setUp(() {
    mockDbWrapper = MockCropCacheDatabase();
    mockDb = MockDatabase();
    when(() => mockDbWrapper.database).thenAnswer((_) async => mockDb);
    policy = IntelligentCacheEvictionPolicy(mockDbWrapper);
  });

  group('IntelligentCacheEvictionPolicy', () {
    test('optimizeCache removes low value entries', () async {
      when(() => mockDb.delete(
            any(),
            where: any(named: 'where'),
            whereArgs: any(named: 'whereArgs'),
          )).thenAnswer((_) async => 3);

      when(() => mockDb.rawQuery(any())).thenAnswer((_) async => []);

      final result = await policy.optimizeCache();

      expect(result.success, isTrue);
      expect(result.removedEntries, 3);
      verify(() => mockDb.delete(
            CropCacheDatabase.tableName,
            where: 'access_count = 1 AND created_at < ?',
            whereArgs: any(named: 'whereArgs'),
          )).called(1);
    });

    test('getEffectivenessMetrics calculates correctly', () async {
      when(() => mockDb.rawQuery(any(), any())).thenAnswer((invocation) async {
        final query = invocation.positionalArguments[0] as String;
        if (query.contains('hit_entries')) {
          return [
            {
              'total_entries': 100,
              'hit_entries': 25,
              'avg_access': 1.5,
              'total_accesses': 150,
            }
          ];
        } else if (query.contains('recent_entries')) {
          return [
            {
              'recent_entries': 50,
              'medium_entries': 30,
              'old_entries': 20,
            }
          ];
        }
        return [];
      });

      when(() => mockDb.rawQuery(any())).thenAnswer((invocation) async {
        final query = invocation.positionalArguments[0] as String;
        if (query.contains('hit_entries')) {
          return [
            {
              'total_entries': 100,
              'hit_entries': 25,
              'avg_access': 1.5,
              'total_accesses': 150,
            }
          ];
        } else if (query.contains('recent_entries')) {
          return [
            {
              'recent_entries': 50,
              'medium_entries': 30,
              'old_entries': 20,
            }
          ];
        }
        return [];
      });

      final metrics = await policy.getEffectivenessMetrics();

      expect(metrics.hitRate, 0.25);
      expect(metrics.averageAccessCount, 1.5);
      expect(metrics.accessEfficiency, 1.5);
      expect(metrics.totalEntries, 100);
      expect(metrics.recentEntries, 50);
      expect(metrics.mediumAgeEntries, 30);
      expect(metrics.oldEntries, 20);
    });
  });
}
