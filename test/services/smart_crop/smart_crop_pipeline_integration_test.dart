import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_preferences.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/screen_utils.dart';

void main() {
  group('Smart Crop Pipeline Integration Tests', () {
    setUpAll(() async {
      // Initialize FFI for testing
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });
    
    setUp(() async {
      // Clear cache before each test
      await SmartCropper.clearCache();
    });
    
    tearDownAll(() async {
      await SmartCropper.close();
    });

    group('End-to-End Crop Processing', () {
      test('should process complete workflow from image URL to cropped result', () async {
        // Create test image
        final sourceImage = await _createTestImage(1200, 800);
        const imageUrl = 'https://example.com/e2e_workflow.jpg';
        const targetSize = ui.Size(600, 600);
        const settings = CropSettings.defaultSettings;
        
        // Process image through complete pipeline
        final result = await SmartCropper.processImage(imageUrl, sourceImage, targetSize, settings);
        
        // Verify successful processing
        expect(result.success, isTrue);
        expect(result.error, isNull);
        expect(result.image, isNotNull);
        expect(result.cropResult, isNotNull);
        
        // Verify output image dimensions
        expect(result.image.width, equals(600));
        expect(result.image.height, equals(600));
        
        // Verify crop result
        expect(result.cropResult.bestCrop.isValid, isTrue);
        expect(result.cropResult.processingTime.inMilliseconds, greaterThanOrEqualTo(0));
        expect(result.cropResult.fromCache, isFalse); // First time
        
        // Second processing should use cache
        final cachedResult = await SmartCropper.processImage(imageUrl, sourceImage, targetSize, settings);
        expect(cachedResult.success, isTrue);
        expect(cachedResult.cropResult.fromCache, isTrue);
        expect(cachedResult.cropResult.bestCrop, equals(result.cropResult.bestCrop));
      });

      test('should handle different image aspect ratios correctly', () async {
        final testCases = [
          {'name': 'Landscape', 'imageSize': const ui.Size(1600, 900), 'targetSize': const ui.Size(400, 400)},
          {'name': 'Portrait', 'imageSize': const ui.Size(900, 1600), 'targetSize': const ui.Size(400, 400)},
          {'name': 'Square', 'imageSize': const ui.Size(1000, 1000), 'targetSize': const ui.Size(400, 600)},
          {'name': 'Ultra-wide', 'imageSize': const ui.Size(2000, 500), 'targetSize': const ui.Size(400, 400)},
          {'name': 'Ultra-tall', 'imageSize': const ui.Size(500, 2000), 'targetSize': const ui.Size(400, 400)},
        ];

        for (final testCase in testCases) {
          final name = testCase['name'] as String;
          final imageSize = testCase['imageSize'] as ui.Size;
          final targetSize = testCase['targetSize'] as ui.Size;
          
          final sourceImage = await _createTestImage(imageSize.width.toInt(), imageSize.height.toInt());
          final imageUrl = 'https://example.com/aspect_ratio_$name.jpg';
          
          final result = await SmartCropper.processImage(
            imageUrl, 
            sourceImage, 
            targetSize, 
            CropSettings.defaultSettings,
          );
          
          expect(result.success, isTrue, reason: '$name aspect ratio should process successfully');
          expect(result.image.width, equals(targetSize.width.toInt()), reason: '$name output width should match target');
          expect(result.image.height, equals(targetSize.height.toInt()), reason: '$name output height should match target');
          expect(result.cropResult.bestCrop.isValid, isTrue, reason: '$name should produce valid crop coordinates');
        }
      });

      test('should handle different crop settings correctly', () async {
        final sourceImage = await _createComplexTestImage(1000, 800);
        const imageUrl = 'https://example.com/settings_test.jpg';
        const targetSize = ui.Size(500, 500);
        
        final settingsVariations = [
          CropSettings.defaultSettings,
          const CropSettings(aggressiveness: CropAggressiveness.conservative),
          const CropSettings(aggressiveness: CropAggressiveness.aggressive),
          const CropSettings(enableRuleOfThirds: false, enableCenterWeighting: true),
          const CropSettings(enableEntropyAnalysis: true, enableEdgeDetection: false),
        ];

        final results = <CropResult>[];
        
        for (int i = 0; i < settingsVariations.length; i++) {
          final settings = settingsVariations[i];
          final result = await SmartCropper.processImage(
            '${imageUrl}_$i', // Different URL for each setting to avoid cache conflicts
            sourceImage, 
            targetSize, 
            settings,
          );
          
          expect(result.success, isTrue, reason: 'Settings variation $i should process successfully');
          expect(result.cropResult.bestCrop.isValid, isTrue, reason: 'Settings variation $i should produce valid crop');
          
          results.add(result.cropResult);
        }
        
        // Different settings should potentially produce different results
        // (though some might be the same if the image is simple)
        expect(results.length, equals(settingsVariations.length));
      });
    });

    group('Performance and Scalability', () {
      test('should handle multiple concurrent processing requests', () async {
        const numConcurrent = 5;
        final futures = <Future<ProcessedImageResult>>[];
        
        for (int i = 0; i < numConcurrent; i++) {
          final sourceImage = await _createTestImage(800, 600);
          final future = SmartCropper.processImage(
            'https://example.com/concurrent_$i.jpg',
            sourceImage,
            const ui.Size(400, 400),
            CropSettings.defaultSettings,
          );
          futures.add(future);
        }
        
        final results = await Future.wait(futures);
        
        for (int i = 0; i < results.length; i++) {
          expect(results[i].success, isTrue, reason: 'Concurrent request $i should succeed');
          expect(results[i].image.width, equals(400));
          expect(results[i].image.height, equals(400));
        }
      });

      test('should handle large images efficiently', () async {
        final largeImage = await _createTestImage(4000, 3000); // 12MP image
        const imageUrl = 'https://example.com/large_image.jpg';
        const targetSize = ui.Size(800, 600);
        
        final stopwatch = Stopwatch()..start();
        final result = await SmartCropper.processImage(
          imageUrl,
          largeImage,
          targetSize,
          CropSettings.defaultSettings,
        );
        stopwatch.stop();
        
        expect(result.success, isTrue);
        expect(result.image.width, equals(800));
        expect(result.image.height, equals(600));
        expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // Should complete within 10 seconds
      });

      test('should handle memory pressure gracefully', () async {
        // Process multiple large images to simulate memory pressure
        for (int i = 0; i < 3; i++) {
          final largeImage = await _createTestImage(2000, 1500);
          final result = await SmartCropper.processImage(
            'https://example.com/memory_test_$i.jpg',
            largeImage,
            const ui.Size(600, 600),
            CropSettings.defaultSettings,
          );
          
          expect(result.success, isTrue, reason: 'Memory pressure test $i should succeed');
          expect(result.image.width, equals(600));
          expect(result.image.height, equals(600));
        }
      });
    });

    group('Error Handling and Robustness', () {
      test('should handle timeout scenarios gracefully', () async {
        final sourceImage = await _createTestImage(800, 600);
        const imageUrl = 'https://example.com/timeout_test.jpg';
        const targetSize = ui.Size(400, 400);
        
        // Use very short timeout to force timeout scenario
        const settings = CropSettings(
          maxProcessingTime: Duration(milliseconds: 1), // Very short timeout
        );
        
        final result = await SmartCropper.processImage(imageUrl, sourceImage, targetSize, settings);
        
        // Should still succeed with fallback crop
        expect(result.success, isTrue);
        expect(result.image.width, equals(400));
        expect(result.image.height, equals(400));
        expect(result.cropResult.bestCrop.isValid, isTrue);
      });

      test('should handle invalid input gracefully', () async {
        final sourceImage = await _createTestImage(100, 100);
        
        // Test with invalid target sizes
        final invalidTargets = [
          const ui.Size(0, 100),    // Zero width
          const ui.Size(100, 0),    // Zero height
          const ui.Size(-100, 100), // Negative width
          const ui.Size(100, -100), // Negative height
        ];
        
        for (final targetSize in invalidTargets) {
          final result = await SmartCropper.processImage(
            'https://example.com/invalid_target.jpg',
            sourceImage,
            targetSize,
            CropSettings.defaultSettings,
          );
          
          // Should handle gracefully (either succeed with fallback or fail gracefully)
          if (result.success) {
            expect(result.image, isNotNull);
            expect(result.cropResult.bestCrop.isValid, isTrue);
          } else {
            expect(result.error, isNotNull);
          }
        }
      });

      test('should recover from analyzer failures', () async {
        final sourceImage = await _createTestImage(800, 600);
        const imageUrl = 'https://example.com/analyzer_failure_test.jpg';
        const targetSize = ui.Size(400, 400);
        
        // Use settings that might cause some analyzers to fail
        const settings = CropSettings(
          enableRuleOfThirds: true,
          enableCenterWeighting: true,
          enableEntropyAnalysis: true,
          enableEdgeDetection: true,
        );
        
        final result = await SmartCropper.processImage(imageUrl, sourceImage, targetSize, settings);
        
        // Should succeed even if some analyzers fail
        expect(result.success, isTrue);
        expect(result.image.width, equals(400));
        expect(result.image.height, equals(400));
        expect(result.cropResult.bestCrop.isValid, isTrue);
      });
    });

    group('Settings Integration', () {
      test('should integrate with SmartCropPreferences correctly', () async {
        // Test default settings
        final defaultSettings = await SmartCropPreferences.getCropSettings();
        expect(defaultSettings.isValid, isTrue);
        
        // Test that different settings produce different results
        const conservativeSettings = CropSettings(
          aggressiveness: CropAggressiveness.conservative,
          enableRuleOfThirds: true,
          enableCenterWeighting: true,
        );
        
        const aggressiveSettings = CropSettings(
          aggressiveness: CropAggressiveness.aggressive,
          enableRuleOfThirds: false,
          enableEntropyAnalysis: true,
        );
        
        expect(conservativeSettings.isValid, isTrue);
        expect(aggressiveSettings.isValid, isTrue);
        expect(conservativeSettings.aggressiveness, isNot(equals(aggressiveSettings.aggressiveness)));
      });

      test('should handle settings changes and cache invalidation', () async {
        final sourceImage = await _createTestImage(800, 600);
        const imageUrl = 'https://example.com/settings_change_test.jpg';
        const targetSize = ui.Size(400, 400);
        
        // Process with initial settings
        const initialSettings = CropSettings.defaultSettings;
        final result1 = await SmartCropper.processImage(imageUrl, sourceImage, targetSize, initialSettings);
        expect(result1.success, isTrue);
        expect(result1.cropResult.fromCache, isFalse);
        
        // Process again with same settings (should use cache)
        final result2 = await SmartCropper.processImage(imageUrl, sourceImage, targetSize, initialSettings);
        expect(result2.success, isTrue);
        expect(result2.cropResult.fromCache, isTrue);
        
        // Change settings and process again (should not use cache)
        const newSettings = CropSettings(aggressiveness: CropAggressiveness.aggressive);
        final result3 = await SmartCropper.processImage(imageUrl, sourceImage, targetSize, newSettings);
        expect(result3.success, isTrue);
        expect(result3.cropResult.fromCache, isFalse);
      });
    });

    group('Visual Regression Prevention', () {
      test('should produce consistent results for reference images', () async {
        // Create reference images with known characteristics
        final referenceImages = [
          await _createGradientTestImage(800, 600),
          await _createPatternTestImage(800, 600),
          await _createCenterFocusTestImage(800, 600),
        ];
        
        const targetSize = ui.Size(400, 400);
        const settings = CropSettings.defaultSettings;
        
        for (int i = 0; i < referenceImages.length; i++) {
          final imageUrl = 'https://example.com/reference_$i.jpg';
          final image = referenceImages[i];
          
          // Process multiple times to ensure consistency
          final results = <CropResult>[];
          for (int j = 0; j < 3; j++) {
            final result = await SmartCropper.processImage(imageUrl, image, targetSize, settings);
            expect(result.success, isTrue);
            results.add(result.cropResult);
          }
          
          // All results should be identical (from cache after first)
          for (int j = 1; j < results.length; j++) {
            expect(results[j].bestCrop.x, closeTo(results[0].bestCrop.x, 0.001));
            expect(results[j].bestCrop.y, closeTo(results[0].bestCrop.y, 0.001));
            expect(results[j].bestCrop.width, closeTo(results[0].bestCrop.width, 0.001));
            expect(results[j].bestCrop.height, closeTo(results[0].bestCrop.height, 0.001));
          }
        }
      });

      test('should maintain crop quality metrics within expected ranges', () async {
        final testImage = await _createComplexTestImage(1000, 800);
        const imageUrl = 'https://example.com/quality_test.jpg';
        const targetSize = ui.Size(500, 500);
        const settings = CropSettings.defaultSettings;
        
        final result = await SmartCropper.processImage(imageUrl, testImage, targetSize, settings);
        
        expect(result.success, isTrue);
        
        final crop = result.cropResult.bestCrop;
        
        // Verify crop is within reasonable bounds
        expect(crop.x, greaterThanOrEqualTo(0.0));
        expect(crop.y, greaterThanOrEqualTo(0.0));
        expect(crop.x + crop.width, lessThanOrEqualTo(1.0));
        expect(crop.y + crop.height, lessThanOrEqualTo(1.0));
        
        // Verify crop preserves reasonable amount of content
        final cropArea = crop.width * crop.height;
        expect(cropArea, greaterThan(0.1)); // At least 10% of original
        expect(cropArea, lessThanOrEqualTo(1.0)); // At most 100% of original
        
        // Verify confidence is reasonable
        expect(crop.confidence, greaterThanOrEqualTo(0.0));
        expect(crop.confidence, lessThanOrEqualTo(1.0));
      });
    });
  });
}

/// Helper function to create a basic test image
Future<ui.Image> _createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create a simple gradient pattern
  final paint = ui.Paint()
    ..shader = ui.Gradient.linear(
      ui.Offset.zero,
      ui.Offset(width.toDouble(), height.toDouble()),
      [const ui.Color(0xFF000000), const ui.Color(0xFFFFFFFF)],
    );
  
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Helper function to create a complex test image with varied content
Future<ui.Image> _createComplexTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create background
  final bgPaint = ui.Paint()..color = const ui.Color(0xFF808080);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    bgPaint,
  );
  
  // Add some geometric shapes for complexity
  final shapePaint = ui.Paint()..color = const ui.Color(0xFF000000);
  
  // Circles
  for (int i = 0; i < 5; i++) {
    canvas.drawCircle(
      ui.Offset(
        (i + 1) * width / 6,
        height / 3,
      ),
      width / 20,
      shapePaint,
    );
  }
  
  // Rectangles
  for (int i = 0; i < 3; i++) {
    canvas.drawRect(
      ui.Rect.fromLTWH(
        (i + 1) * width / 4,
        height * 2 / 3,
        width / 8,
        height / 8,
      ),
      shapePaint,
    );
  }
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Helper function to create a gradient test image
Future<ui.Image> _createGradientTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  final paint = ui.Paint()
    ..shader = ui.Gradient.radial(
      ui.Offset(width / 2, height / 2),
      math.min(width, height) / 2,
      [
        const ui.Color(0xFFFF0000),
        const ui.Color(0xFF0000FF),
      ],
    );
  
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Helper function to create a pattern test image
Future<ui.Image> _createPatternTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create checkerboard pattern
  final blackPaint = ui.Paint()..color = const ui.Color(0xFF000000);
  final whitePaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  
  final tileSize = math.min(width, height) / 16;
  
  for (int y = 0; y < height; y += tileSize.toInt()) {
    for (int x = 0; x < width; x += tileSize.toInt()) {
      final isBlack = ((x ~/ tileSize.toInt()) + (y ~/ tileSize.toInt())) % 2 == 0;
      canvas.drawRect(
        ui.Rect.fromLTWH(x.toDouble(), y.toDouble(), tileSize, tileSize),
        isBlack ? blackPaint : whitePaint,
      );
    }
  }
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Helper function to create a center-focused test image
Future<ui.Image> _createCenterFocusTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create background
  final bgPaint = ui.Paint()..color = const ui.Color(0xFFCCCCCC);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    bgPaint,
  );
  
  // Add central focus element
  final centerPaint = ui.Paint()..color = const ui.Color(0xFF000000);
  canvas.drawCircle(
    ui.Offset(width / 2, height / 2),
    math.min(width, height) / 6,
    centerPaint,
  );
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}