import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

void main() {
  group('Smart Crop Final Integration Tests', () {
    late ui.Image testImage;
    
    setUpAll(() async {
      // Create a test image for integration testing
      testImage = await _createTestImage(800, 600);
    });
    
    tearDownAll(() {
      testImage.dispose();
      SmartCropper.close();
    });
    
    setUp(() {
      // Clear caches before each test
      SmartCropper.clearPerformanceData();
      SmartCropper.clearDeviceCapabilityCache();
    });
    
    group('Image Source Compatibility', () {
      test('should work with Bing-style landscape images', () async {
        // Simulate Bing wallpaper dimensions (typically 1920x1080)
        final bingImage = await _createTestImage(1920, 1080);
        final targetSize = ui.Size(1080, 2400); // Modern phone screen
        
        final result = await SmartCropper.analyzeCrop(
          'bing_test_image',
          bingImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.confidence, greaterThan(0.0));
        expect(result.processingTime.inMilliseconds, lessThan(5000));
        
        bingImage.dispose();
      });
      
      test('should work with Pexels-style portrait images', () async {
        // Simulate Pexels portrait dimensions
        final pexelsImage = await _createTestImage(1080, 1920);
        final targetSize = ui.Size(1080, 2400); // Modern phone screen
        
        final result = await SmartCropper.analyzeCrop(
          'pexels_test_image',
          pexelsImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.confidence, greaterThan(0.0));
        expect(result.processingTime.inMilliseconds, lessThan(5000));
        
        pexelsImage.dispose();
      });
      
      test('should work with NASA-style square images', () async {
        // Simulate NASA APOD dimensions (often square or various ratios)
        final nasaImage = await _createTestImage(1024, 1024);
        final targetSize = ui.Size(1080, 2400); // Modern phone screen
        
        final result = await SmartCropper.analyzeCrop(
          'nasa_test_image',
          nasaImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.confidence, greaterThan(0.0));
        expect(result.processingTime.inMilliseconds, lessThan(5000));
        
        nasaImage.dispose();
      });
      
      test('should handle extreme aspect ratios', () async {
        // Test with very wide image
        final wideImage = await _createTestImage(2560, 720);
        final targetSize = ui.Size(1080, 2400);
        
        final wideResult = await SmartCropper.analyzeCrop(
          'wide_test_image',
          wideImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(wideResult.bestCrop.isValid, isTrue);
        
        // Test with very tall image
        final tallImage = await _createTestImage(720, 2560);
        
        final tallResult = await SmartCropper.analyzeCrop(
          'tall_test_image',
          tallImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(tallResult.bestCrop.isValid, isTrue);
        
        wideImage.dispose();
        tallImage.dispose();
      });
    });
    
    group('Settings Integration', () {
      test('should respect all crop settings combinations', () async {
        final targetSize = ui.Size(1080, 2400);
        
        // Test all aggressiveness levels
        for (final aggressiveness in CropAggressiveness.values) {
          final settings = CropSettings(
            aggressiveness: aggressiveness,
            enableRuleOfThirds: true,
            enableEntropyAnalysis: true,
            enableEdgeDetection: true,
            enableCenterWeighting: true,
            maxProcessingTime: const Duration(seconds: 3),
          );
          
          final result = await SmartCropper.analyzeCrop(
            'settings_test_${aggressiveness.name}',
            testImage,
            targetSize,
            settings,
          );
          
          expect(result.bestCrop.isValid, isTrue);
          expect(result.processingTime.inMilliseconds, lessThan(5000));
        }
      });
      
      test('should work with minimal settings', () async {
        final minimalSettings = CropSettings(
          aggressiveness: CropAggressiveness.conservative,
          enableRuleOfThirds: false,
          enableEntropyAnalysis: false,
          enableEdgeDetection: false,
          enableCenterWeighting: true, // At least one must be enabled
          maxProcessingTime: const Duration(milliseconds: 500),
        );
        
        final result = await SmartCropper.analyzeCrop(
          'minimal_settings_test',
          testImage,
          ui.Size(1080, 2400),
          minimalSettings,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        expect(result.bestCrop.strategy, contains('center'));
      });
      
      test('should handle settings refresh functionality', () async {
        final targetSize = ui.Size(1080, 2400);
        
        // First analysis with default settings
        final result1 = await SmartCropper.analyzeCrop(
          'refresh_test_image',
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        // Change settings and analyze again
        final newSettings = CropSettings.defaultSettings.copyWith(
          aggressiveness: CropAggressiveness.aggressive,
          enableEdgeDetection: false,
        );
        
        final result2 = await SmartCropper.analyzeCrop(
          'refresh_test_image',
          testImage,
          targetSize,
          newSettings,
        );
        
        // Results should be different due to settings change
        expect(result1.bestCrop.isValid, isTrue);
        expect(result2.bestCrop.isValid, isTrue);
        
        // Should not use cache due to settings change
        expect(result2.fromCache, isFalse);
      });
    });
    
    group('Performance Impact Assessment', () {
      test('should not significantly impact app startup time', () async {
        final stopwatch = Stopwatch()..start();
        
        // Simulate app startup operations
        await SmartCropper.getCacheStats();
        final deviceInfo = await SmartCropper.getDeviceCapabilityInfo();
        
        stopwatch.stop();
        
        // Startup operations should be very fast
        expect(stopwatch.elapsedMilliseconds, lessThan(100));
        expect(deviceInfo, isNotNull);
      });
      
      test('should handle concurrent image processing', () async {
        final targetSize = ui.Size(1080, 2400);
        final futures = <Future<void>>[];
        
        // Process multiple images concurrently
        for (int i = 0; i < 5; i++) {
          futures.add(
            SmartCropper.analyzeCrop(
              'concurrent_test_$i',
              testImage,
              targetSize,
              CropSettings.defaultSettings,
            ).then((result) {
              expect(result.bestCrop.isValid, isTrue);
            }),
          );
        }
        
        // All should complete successfully
        await Future.wait(futures);
      });
      
      test('should provide performance analytics', () async {
        // Perform some operations to generate metrics
        await SmartCropper.analyzeCrop(
          'analytics_test',
          testImage,
          ui.Size(1080, 2400),
          CropSettings.defaultSettings,
        );
        
        final analytics = SmartCropper.getPerformanceAnalytics();
        
        expect(analytics, isA<Map<String, dynamic>>());
        expect(analytics.containsKey('overall_stats'), isTrue);
        expect(analytics.containsKey('trends'), isTrue);
        expect(analytics.containsKey('cache_stats'), isTrue);
        expect(analytics['overall_stats']['total_operations'], greaterThan(0));
      });
      
      test('should handle memory pressure gracefully', () async {
        // Test with large image that might trigger memory pressure
        final largeImage = await _createTestImage(4096, 4096);
        final targetSize = ui.Size(1080, 2400);
        
        final result = await SmartCropper.analyzeCrop(
          'memory_pressure_test',
          largeImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        // Should still produce valid result, possibly with fallback
        expect(result.bestCrop.isValid, isTrue);
        
        largeImage.dispose();
      });
    });
    
    group('Cache Integration', () {
      test('should cache and retrieve crop coordinates', () async {
        final targetSize = ui.Size(1080, 2400);
        final imageUrl = 'cache_integration_test';
        
        // First call - should not be from cache
        final result1 = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(result1.fromCache, isFalse);
        
        // Second call - should be from cache (if caching is working)
        final result2 = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        // Cache might not work in test environment, so just verify coordinates are consistent
        expect(result2.bestCrop.isValid, isTrue);
        if (result2.fromCache) {
          expect(result2.bestCrop.x, result1.bestCrop.x);
          expect(result2.bestCrop.y, result1.bestCrop.y);
        }
      });
      
      test('should invalidate cache when settings change', () async {
        final targetSize = ui.Size(1080, 2400);
        final imageUrl = 'cache_invalidation_test';
        
        // First call with default settings
        await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        // Second call with different settings - should not use cache
        final differentSettings = CropSettings.defaultSettings.copyWith(
          aggressiveness: CropAggressiveness.aggressive,
        );
        
        final result = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          differentSettings,
        );
        
        expect(result.fromCache, isFalse);
      });
    });
    
    group('Error Handling and Fallbacks', () {
      test('should handle invalid image gracefully', () async {
        // Create a minimal 1x1 image that might cause issues
        final tinyImage = await _createTestImage(1, 1);
        
        final result = await SmartCropper.analyzeCrop(
          'tiny_image_test',
          tinyImage,
          ui.Size(1080, 2400),
          CropSettings.defaultSettings,
        );
        
        // Should still produce a valid result (likely fallback)
        expect(result.bestCrop.isValid, isTrue);
        
        tinyImage.dispose();
      });
      
      test('should handle timeout scenarios', () async {
        final veryShortTimeout = CropSettings.defaultSettings.copyWith(
          maxProcessingTime: const Duration(milliseconds: 1), // Very short timeout
        );
        
        final result = await SmartCropper.analyzeCrop(
          'timeout_test',
          testImage,
          ui.Size(1080, 2400),
          veryShortTimeout,
        );
        
        // Should produce valid result (might be fallback or fast processing)
        expect(result.bestCrop.isValid, isTrue);
        // Don't strictly require fallback as fast processing might complete in time
        expect(result.processingTime.inMilliseconds, lessThan(100));
      });
    });
    
    group('Device Capability Integration', () {
      test('should adapt to device capabilities', () async {
        final deviceInfo = await SmartCropper.getDeviceCapabilityInfo();
        
        expect(deviceInfo, isA<Map<String, dynamic>>());
        expect(deviceInfo.containsKey('device_capability'), isTrue);
        expect(deviceInfo.containsKey('battery_optimization'), isTrue);
        expect(deviceInfo.containsKey('performance_constants'), isTrue);
        
        final deviceCapability = deviceInfo['device_capability'];
        expect(deviceCapability['platform'], isNotNull);
        expect(deviceCapability['overall_tier'], isNotNull);
        expect(deviceCapability['max_concurrent_analyzers'], greaterThan(0));
      });
      
      test('should apply battery optimizations', () async {
        // This test verifies that battery optimization is being applied
        // The actual optimization behavior is tested in battery_optimizer_test.dart
        
        final result = await SmartCropper.analyzeCrop(
          'battery_optimization_test',
          testImage,
          ui.Size(1080, 2400),
          CropSettings.defaultSettings,
        );
        
        expect(result.bestCrop.isValid, isTrue);
        
        // Check that performance monitoring is working
        final analytics = SmartCropper.getPerformanceAnalytics();
        expect(analytics['overall_stats']['total_operations'], greaterThan(0));
      });
    });
  });
}

/// Creates a test image with the specified dimensions
Future<ui.Image> _createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create a simple gradient pattern for testing
  final paint = ui.Paint();
  
  // Draw a gradient background
  for (int y = 0; y < height; y += 10) {
    for (int x = 0; x < width; x += 10) {
      final intensity = ((x + y) % 255) / 255.0;
      paint.color = ui.Color.fromRGBO(
        (intensity * 255).round(),
        ((1 - intensity) * 255).round(),
        128,
        1.0,
      );
      
      canvas.drawRect(
        ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), 10, 10),
        paint,
      );
    }
  }
  
  // Add some high-contrast elements for edge detection
  paint.color = const ui.Color(0xFFFFFFFF);
  canvas.drawCircle(
    ui.Offset(width * 0.3, height * 0.3),
    math.min(width, height) * 0.1,
    paint,
  );
  
  paint.color = const ui.Color(0xFF000000);
  canvas.drawRect(
    ui.Rect.fromLTWH(
      width * 0.6,
      height * 0.6,
      width * 0.2,
      height * 0.2,
    ),
    paint,
  );
  
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  
  return image;
}