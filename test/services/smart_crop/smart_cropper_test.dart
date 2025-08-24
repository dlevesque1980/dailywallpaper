import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../../lib/services/smart_crop/smart_cropper.dart';
import '../../../lib/services/smart_crop/models/crop_settings.dart';
import '../../../lib/services/smart_crop/models/crop_coordinates.dart';
import '../../../lib/services/smart_crop/models/crop_result.dart';

void main() {
  group('SmartCropper', () {
    late ui.Image testImage;
    
    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      
      // Create a test image (100x100 pixels)
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);
      final paint = ui.Paint()..color = const ui.Color(0xFF000000);
      
      canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 100, 100), paint);
      
      final picture = recorder.endRecording();
      testImage = await picture.toImage(100, 100);
    });
    
    tearDown(() async {
      await SmartCropper.clearCache();
    });
    
    tearDownAll(() async {
      await SmartCropper.close();
    });
    
    group('analyzeCrop', () {
      test('should return valid crop result for square image', () async {
        const targetSize = ui.Size(50, 50);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.analyzeCrop(
          'test_image_1',
          testImage,
          targetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        expect(result.processingTime.inMilliseconds, greaterThan(0));
        expect(result.fromCache, isFalse);
      });
      
      test('should return cached result on second call', () async {
        const targetSize = ui.Size(50, 50);
        const settings = CropSettings.defaultSettings;
        const imageUrl = 'test_image_cache';
        
        // First call
        final result1 = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          settings,
        );
        
        // Second call should be from cache
        final result2 = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          settings,
        );
        
        expect(result1.fromCache, isFalse);
        expect(result2.fromCache, isTrue);
        expect(result2.bestCrop, equals(result1.bestCrop));
      });
      
      test('should handle timeout gracefully', () async {
        const targetSize = ui.Size(50, 50);
        const settings = CropSettings(
          maxProcessingTime: Duration(milliseconds: 1), // Very short timeout
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_timeout',
          testImage,
          targetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        // With very short timeout, it might complete normally or timeout
        expect(result.processingTime.inMilliseconds, lessThanOrEqualTo(100));
      });
      
      test('should handle memory pressure gracefully', () async {
        // Create a large target size to trigger memory pressure
        const largeTargetSize = ui.Size(5000, 5000);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.analyzeCrop(
          'test_memory_pressure',
          testImage,
          largeTargetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        // Should use fallback due to memory pressure
        expect(result.bestCrop.strategy, contains('fallback'));
      });
      
      test('should skip smart crop for very small images', () async {
        // Create a very small test image
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        final paint = ui.Paint()..color = const ui.Color(0xFF000000);
        
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 10, 10), paint);
        
        final picture = recorder.endRecording();
        final smallImage = await picture.toImage(10, 10);
        
        const targetSize = ui.Size(50, 50);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.analyzeCrop(
          'test_small_image',
          smallImage,
          targetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.strategy, contains('fallback'));
      });
      
      test('should skip smart crop for very small target sizes', () async {
        const verySmallTargetSize = ui.Size(10, 10);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.analyzeCrop(
          'test_small_target',
          testImage,
          verySmallTargetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.strategy, contains('fallback'));
      });
      
      test('should handle analyzer failures gracefully', () async {
        const targetSize = ui.Size(50, 50);
        // Create settings with all analyzers enabled to test failure handling
        const settings = CropSettings(
          enableRuleOfThirds: true,
          enableCenterWeighting: true,
          enableEntropyAnalysis: true,
          enableEdgeDetection: true,
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_analyzer_failures',
          testImage,
          targetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        // Should either succeed or use fallback
        expect(result.bestCrop.confidence, greaterThan(0.0));
      });
      
      test('should use degraded settings under memory pressure', () async {
        // This test verifies that the system can degrade gracefully
        const targetSize = ui.Size(200, 200);
        const settings = CropSettings(
          enableRuleOfThirds: true,
          enableCenterWeighting: true,
          enableEntropyAnalysis: true,
          enableEdgeDetection: true,
          maxProcessingTime: Duration(seconds: 2),
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_degraded_settings',
          testImage,
          targetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        // Should complete successfully or use fallback
        expect(result.processingTime.inMilliseconds, lessThan(3000));
      });
      
      test('should handle different aggressiveness levels', () async {
        const targetSize = ui.Size(50, 50);
        
        final conservativeSettings = CropSettings(
          aggressiveness: CropAggressiveness.conservative,
        );
        
        final aggressiveSettings = CropSettings(
          aggressiveness: CropAggressiveness.aggressive,
        );
        
        final conservativeResult = await SmartCropper.analyzeCrop(
          'test_conservative',
          testImage,
          targetSize,
          conservativeSettings,
        );
        
        final aggressiveResult = await SmartCropper.analyzeCrop(
          'test_aggressive',
          testImage,
          targetSize,
          aggressiveSettings,
        );
        
        expect(conservativeResult.bestCrop.isValid, isTrue);
        expect(aggressiveResult.bestCrop.isValid, isTrue);
        // Results may differ based on strategy weighting
      });
      
      test('should handle different aspect ratios', () async {
        const settings = CropSettings.defaultSettings;
        
        // Wide target
        const wideTarget = ui.Size(100, 50);
        final wideResult = await SmartCropper.analyzeCrop(
          'test_wide',
          testImage,
          wideTarget,
          settings,
        );
        
        // Tall target
        const tallTarget = ui.Size(50, 100);
        final tallResult = await SmartCropper.analyzeCrop(
          'test_tall',
          testImage,
          tallTarget,
          settings,
        );
        
        expect(wideResult.bestCrop.isValid, isTrue);
        expect(tallResult.bestCrop.isValid, isTrue);
        
        // Wide crop should have different proportions than tall crop
        final wideAspectRatio = wideResult.bestCrop.width / wideResult.bestCrop.height;
        final tallAspectRatio = tallResult.bestCrop.width / tallResult.bestCrop.height;
        
        expect(wideAspectRatio, greaterThan(tallAspectRatio));
      });
      
      test('should handle disabled strategies', () async {
        const targetSize = ui.Size(50, 50);
        
        const onlyRuleOfThirds = CropSettings(
          enableRuleOfThirds: true,
          enableCenterWeighting: false,
          enableEntropyAnalysis: false,
          enableEdgeDetection: false,
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_single_strategy',
          testImage,
          targetSize,
          onlyRuleOfThirds,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        expect(result.allScores.length, equals(1));
        expect(result.allScores.first.strategy, equals('rule_of_thirds'));
      });
      
      test('should return fallback when no strategies enabled', () async {
        const targetSize = ui.Size(50, 50);
        
        const noStrategies = CropSettings(
          enableRuleOfThirds: false,
          enableCenterWeighting: false,
          enableEntropyAnalysis: false,
          enableEdgeDetection: false,
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_no_strategies',
          testImage,
          targetSize,
          noStrategies,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.strategy, contains('fallback'));
      });
    });
    
    group('cache management', () {
      test('should cache and retrieve crop coordinates', () async {
        const imageUrl = 'https://example.com/cache_test.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        const coordinates = CropCoordinates(
          x: 0.1,
          y: 0.2,
          width: 0.8,
          height: 0.6,
          confidence: 0.9,
          strategy: 'test',
        );
        
        // Cache should be empty initially
        final initialCached = await SmartCropper.getCachedCrop(imageUrl, targetSize, settings);
        expect(initialCached, isNull);
        
        // Cache the coordinates
        final cached = await SmartCropper.cacheCrop(imageUrl, targetSize, settings, coordinates);
        expect(cached, isTrue);
        
        // Should retrieve the same coordinates
        final retrieved = await SmartCropper.getCachedCrop(imageUrl, targetSize, settings);
        expect(retrieved, equals(coordinates));
      });
      
      test('should clear cache', () async {
        const imageUrl = 'https://example.com/clear_test.jpg';
        const targetSize = ui.Size(1080, 1920);
        const settings = CropSettings.defaultSettings;
        const coordinates = CropCoordinates(
          x: 0.1,
          y: 0.2,
          width: 0.8,
          height: 0.6,
          confidence: 0.9,
          strategy: 'test',
        );
        
        // Cache coordinates
        await SmartCropper.cacheCrop(imageUrl, targetSize, settings, coordinates);
        final beforeClear = await SmartCropper.getCachedCrop(imageUrl, targetSize, settings);
        expect(beforeClear, isNotNull);
        
        // Clear cache
        final clearedCount = await SmartCropper.clearCache();
        expect(clearedCount, greaterThanOrEqualTo(0));
        
        // Should be cleared
        final afterClear = await SmartCropper.getCachedCrop(imageUrl, targetSize, settings);
        expect(afterClear, isNull);
      });
      
      test('should provide cache statistics', () async {
        await SmartCropper.clearCache();
        
        final initialStats = await SmartCropper.getCacheStats();
        expect(initialStats['crop_cache_size'], equals(0));
        
        // Add some cache entries
        await SmartCropper.cacheCrop(
          'https://example.com/stats1.jpg',
          const ui.Size(1080, 1920),
          CropSettings.defaultSettings,
          const CropCoordinates(x: 0, y: 0, width: 1, height: 1, confidence: 1, strategy: 'test'),
        );
        await SmartCropper.cacheCrop(
          'https://example.com/stats2.jpg',
          const ui.Size(1080, 1920),
          CropSettings.defaultSettings,
          const CropCoordinates(x: 0, y: 0, width: 1, height: 1, confidence: 1, strategy: 'test'),
        );
        
        final stats = await SmartCropper.getCacheStats();
        expect(stats['crop_cache_size'], equals(2));
        expect(stats['crop_cache_size_mb'], greaterThanOrEqualTo(0.0));
        expect(stats['hit_rate_percentage'], greaterThanOrEqualTo(0.0));
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
        await SmartCropper.cacheCrop(imageUrl, targetSize, settings, coordinates);
        
        // Verify it's cached
        final beforeInvalidation = await SmartCropper.getCachedCrop(imageUrl, targetSize, settings);
        expect(beforeInvalidation, isNotNull);
        
        // Invalidate cache for this image
        final invalidatedCount = await SmartCropper.invalidateImageCache(imageUrl);
        expect(invalidatedCount, greaterThanOrEqualTo(0));
        
        // Should be invalidated
        final afterInvalidation = await SmartCropper.getCachedCrop(imageUrl, targetSize, settings);
        expect(afterInvalidation, isNull);
      });
      
      test('should perform cache maintenance', () async {
        // Add some entries first
        for (int i = 0; i < 3; i++) {
          await SmartCropper.cacheCrop(
            'https://example.com/maintenance_$i.jpg',
            const ui.Size(1080, 1920),
            CropSettings.defaultSettings,
            CropCoordinates(
              x: 0.1 * i, y: 0.1 * i, width: 0.8, height: 0.8,
              confidence: 0.8, strategy: 'test_$i',
            ),
          );
        }
        
        // Perform maintenance
        final result = await SmartCropper.performCacheMaintenance();
        
        expect(result['success'], isTrue);
        expect(result['expired_entries_deleted'], greaterThanOrEqualTo(0));
        expect(result['lru_entries_evicted'], greaterThanOrEqualTo(0));
        expect(result['total_entries_deleted'], greaterThanOrEqualTo(0));
      });
    });
    
    group('error handling and fallbacks', () {
      test('should handle invalid image gracefully', () async {
        // Test with invalid target size instead since 0x0 image creation fails
        const invalidTargetSize = ui.Size(-1, -1);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.analyzeCrop(
          'test_invalid_image',
          testImage,
          invalidTargetSize,
          settings,
        );
        
        // Should return fallback crop
        expect(result.bestCrop.strategy, contains('fallback'));
      });
      
      test('should handle invalid target size gracefully', () async {
        const invalidTargetSize = ui.Size(0, 0);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.analyzeCrop(
          'test_invalid_target',
          testImage,
          invalidTargetSize,
          settings,
        );
        
        // Should return fallback crop
        expect(result.bestCrop.strategy, contains('fallback'));
      });
      
      test('should handle extreme timeout scenarios', () async {
        const targetSize = ui.Size(50, 50);
        const extremeTimeout = CropSettings(
          maxProcessingTime: Duration(microseconds: 1), // Extremely short
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_extreme_timeout',
          testImage,
          targetSize,
          extremeTimeout,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.strategy, contains('fallback'));
      });
      
      test('should handle memory estimation errors gracefully', () async {
        const targetSize = ui.Size(50, 50);
        const settings = CropSettings.defaultSettings;
        
        // This should not throw even if memory estimation has issues
        final memoryUsage = SmartCropper.estimateMemoryUsage(testImage, targetSize);
        expect(memoryUsage, greaterThan(0));
        
        final shouldProcess = SmartCropper.shouldProcessImage(
          testImage, 
          targetSize, 
          maxMemoryMB: 1, // Very low limit
        );
        expect(shouldProcess, isA<bool>());
      });
      
      test('should provide different fallback strategies', () async {
        const targetSize = ui.Size(50, 50);
        
        // Test timeout fallback
        const timeoutSettings = CropSettings(
          maxProcessingTime: Duration(milliseconds: 1),
        );
        
        final timeoutResult = await SmartCropper.analyzeCrop(
          'test_timeout_fallback',
          testImage,
          targetSize,
          timeoutSettings,
        );
        
        expect(timeoutResult.bestCrop.isValid, isTrue);
        
        // Test memory pressure fallback with large image
        const largeTargetSize = ui.Size(8000, 8000);
        final memoryResult = await SmartCropper.analyzeCrop(
          'test_memory_fallback',
          testImage,
          largeTargetSize,
          CropSettings.defaultSettings,
        );
        
        expect(memoryResult.bestCrop.isValid, isTrue);
      });
      
      test('should handle cache errors gracefully', () async {
        const targetSize = ui.Size(50, 50);
        const settings = CropSettings.defaultSettings;
        
        // This should not fail even if caching has issues
        final result = await SmartCropper.analyzeCrop(
          'test_cache_error_handling',
          testImage,
          targetSize,
          settings,
        );
        
        expect(result, isA<CropResult>());
        expect(result.bestCrop.isValid, isTrue);
      });
      
      test('should validate fallback crop coordinates', () async {
        const targetSize = ui.Size(50, 50);
        const invalidSettings = CropSettings(
          enableRuleOfThirds: false,
          enableCenterWeighting: false,
          enableEntropyAnalysis: false,
          enableEdgeDetection: false,
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_fallback_validation',
          testImage,
          targetSize,
          invalidSettings,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.x, greaterThanOrEqualTo(0.0));
        expect(result.bestCrop.y, greaterThanOrEqualTo(0.0));
        expect(result.bestCrop.width, greaterThan(0.0));
        expect(result.bestCrop.height, greaterThan(0.0));
        expect(result.bestCrop.x + result.bestCrop.width, lessThanOrEqualTo(1.0));
        expect(result.bestCrop.y + result.bestCrop.height, lessThanOrEqualTo(1.0));
      });
    });
    
    group('strategy coordination', () {
      test('should combine multiple strategy scores', () async {
        const targetSize = ui.Size(50, 50);
        const settings = CropSettings(
          enableRuleOfThirds: true,
          enableCenterWeighting: true,
          enableEntropyAnalysis: true,
          enableEdgeDetection: false, // Keep disabled for performance
        );
        
        final result = await SmartCropper.analyzeCrop(
          'test_multi_strategy',
          testImage,
          targetSize,
          settings,
        );
        
        expect(result.allScores.length, greaterThanOrEqualTo(2));
        expect(result.bestCrop.isValid, isTrue);
        
        // Should have scores from multiple strategies
        final strategies = result.allScores.map((s) => s.strategy).toSet();
        expect(strategies.length, greaterThanOrEqualTo(2));
      });
      
      test('should apply aggressiveness weighting correctly', () async {
        const targetSize = ui.Size(50, 50);
        
        final conservativeResult = await SmartCropper.analyzeCrop(
          'test_conservative_weight',
          testImage,
          targetSize,
          const CropSettings(aggressiveness: CropAggressiveness.conservative),
        );
        
        final aggressiveResult = await SmartCropper.analyzeCrop(
          'test_aggressive_weight',
          testImage,
          targetSize,
          const CropSettings(aggressiveness: CropAggressiveness.aggressive),
        );
        
        expect(conservativeResult.bestCrop.isValid, isTrue);
        expect(aggressiveResult.bestCrop.isValid, isTrue);
        
        // Results should be valid regardless of aggressiveness
        // (Specific behavior differences would require more complex test images)
      });
    });
    
    group('applyCrop', () {
      test('should crop image correctly', () async {
        const cropCoordinates = CropCoordinates(
          x: 0.25,
          y: 0.25,
          width: 0.5,
          height: 0.5,
          confidence: 1.0,
          strategy: 'test',
        );
        
        final croppedImage = await SmartCropper.applyCrop(testImage, cropCoordinates);
        
        expect(croppedImage.width, equals(50)); // 50% of 100
        expect(croppedImage.height, equals(50)); // 50% of 100
      });
      
      test('should handle edge crop coordinates', () async {
        const edgeCrop = CropCoordinates(
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
          confidence: 1.0,
          strategy: 'test',
        );
        
        final croppedImage = await SmartCropper.applyCrop(testImage, edgeCrop);
        
        expect(croppedImage.width, equals(testImage.width));
        expect(croppedImage.height, equals(testImage.height));
      });
      
      test('should handle invalid crop coordinates gracefully', () async {
        const invalidCrop = CropCoordinates(
          x: -0.1,
          y: -0.1,
          width: 1.2,
          height: 1.2,
          confidence: 1.0,
          strategy: 'test',
        );
        
        final result = await SmartCropper.applyCrop(testImage, invalidCrop);
        
        // Should return original image on invalid coordinates
        expect(result.width, equals(testImage.width));
        expect(result.height, equals(testImage.height));
      });
    });
    
    group('applyCropAndResize', () {
      test('should crop and resize image correctly', () async {
        const cropCoordinates = CropCoordinates(
          x: 0.25,
          y: 0.25,
          width: 0.5,
          height: 0.5,
          confidence: 1.0,
          strategy: 'test',
        );
        
        const targetSize = ui.Size(200, 200);
        
        final result = await SmartCropper.applyCropAndResize(
          testImage,
          cropCoordinates,
          targetSize,
        );
        
        expect(result.width, equals(200));
        expect(result.height, equals(200));
      });
      
      test('should handle different aspect ratios', () async {
        const cropCoordinates = CropCoordinates(
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
          confidence: 1.0,
          strategy: 'test',
        );
        
        const wideTargetSize = ui.Size(200, 100);
        
        final result = await SmartCropper.applyCropAndResize(
          testImage,
          cropCoordinates,
          wideTargetSize,
        );
        
        expect(result.width, equals(200));
        expect(result.height, equals(100));
      });
    });
    
    group('processImage', () {
      test('should process image end-to-end', () async {
        const targetSize = ui.Size(80, 80);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.processImage(
          'test_process',
          testImage,
          targetSize,
          settings,
        );
        
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.image.width, equals(80));
        expect(result.image.height, equals(80));
        expect(result.cropResult.bestCrop.isValid, isTrue);
      });
      
      test('should handle processing errors gracefully', () async {
        const invalidTargetSize = ui.Size(-1, -1);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.processImage(
          'test_process_error',
          testImage,
          invalidTargetSize,
          settings,
        );
        
        expect(result.success, isFalse);
        expect(result.error, isNotNull);
        // Should still return a valid image (fallback)
        expect(result.image.width, greaterThan(0));
        expect(result.image.height, greaterThan(0));
      });
    });
    
    group('memory management', () {
      test('should estimate memory usage correctly', () {
        const targetSize = ui.Size(200, 200);
        
        final memoryUsage = SmartCropper.estimateMemoryUsage(testImage, targetSize);
        
        expect(memoryUsage, greaterThan(0));
        
        // Should account for source, target, and processing memory
        const bytesPerPixel = 4;
        final expectedMinimum = (100 * 100 + 200 * 200) * bytesPerPixel;
        expect(memoryUsage, greaterThanOrEqualTo(expectedMinimum));
      });
      
      test('should make processing decisions based on memory constraints', () {
        const smallTargetSize = ui.Size(50, 50);
        const largeTargetSize = ui.Size(5000, 5000);
        
        final shouldProcessSmall = SmartCropper.shouldProcessImage(
          testImage,
          smallTargetSize,
          maxMemoryMB: 10,
        );
        
        final shouldProcessLarge = SmartCropper.shouldProcessImage(
          testImage,
          largeTargetSize,
          maxMemoryMB: 10,
        );
        
        expect(shouldProcessSmall, isTrue);
        expect(shouldProcessLarge, isFalse);
      });
    });
  });
}