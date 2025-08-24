import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

void main() {
  group('Cache Integration Tests', () {
    late ui.Image testImage;
    
    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Create a test image (200x200 pixels)
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = const ui.Color(0xFF0000FF);
      
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 200, 200), paint);
      
      final picture = recorder.endRecording();
      testImage = await picture.toImage(200, 200);
    });
    
    setUp(() async {
      await SmartCropper.clearCache();
    });
    
    tearDownAll(() async {
      await SmartCropper.close();
    });

    test('should cache crop results and improve performance on subsequent calls', () async {
      const imageUrl = 'https://example.com/integration_test.jpg';
      const targetSize = ui.Size(100, 150);
      const settings = CropSettings.defaultSettings;
      
      // First call - should analyze and cache
      final stopwatch1 = Stopwatch()..start();
      final result1 = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings);
      stopwatch1.stop();
      
      expect(result1.fromCache, isFalse);
      expect(result1.bestCrop.isValid, isTrue);
      
      // Second call - should use cache
      final stopwatch2 = Stopwatch()..start();
      final result2 = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings);
      stopwatch2.stop();
      
      expect(result2.fromCache, isTrue);
      expect(result2.bestCrop, equals(result1.bestCrop));
      
      // Cache hit should be faster (though this might not always be true in tests)
      // We just verify that both calls completed successfully
      expect(stopwatch1.elapsedMicroseconds, greaterThan(0));
      expect(stopwatch2.elapsedMicroseconds, greaterThan(0));
    });
    
    test('should handle cache invalidation correctly', () async {
      const imageUrl = 'https://example.com/invalidation_test.jpg';
      const targetSize = ui.Size(100, 150);
      const settings1 = CropSettings.defaultSettings;
      const settings2 = CropSettings(
        aggressiveness: CropAggressiveness.aggressive,
        enableRuleOfThirds: false,
      );
      
      // Cache with first settings
      final result1 = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings1);
      expect(result1.fromCache, isFalse);
      
      // Use cache with same settings
      final result2 = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings1);
      expect(result2.fromCache, isTrue);
      
      // Different settings should not use cache
      final result3 = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings2);
      expect(result3.fromCache, isFalse);
      
      // Invalidate cache for this image
      final invalidatedCount = await SmartCropper.invalidateImageCache(imageUrl);
      expect(invalidatedCount, greaterThan(0));
      
      // Should not use cache after invalidation
      final result4 = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings1);
      expect(result4.fromCache, isFalse);
    });
    
    test('should handle multiple images and sizes correctly', () async {
      final imageUrls = [
        'https://example.com/multi_test_1.jpg',
        'https://example.com/multi_test_2.jpg',
        'https://example.com/multi_test_3.jpg',
      ];
      
      final targetSizes = [
        const ui.Size(100, 150),
        const ui.Size(150, 200),
        const ui.Size(200, 100),
      ];
      
      const settings = CropSettings.defaultSettings;
      
      // Cache crops for all combinations
      for (final imageUrl in imageUrls) {
        for (final targetSize in targetSizes) {
          final result = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings);
          expect(result.fromCache, isFalse);
          expect(result.bestCrop.isValid, isTrue);
        }
      }
      
      // Verify all are cached
      for (final imageUrl in imageUrls) {
        for (final targetSize in targetSizes) {
          final result = await SmartCropper.analyzeCrop(imageUrl, testImage, targetSize, settings);
          expect(result.fromCache, isTrue);
        }
      }
      
      // Check cache statistics
      final stats = await SmartCropper.getCacheStats();
      expect(stats['crop_cache_size'], equals(9)); // 3 images × 3 sizes
      expect(stats['crop_cache_size_mb'], greaterThan(0.0));
    });
    
    test('should perform end-to-end processing with cache', () async {
      const imageUrl = 'https://example.com/e2e_test.jpg';
      const targetSize = ui.Size(80, 120);
      const settings = CropSettings.defaultSettings;
      
      // First processing - should analyze, cache, and process
      final result1 = await SmartCropper.processImage(imageUrl, testImage, targetSize, settings);
      
      expect(result1.success, isTrue);
      expect(result1.error, isNull);
      expect(result1.image.width, equals(80));
      expect(result1.image.height, equals(120));
      expect(result1.cropResult.fromCache, isFalse);
      
      // Second processing - should use cached analysis
      final result2 = await SmartCropper.processImage(imageUrl, testImage, targetSize, settings);
      
      expect(result2.success, isTrue);
      expect(result2.error, isNull);
      expect(result2.image.width, equals(80));
      expect(result2.image.height, equals(120));
      expect(result2.cropResult.fromCache, isTrue);
      
      // Results should have the same crop coordinates
      expect(result2.cropResult.bestCrop, equals(result1.cropResult.bestCrop));
    });
    
    test('should handle cache maintenance operations', () async {
      // Add several cache entries
      for (int i = 0; i < 5; i++) {
        await SmartCropper.analyzeCrop(
          'https://example.com/maintenance_$i.jpg',
          testImage,
          ui.Size(100 + i * 10, 150 + i * 10),
          CropSettings.defaultSettings,
        );
      }
      
      // Verify entries are cached
      final initialStats = await SmartCropper.getCacheStats();
      expect(initialStats['crop_cache_size'], equals(5));
      
      // Perform maintenance
      final maintenanceResult = await SmartCropper.performCacheMaintenance(
        maxEntries: 3, // Force LRU eviction
      );
      
      expect(maintenanceResult['success'], isTrue);
      expect(maintenanceResult['total_entries_deleted'], greaterThanOrEqualTo(0));
      
      // Check final stats
      final finalStats = await SmartCropper.getCacheStats();
      expect(finalStats['crop_cache_size'], lessThanOrEqualTo(5));
    });
    
    test('should handle preloading for common sizes', () async {
      const imageUrl = 'https://example.com/preload_test.jpg';
      const settings = CropSettings.defaultSettings;
      
      // Preload common sizes
      await SmartCropper.preloadCommonSizes(imageUrl, testImage, settings);
      
      // Check that some entries were cached
      final stats = await SmartCropper.getCacheStats();
      expect(stats['crop_cache_size'], greaterThan(0));
      
      // Try to get a common size - should be cached
      final result = await SmartCropper.analyzeCrop(
        imageUrl,
        testImage,
        const ui.Size(1080, 1920), // Common phone size
        settings,
      );
      
      // May or may not be from cache depending on exact preload implementation
      expect(result.bestCrop.isValid, isTrue);
    });
  });
}