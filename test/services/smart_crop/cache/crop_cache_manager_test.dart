import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailywallpaper/services/smart_crop/cache/crop_cache_manager.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

void main() {
  group('CropCacheManager', () {
    late CropCacheManager cacheManager;
    
    setUpAll(() {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    
    setUp(() async {
      cacheManager = CropCacheManager();
      // Clear any existing cache
      await cacheManager.clearCache();
    });
    
    tearDown(() async {
      await cacheManager.close();
    });

    group('cache key generation', () {
      test('should generate consistent cache keys', () {
        const imageUrl = 'https://example.com/image.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        
        final key1 = cacheManager.generateCacheKey(imageUrl, targetSize, settings);
        final key2 = cacheManager.generateCacheKey(imageUrl, targetSize, settings);
        
        expect(key1, equals(key2));
        expect(key1.length, equals(64)); // SHA-256 hash length
      });
      
      test('should generate different keys for different inputs', () {
        const imageUrl1 = 'https://example.com/image1.jpg';
        const imageUrl2 = 'https://example.com/image2.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        
        final key1 = cacheManager.generateCacheKey(imageUrl1, targetSize, settings);
        final key2 = cacheManager.generateCacheKey(imageUrl2, targetSize, settings);
        
        expect(key1, isNot(equals(key2)));
      });
      
      test('should generate different keys for different target sizes', () {
        const imageUrl = 'https://example.com/image.jpg';
        const targetSize1 = ui.Size(1080, 1920);
        const targetSize2 = ui.Size(1440, 2560);
        const settings = CropSettings.defaultSettings;
        
        final key1 = cacheManager.generateCacheKey(imageUrl, targetSize1, settings);
        final key2 = cacheManager.generateCacheKey(imageUrl, targetSize2, settings);
        
        expect(key1, isNot(equals(key2)));
      });
      
      test('should generate different keys for different settings', () {
        const imageUrl = 'https://example.com/image.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings1 = CropSettings.defaultSettings;
        const settings2 = CropSettings(
          aggressiveness: CropAggressiveness.aggressive,
          enableRuleOfThirds: false,
        );
        
        final key1 = cacheManager.generateCacheKey(imageUrl, targetSize, settings1);
        final key2 = cacheManager.generateCacheKey(imageUrl, targetSize, settings2);
        
        expect(key1, isNot(equals(key2)));
      });
    });
    
    group('cache operations', () {
      test('should cache and retrieve crop coordinates', () async {
        const imageUrl = 'https://example.com/test_image.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        const coordinates = CropCoordinates(
          x: 0.1,
          y: 0.2,
          width: 0.8,
          height: 0.6,
          confidence: 0.9,
          strategy: 'test_strategy',
        );
        
        // Cache coordinates
        final cached = await cacheManager.cacheCrop(
          imageUrl,
          targetSize,
          settings,
          coordinates,
        );
        expect(cached, isTrue);
        
        // Retrieve coordinates
        final retrieved = await cacheManager.getCachedCrop(
          imageUrl,
          targetSize,
          settings,
        );
        
        expect(retrieved, isNotNull);
        expect(retrieved, equals(coordinates));
      });
      
      test('should return null for cache miss', () async {
        const imageUrl = 'https://example.com/nonexistent.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        
        final retrieved = await cacheManager.getCachedCrop(
          imageUrl,
          targetSize,
          settings,
        );
        
        expect(retrieved, isNull);
      });
      
      test('should invalidate cache when settings change', () async {
        const imageUrl = 'https://example.com/test_image.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings1 = CropSettings.defaultSettings;
        const settings2 = CropSettings(
          aggressiveness: CropAggressiveness.aggressive,
        );
        const coordinates = CropCoordinates(
          x: 0.1, y: 0.2, width: 0.8, height: 0.6,
          confidence: 0.9, strategy: 'test',
        );
        
        // Cache with first settings
        await cacheManager.cacheCrop(imageUrl, targetSize, settings1, coordinates);
        
        // Try to retrieve with different settings
        final retrieved = await cacheManager.getCachedCrop(
          imageUrl,
          targetSize,
          settings2,
        );
        
        expect(retrieved, isNull); // Should be cache miss due to different settings
      });
      
      test('should get cached crops for image URL', () async {
        const imageUrl = 'https://example.com/multi_size_image.jpg';
        const settings = CropSettings.defaultSettings;
        
        final sizes = [
          const ui.Size(1080, 1920),
          const ui.Size(1440, 2560),
          const ui.Size(1200, 1920),
        ];
        
        // Cache crops for different sizes
        for (int i = 0; i < sizes.length; i++) {
          final coordinates = CropCoordinates(
            x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
            confidence: 0.8, strategy: 'test_$i',
          );
          
          await cacheManager.cacheCrop(imageUrl, sizes[i], settings, coordinates);
        }
        
        // Retrieve all cached crops for the image
        final cachedCrops = await cacheManager.getCachedCropsForImage(imageUrl);
        
        expect(cachedCrops.length, equals(3));
        
        // Verify each crop has the correct image URL
        for (final crop in cachedCrops) {
          expect(crop.imageUrl, equals(imageUrl));
        }
      });
      
      test('should invalidate image cache', () async {
        const imageUrl = 'https://example.com/invalidate_test.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        const coordinates = CropCoordinates(
          x: 0.1, y: 0.2, width: 0.8, height: 0.6,
          confidence: 0.9, strategy: 'test',
        );
        
        // Cache coordinates
        await cacheManager.cacheCrop(imageUrl, targetSize, settings, coordinates);
        
        // Verify it's cached
        final beforeInvalidation = await cacheManager.getCachedCrop(
          imageUrl,
          targetSize,
          settings,
        );
        expect(beforeInvalidation, isNotNull);
        
        // Invalidate cache for this image
        final invalidatedCount = await cacheManager.invalidateImageCache(imageUrl);
        expect(invalidatedCount, equals(1));
        
        // Verify it's no longer cached
        final afterInvalidation = await cacheManager.getCachedCrop(
          imageUrl,
          targetSize,
          settings,
        );
        expect(afterInvalidation, isNull);
      });
      
      test('should clear entire cache', () async {
        // Cache multiple entries
        for (int i = 0; i < 3; i++) {
          await cacheManager.cacheCrop(
            'https://example.com/image_$i.jpg',
            const ui.Size(1080, 1920),
            CropSettings.defaultSettings,
            CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test_$i',
            ),
          );
        }
        
        // Verify entries exist
        final beforeClear = await cacheManager.getStats();
        expect(beforeClear.totalEntries, equals(3));
        
        // Clear cache
        final clearedCount = await cacheManager.clearCache();
        expect(clearedCount, equals(3));
        
        // Verify cache is empty
        final afterClear = await cacheManager.getStats();
        expect(afterClear.totalEntries, equals(0));
      });
    });
    
    group('cache statistics', () {
      test('should provide accurate statistics', () async {
        // Cache some entries
        for (int i = 0; i < 5; i++) {
          await cacheManager.cacheCrop(
            'https://example.com/stats_image_$i.jpg',
            ui.Size(1080 + i * 100, 1920 + i * 100),
            CropSettings.defaultSettings,
            CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test_$i',
            ),
          );
        }
        
        final stats = await cacheManager.getStats();
        
        expect(stats.totalEntries, equals(5));
        expect(stats.totalSizeBytes, greaterThan(0));
        expect(stats.averageAccessCount, equals(1.0)); // All entries accessed once
      });
      
      test('should provide hit rate statistics', () async {
        // Clear cache first to ensure clean state
        await cacheManager.clearCache();
        
        const imageUrl = 'https://example.com/hit_rate_test.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        const coordinates = CropCoordinates(
          x: 0.1, y: 0.2, width: 0.8, height: 0.6,
          confidence: 0.9, strategy: 'test',
        );
        
        // Cache entry
        await cacheManager.cacheCrop(imageUrl, targetSize, settings, coordinates);
        
        // Access it multiple times to increase access count
        for (int i = 0; i < 3; i++) {
          await cacheManager.getCachedCrop(imageUrl, targetSize, settings);
        }
        
        final hitRateStats = await cacheManager.getHitRateStats();
        
        expect(hitRateStats.totalEntries, equals(1));
        expect(hitRateStats.maxAccessCount, greaterThan(1));
        expect(hitRateStats.estimatedHitRate, greaterThan(0.0));
      });
    });
    
    group('maintenance operations', () {
      test('should perform cache maintenance', () async {
        // This test would need more complex setup to test TTL and LRU
        // For now, just verify the method doesn't throw
        final result = await cacheManager.performMaintenance();
        
        expect(result.success, isTrue);
        expect(result.expiredEntriesDeleted, greaterThanOrEqualTo(0));
        expect(result.lruEntriesEvicted, greaterThanOrEqualTo(0));
      });
      
      test('should optimize cache by removing duplicates', () async {
        // Cache some entries
        for (int i = 0; i < 3; i++) {
          await cacheManager.cacheCrop(
            'https://example.com/optimize_image_$i.jpg',
            const ui.Size(1080, 1920),
            CropSettings.defaultSettings,
            CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test_$i',
            ),
          );
        }
        
        // Optimize cache
        final optimizedCount = await cacheManager.optimizeCache();
        
        // Should return 0 since there shouldn't be duplicates in normal operation
        expect(optimizedCount, greaterThanOrEqualTo(0));
      });
    });
    
    group('preloading', () {
      test('should preload common sizes', () async {
        const imageUrl = 'https://example.com/preload_test.jpg';
        const settings = CropSettings.defaultSettings;
        
        // Create a mock analyzer function
        Future<CropCoordinates> mockAnalyzer(ui.Size size) async {
          return CropCoordinates(
            x: 0.1,
            y: 0.2,
            width: 0.8,
            height: 0.6,
            confidence: 0.9,
            strategy: 'preload_test',
          );
        }
        
        // Create a mock source image
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = ui.Paint()..color = const ui.Color(0xFF000000);
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 1000, 1000), paint);
        final picture = recorder.endRecording();
        final sourceImage = await picture.toImage(1000, 1000);
        
        // Preload common sizes
        await cacheManager.preloadCommonSizes(
          imageUrl,
          sourceImage,
          settings,
          mockAnalyzer,
        );
        
        // Verify some entries were cached
        final stats = await cacheManager.getStats();
        expect(stats.totalEntries, greaterThan(0));
        
        // Verify some entries were cached (check stats instead of specific size)
        final cachedCrops = await cacheManager.getCachedCropsForImage(imageUrl);
        expect(cachedCrops.length, greaterThan(0));
      });
    });
    
    group('error handling', () {
      test('should handle cache operations gracefully', () async {
        // Test with non-existent cache key
        final retrieved = await cacheManager.getCachedCrop(
          'non_existent_image',
          const ui.Size(100, 100),
          CropSettings.defaultSettings,
        );
        expect(retrieved, isNull);
        
        // Test that cache operations work normally
        final cached = await cacheManager.cacheCrop(
          'test_error_handling',
          const ui.Size(100, 100),
          CropSettings.defaultSettings,
          const CropCoordinates(
            x: 0, y: 0, width: 1, height: 1,
            confidence: 1, strategy: 'test',
          ),
        );
        expect(cached, isTrue);
        
        // Close the cache manager
        await cacheManager.close();
      });
    });
  });
}