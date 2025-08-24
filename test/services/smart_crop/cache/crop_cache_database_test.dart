import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailywallpaper/services/smart_crop/cache/crop_cache_database.dart';
import 'package:dailywallpaper/services/smart_crop/cache/crop_cache_entry.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

void main() {
  group('CropCacheDatabase', () {
    late CropCacheDatabase database;
    
    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    
    setUp(() async {
      database = CropCacheDatabase();
      // Clear any existing data
      await database.clear();
    });
    
    tearDown(() async {
      await database.close();
    });

    group('CRUD operations', () {
      test('should insert and retrieve cache entry', () async {
        final coordinates = const CropCoordinates(
          x: 0.1,
          y: 0.2,
          width: 0.8,
          height: 0.6,
          confidence: 0.9,
          strategy: 'test_strategy',
        );
        
        final entry = CropCacheEntry.create(
          cacheKey: 'test_key_1',
          imageUrl: 'https://example.com/image1.jpg',
          targetWidth: 1080,
          targetHeight: 1920,
          settingsHash: 'settings_hash_1',
          coordinates: coordinates,
        );
        
        // Insert entry
        final id = await database.insert(entry);
        expect(id, greaterThan(0));
        
        // Retrieve entry
        final retrieved = await database.getByCacheKey('test_key_1');
        expect(retrieved, isNotNull);
        expect(retrieved!.cacheKey, equals('test_key_1'));
        expect(retrieved.coordinates, equals(coordinates));
        expect(retrieved.accessCount, equals(2)); // Should be incremented on access
      });
      
      test('should handle duplicate cache keys with replace', () async {
        final coordinates1 = const CropCoordinates(
          x: 0.1, y: 0.1, width: 0.8, height: 0.8,
          confidence: 0.8, strategy: 'strategy1',
        );
        
        final coordinates2 = const CropCoordinates(
          x: 0.2, y: 0.2, width: 0.6, height: 0.6,
          confidence: 0.9, strategy: 'strategy2',
        );
        
        final entry1 = CropCacheEntry.create(
          cacheKey: 'duplicate_key',
          imageUrl: 'https://example.com/image.jpg',
          targetWidth: 1080,
          targetHeight: 1920,
          settingsHash: 'hash1',
          coordinates: coordinates1,
        );
        
        final entry2 = CropCacheEntry.create(
          cacheKey: 'duplicate_key',
          imageUrl: 'https://example.com/image.jpg',
          targetWidth: 1080,
          targetHeight: 1920,
          settingsHash: 'hash2',
          coordinates: coordinates2,
        );
        
        // Insert first entry
        await database.insert(entry1);
        
        // Insert second entry with same key (should replace)
        await database.insert(entry2);
        
        // Retrieve should get the second entry
        final retrieved = await database.getByCacheKey('duplicate_key');
        expect(retrieved, isNotNull);
        expect(retrieved!.coordinates, equals(coordinates2));
        expect(retrieved.settingsHash, equals('hash2'));
      });
      
      test('should return null for non-existent cache key', () async {
        final retrieved = await database.getByCacheKey('non_existent_key');
        expect(retrieved, isNull);
      });
      
      test('should get entries by image URL', () async {
        const imageUrl = 'https://example.com/test_image.jpg';
        
        // Insert multiple entries for the same image
        for (int i = 0; i < 3; i++) {
          final entry = CropCacheEntry.create(
            cacheKey: 'key_$i',
            imageUrl: imageUrl,
            targetWidth: 1080 + i * 100,
            targetHeight: 1920 + i * 100,
            settingsHash: 'hash_$i',
            coordinates: CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'strategy_$i',
            ),
          );
          
          await database.insert(entry);
        }
        
        // Retrieve entries by image URL
        final entries = await database.getByImageUrl(imageUrl);
        expect(entries.length, equals(3));
        
        // Should be ordered by last_accessed_at DESC
        for (int i = 0; i < entries.length - 1; i++) {
          expect(
            entries[i].lastAccessedAt.isAfter(entries[i + 1].lastAccessedAt) ||
            entries[i].lastAccessedAt.isAtSameMomentAs(entries[i + 1].lastAccessedAt),
            isTrue,
          );
        }
      });
      
      test('should update cache entry', () async {
        final entry = CropCacheEntry.create(
          cacheKey: 'update_test',
          imageUrl: 'https://example.com/image.jpg',
          targetWidth: 1080,
          targetHeight: 1920,
          settingsHash: 'original_hash',
          coordinates: const CropCoordinates(
            x: 0.1, y: 0.1, width: 0.8, height: 0.8,
            confidence: 0.8, strategy: 'original',
          ),
        );
        
        // Insert entry
        final id = await database.insert(entry);
        
        // Update entry
        final updatedEntry = entry.copyWith(
          id: id,
          settingsHash: 'updated_hash',
          accessCount: 5,
        );
        
        final updateCount = await database.update(updatedEntry);
        expect(updateCount, equals(1));
        
        // Retrieve and verify update
        final retrieved = await database.getByCacheKey('update_test');
        expect(retrieved, isNotNull);
        expect(retrieved!.settingsHash, equals('updated_hash'));
      });
      
      test('should delete cache entry', () async {
        final entry = CropCacheEntry.create(
          cacheKey: 'delete_test',
          imageUrl: 'https://example.com/image.jpg',
          targetWidth: 1080,
          targetHeight: 1920,
          settingsHash: 'hash',
          coordinates: const CropCoordinates(
            x: 0.1, y: 0.1, width: 0.8, height: 0.8,
            confidence: 0.8, strategy: 'test',
          ),
        );
        
        // Insert entry
        final id = await database.insert(entry);
        
        // Verify it exists
        final beforeDelete = await database.getByCacheKey('delete_test');
        expect(beforeDelete, isNotNull);
        
        // Delete entry
        final deleteCount = await database.delete(id);
        expect(deleteCount, equals(1));
        
        // Verify it's gone
        final afterDelete = await database.getByCacheKey('delete_test');
        expect(afterDelete, isNull);
      });
    });
    
    group('cleanup operations', () {
      test('should delete expired entries', () async {
        final now = DateTime.now();
        
        // Create entries with different ages
        final recentEntry = CropCacheEntry(
          cacheKey: 'recent',
          imageUrl: 'https://example.com/recent.jpg',
          targetWidth: 1080,
          targetHeight: 1920,
          settingsHash: 'hash',
          coordinates: const CropCoordinates(
            x: 0.1, y: 0.1, width: 0.8, height: 0.8,
            confidence: 0.8, strategy: 'test',
          ),
          createdAt: now.subtract(const Duration(days: 1)),
          lastAccessedAt: now,
          accessCount: 1,
        );
        
        final oldEntry = CropCacheEntry(
          cacheKey: 'old',
          imageUrl: 'https://example.com/old.jpg',
          targetWidth: 1080,
          targetHeight: 1920,
          settingsHash: 'hash',
          coordinates: const CropCoordinates(
            x: 0.2, y: 0.2, width: 0.6, height: 0.6,
            confidence: 0.7, strategy: 'test',
          ),
          createdAt: now.subtract(const Duration(days: 10)),
          lastAccessedAt: now.subtract(const Duration(days: 5)),
          accessCount: 1,
        );
        
        // Insert entries
        await database.insert(recentEntry);
        await database.insert(oldEntry);
        
        // Delete expired entries (TTL = 7 days)
        final deletedCount = await database.deleteExpired(
          ttl: const Duration(days: 7),
        );
        
        expect(deletedCount, equals(1)); // Only old entry should be deleted
        
        // Verify recent entry still exists
        final remaining = await database.getByCacheKey('recent');
        expect(remaining, isNotNull);
        
        // Verify old entry is gone
        final deleted = await database.getByCacheKey('old');
        expect(deleted, isNull);
      });
      
      test('should perform LRU eviction', () async {
        final now = DateTime.now();
        
        // Insert entries with different access times
        for (int i = 0; i < 5; i++) {
          final entry = CropCacheEntry(
            cacheKey: 'entry_$i',
            imageUrl: 'https://example.com/image_$i.jpg',
            targetWidth: 1080,
            targetHeight: 1920,
            settingsHash: 'hash',
            coordinates: CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test',
            ),
            createdAt: now.subtract(Duration(hours: i)),
            lastAccessedAt: now.subtract(Duration(minutes: i * 10)),
            accessCount: 1,
          );
          
          await database.insert(entry);
        }
        
        // Perform LRU eviction (keep only 3 entries)
        final evictedCount = await database.evictLRU(maxEntries: 3);
        expect(evictedCount, equals(2)); // Should remove 2 oldest entries
        
        // Verify only 3 entries remain
        final stats = await database.getStats();
        expect(stats.totalEntries, equals(3));
      });
      
      test('should clear all entries', () async {
        // Insert some entries
        for (int i = 0; i < 3; i++) {
          final entry = CropCacheEntry.create(
            cacheKey: 'clear_test_$i',
            imageUrl: 'https://example.com/image_$i.jpg',
            targetWidth: 1080,
            targetHeight: 1920,
            settingsHash: 'hash',
            coordinates: CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test',
            ),
          );
          
          await database.insert(entry);
        }
        
        // Verify entries exist
        final beforeClear = await database.getStats();
        expect(beforeClear.totalEntries, equals(3));
        
        // Clear all entries
        final clearedCount = await database.clear();
        expect(clearedCount, equals(3));
        
        // Verify all entries are gone
        final afterClear = await database.getStats();
        expect(afterClear.totalEntries, equals(0));
      });
    });
    
    group('statistics and maintenance', () {
      test('should provide accurate statistics', () async {
        // Insert test entries
        final now = DateTime.now();
        
        for (int i = 0; i < 3; i++) {
          final entry = CropCacheEntry(
            cacheKey: 'stats_test_$i',
            imageUrl: 'https://example.com/image_$i.jpg',
            targetWidth: 1080,
            targetHeight: 1920,
            settingsHash: 'hash',
            coordinates: CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test',
            ),
            createdAt: now.subtract(Duration(hours: i)),
            lastAccessedAt: now,
            accessCount: i + 1,
          );
          
          await database.insert(entry);
        }
        
        // Get statistics
        final stats = await database.getStats();
        
        expect(stats.totalEntries, equals(3));
        expect(stats.totalSizeBytes, greaterThan(0));
        expect(stats.averageAccessCount, equals(2.0)); // (1+2+3)/3 = 2
        expect(stats.oldestEntry, isNotNull);
        expect(stats.newestEntry, isNotNull);
        expect(stats.cacheAge, isNotNull);
      });
      
      test('should perform maintenance successfully', () async {
        final now = DateTime.now();
        
        // Insert mix of recent and old entries
        for (int i = 0; i < 5; i++) {
          final entry = CropCacheEntry(
            cacheKey: 'maintenance_test_$i',
            imageUrl: 'https://example.com/image_$i.jpg',
            targetWidth: 1080,
            targetHeight: 1920,
            settingsHash: 'hash',
            coordinates: CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test',
            ),
            createdAt: i < 2 
              ? now.subtract(const Duration(days: 10)) // Old entries
              : now.subtract(const Duration(hours: 1)), // Recent entries
            lastAccessedAt: now.subtract(Duration(minutes: i)),
            accessCount: 1,
          );
          
          await database.insert(entry);
        }
        
        // Perform maintenance
        final result = await database.performMaintenance(
          ttl: const Duration(days: 7),
          maxEntries: 2,
        );
        
        expect(result.success, isTrue);
        expect(result.expiredEntriesDeleted, equals(2)); // 2 old entries
        expect(result.lruEntriesEvicted, equals(1)); // 1 LRU evicted to reach max 2
        expect(result.totalEntriesDeleted, equals(3));
        
        // Verify final count
        final finalStats = await database.getStats();
        expect(finalStats.totalEntries, equals(2));
      });
    });
    
    group('error handling', () {
      test('should handle database operations gracefully', () async {
        // Test with valid operations - the database handles errors internally
        final result = await database.getByCacheKey('non_existent_key');
        expect(result, isNull);
        
        // Test that database can be closed without errors
        await database.close();
        
        // After closing, operations should still work (new connection created)
        final newDatabase = CropCacheDatabase();
        final newResult = await newDatabase.getByCacheKey('test');
        expect(newResult, isNull);
        await newDatabase.close();
      });
    });
  });
}