import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

void main() {
  group('Image Pipeline Integration Tests', () {
    late ui.Image testImage;
    
    setUpAll(() async {
      testImage = await _createTestImage(1920, 1080);
    });
    
    tearDownAll(() {
      testImage.dispose();
      SmartCropper.close();
    });
    
    group('Image Loading Pipeline Compatibility', () {
      test('should integrate with image download workflow', () async {
        // Simulate the typical image loading workflow
        final imageUrl = 'https://example.com/wallpaper.jpg';
        final targetSize = ui.Size(1080, 2400);
        
        // Step 1: Image downloaded (simulated)
        final downloadedImage = testImage;
        
        // Step 2: Smart crop analysis
        final cropResult = await SmartCropper.analyzeCrop(
          imageUrl,
          downloadedImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(cropResult.bestCrop.isValid, isTrue);
        
        // Step 3: Apply crop for display
        final croppedImage = await SmartCropper.applyCrop(
          downloadedImage,
          cropResult.bestCrop,
        );
        
        expect(croppedImage.width, greaterThan(0));
        expect(croppedImage.height, greaterThan(0));
        
        croppedImage.dispose();
      });
      
      test('should work with cached images', () async {
        final imageUrl = 'cached_image_test';
        final targetSize = ui.Size(1080, 2400);
        
        // First processing - should cache the result
        final result1 = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        // Second processing - should use cache if available
        final result2 = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        expect(result1.bestCrop.isValid, isTrue);
        expect(result2.bestCrop.isValid, isTrue);
        
        // If cached, should be much faster
        if (result2.fromCache) {
          expect(result2.processingTime.inMilliseconds, lessThan(50));
        }
      });
      
      test('should handle different image formats and sizes', () async {
        final testCases = [
          {'width': 1920, 'height': 1080, 'name': 'HD Landscape'},
          {'width': 1080, 'height': 1920, 'name': 'HD Portrait'},
          {'width': 2560, 'height': 1440, 'name': 'QHD Landscape'},
          {'width': 1440, 'height': 2560, 'name': 'QHD Portrait'},
          {'width': 1024, 'height': 1024, 'name': 'Square'},
          {'width': 3840, 'height': 2160, 'name': '4K Landscape'},
        ];
        
        final targetSize = ui.Size(1080, 2400);
        
        for (final testCase in testCases) {
          final image = await _createTestImage(
            testCase['width'] as int,
            testCase['height'] as int,
          );
          
          final result = await SmartCropper.analyzeCrop(
            'test_${testCase['name']}',
            image,
            targetSize,
            CropSettings.defaultSettings,
          );
          
          expect(result.bestCrop.isValid, isTrue, 
                 reason: 'Failed for ${testCase['name']}');
          expect(result.processingTime.inMilliseconds, lessThan(10000),
                 reason: 'Too slow for ${testCase['name']}');
          
          image.dispose();
        }
      });
    });
    
    group('Performance Impact on App Startup', () {
      test('should not delay app initialization', () async {
        final stopwatch = Stopwatch()..start();
        
        // Simulate app startup operations that might use smart crop
        await SmartCropper.getCacheStats();
        final deviceInfo = await SmartCropper.getDeviceCapabilityInfo();
        
        stopwatch.stop();
        
        // Should complete very quickly
        expect(stopwatch.elapsedMilliseconds, lessThan(200));
        expect(deviceInfo, isNotNull);
      });
      
      test('should handle cold start efficiently', () async {
        // Clear all caches to simulate cold start
        SmartCropper.clearDeviceCapabilityCache();
        SmartCropper.clearPerformanceData();
        
        final stopwatch = Stopwatch()..start();
        
        // First operation after cold start
        final result = await SmartCropper.analyzeCrop(
          'cold_start_test',
          testImage,
          ui.Size(1080, 2400),
          CropSettings.defaultSettings,
        );
        
        stopwatch.stop();
        
        expect(result.bestCrop.isValid, isTrue);
        // Should complete within reasonable time even on cold start
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });
    
    group('Memory Management in Production', () {
      test('should handle multiple concurrent operations', () async {
        final futures = <Future<void>>[];
        final targetSize = ui.Size(1080, 2400);
        
        // Start multiple operations concurrently
        for (int i = 0; i < 10; i++) {
          futures.add(
            SmartCropper.analyzeCrop(
              'concurrent_$i',
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
        
        // Check that performance monitoring is working
        final analytics = SmartCropper.getPerformanceAnalytics();
        expect(analytics['overall_stats']['total_operations'], greaterThanOrEqualTo(10));
      });
      
      test('should clean up resources properly', () async {
        // Perform operations that create temporary resources
        for (int i = 0; i < 5; i++) {
          final result = await SmartCropper.analyzeCrop(
            'cleanup_test_$i',
            testImage,
            ui.Size(1080, 2400),
            CropSettings.defaultSettings,
          );
          
          expect(result.bestCrop.isValid, isTrue);
        }
        
        // Close should clean up all resources
        await SmartCropper.close();
        
        // Verify cleanup by checking that we can restart
        final result = await SmartCropper.analyzeCrop(
          'after_cleanup_test',
          testImage,
          ui.Size(1080, 2400),
          CropSettings.defaultSettings,
        );
        
        expect(result.bestCrop.isValid, isTrue);
      });
    });
    
    group('Settings Refresh Compatibility', () {
      test('should handle settings changes during operation', () async {
        final targetSize = ui.Size(1080, 2400);
        
        // Start with default settings
        final result1 = await SmartCropper.analyzeCrop(
          'settings_change_test',
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        // Change settings (simulating user changing preferences)
        final newSettings = CropSettings.defaultSettings.copyWith(
          aggressiveness: CropAggressiveness.aggressive,
          enableEdgeDetection: false,
        );
        
        // Process with new settings
        final result2 = await SmartCropper.analyzeCrop(
          'settings_change_test',
          testImage,
          targetSize,
          newSettings,
        );
        
        expect(result1.bestCrop.isValid, isTrue);
        expect(result2.bestCrop.isValid, isTrue);
        
        // Should not use cache due to settings change
        expect(result2.fromCache, isFalse);
      });
      
      test('should invalidate cache when settings change', () async {
        final imageUrl = 'cache_invalidation_test';
        final targetSize = ui.Size(1080, 2400);
        
        // Process with initial settings
        await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        
        // Change settings significantly
        final differentSettings = CropSettings(
          aggressiveness: CropAggressiveness.conservative,
          enableRuleOfThirds: false,
          enableEntropyAnalysis: false,
          enableEdgeDetection: false,
          enableCenterWeighting: true,
          maxProcessingTime: const Duration(seconds: 1),
        );
        
        // Process with different settings
        final result = await SmartCropper.analyzeCrop(
          imageUrl,
          testImage,
          targetSize,
          differentSettings,
        );
        
        // Should not use cache due to different settings
        expect(result.fromCache, isFalse);
        expect(result.bestCrop.isValid, isTrue);
      });
    });
    
    group('Error Recovery and Resilience', () {
      test('should recover from processing errors gracefully', () async {
        // Test with extreme settings that might cause issues
        final extremeSettings = CropSettings(
          aggressiveness: CropAggressiveness.aggressive,
          enableRuleOfThirds: true,
          enableEntropyAnalysis: true,
          enableEdgeDetection: true,
          enableCenterWeighting: true,
          maxProcessingTime: const Duration(milliseconds: 1), // Very short
        );
        
        final result = await SmartCropper.analyzeCrop(
          'extreme_settings_test',
          testImage,
          ui.Size(1080, 2400),
          extremeSettings,
        );
        
        // Should still produce a valid result (likely fallback)
        expect(result.bestCrop.isValid, isTrue);
      });
      
      test('should handle resource exhaustion scenarios', () async {
        // Create a very large image that might cause memory issues
        final largeImage = await _createTestImage(8192, 8192);
        
        try {
          final result = await SmartCropper.analyzeCrop(
            'large_image_test',
            largeImage,
            ui.Size(1080, 2400),
            CropSettings.defaultSettings,
          );
          
          // Should handle large images gracefully
          expect(result.bestCrop.isValid, isTrue);
        } finally {
          largeImage.dispose();
        }
      });
    });
    
    group('Production Monitoring', () {
      test('should provide comprehensive analytics', () async {
        // Perform various operations to generate metrics
        await SmartCropper.analyzeCrop(
          'analytics_test_1',
          testImage,
          ui.Size(1080, 2400),
          CropSettings.defaultSettings,
        );
        
        await SmartCropper.analyzeCrop(
          'analytics_test_2',
          testImage,
          ui.Size(1440, 2560),
          CropSettings.defaultSettings.copyWith(
            aggressiveness: CropAggressiveness.conservative,
          ),
        );
        
        final analytics = SmartCropper.getPerformanceAnalytics();
        
        // Verify analytics structure
        expect(analytics, isA<Map<String, dynamic>>());
        expect(analytics.containsKey('overall_stats'), isTrue);
        expect(analytics.containsKey('trends'), isTrue);
        expect(analytics.containsKey('memory_stats'), isTrue);
        expect(analytics.containsKey('cache_stats'), isTrue);
        expect(analytics.containsKey('operation_stats'), isTrue);
        
        final overallStats = analytics['overall_stats'];
        expect(overallStats['total_operations'], greaterThan(0));
        expect(overallStats['success_rate'], greaterThanOrEqualTo(0.0));
        expect(overallStats['success_rate'], lessThanOrEqualTo(1.0));
      });
      
      test('should track device capability information', () async {
        final deviceInfo = await SmartCropper.getDeviceCapabilityInfo();
        
        expect(deviceInfo, isA<Map<String, dynamic>>());
        expect(deviceInfo.containsKey('device_capability'), isTrue);
        expect(deviceInfo.containsKey('battery_optimization'), isTrue);
        expect(deviceInfo.containsKey('performance_constants'), isTrue);
        
        final deviceCapability = deviceInfo['device_capability'];
        expect(deviceCapability['platform'], isNotNull);
        expect(deviceCapability['overall_tier'], isNotNull);
        expect(deviceCapability['max_concurrent_analyzers'], greaterThan(0));
        expect(deviceCapability['max_image_dimension'], greaterThan(0));
        expect(deviceCapability['timeout_multiplier'], greaterThan(0));
      });
    });
  });
}

/// Creates a test image with realistic content for testing
Future<ui.Image> _createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create a realistic wallpaper-like image
  final paint = ui.Paint();
  
  // Background gradient
  for (int y = 0; y < height; y++) {
    final t = y / height;
    paint.color = ui.Color.lerp(
      const ui.Color(0xFF1E3A8A), // Blue
      const ui.Color(0xFF7C3AED), // Purple
      t,
    )!;
    
    canvas.drawRect(
      ui.Rect.fromLTWH(0, y.toDouble(), width.toDouble(), 1),
      paint,
    );
  }
  
  // Add some geometric shapes for content analysis
  paint.color = const ui.Color(0xFFFFFFFF);
  
  // Circle in upper third (rule of thirds intersection)
  canvas.drawCircle(
    ui.Offset(width * 0.33, height * 0.33),
    math.min(width, height) * 0.05,
    paint,
  );
  
  // Rectangle in lower third
  canvas.drawRect(
    ui.Rect.fromLTWH(
      width * 0.6,
      height * 0.7,
      width * 0.15,
      height * 0.1,
    ),
    paint,
  );
  
  // Add some texture for entropy analysis
  final random = math.Random(42); // Fixed seed for consistent tests
  paint.color = const ui.Color(0x40FFFFFF);
  
  for (int i = 0; i < 100; i++) {
    final x = random.nextDouble() * width;
    final y = random.nextDouble() * height;
    final size = random.nextDouble() * 10 + 2;
    
    canvas.drawCircle(ui.Offset(x, y), size, paint);
  }
  
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  
  return image;
}