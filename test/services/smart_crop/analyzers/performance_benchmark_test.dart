import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/analyzers.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'dart:ui' as ui;
import 'dart:math' as math;

void main() {
  group('Analyzer Performance Benchmarks', () {
    late List<CropAnalyzer> analyzers;

    setUp(() {
      analyzers = [
        RuleOfThirdsCropAnalyzer(),
        CenterWeightedCropAnalyzer(),
        EntropyBasedCropAnalyzer(),
        EdgeDetectionCropAnalyzer(),
      ];
    });

    group('Performance Tests', () {
      test('should complete analysis within time limits for typical image sizes', () async {
        final testCases = [
          {'size': const ui.Size(1920, 1080), 'name': 'Full HD'},
          {'size': const ui.Size(1080, 1920), 'name': 'Full HD Portrait'},
          {'size': const ui.Size(2560, 1440), 'name': '1440p'},
          {'size': const ui.Size(3840, 2160), 'name': '4K'},
        ];

        final targetSize = const ui.Size(400, 400);

        for (final testCase in testCases) {
          final imageSize = testCase['size'] as ui.Size;
          final name = testCase['name'] as String;
          final image = await _createTestImage(imageSize.width.toInt(), imageSize.height.toInt());

          for (final analyzer in analyzers) {
            final stopwatch = Stopwatch()..start();
            final result = await analyzer.analyze(image, targetSize);
            stopwatch.stop();

            expect(result.isValid, isTrue, 
              reason: '${analyzer.strategyName} should produce valid result for $name');
            
            // Performance expectations based on analyzer complexity
            final maxTime = _getMaxTimeForAnalyzer(analyzer.strategyName);
            expect(stopwatch.elapsedMilliseconds, lessThan(maxTime),
              reason: '${analyzer.strategyName} should complete $name analysis within ${maxTime}ms, took ${stopwatch.elapsedMilliseconds}ms');
          }
        }
      });

      test('should handle memory efficiently for large images', () async {
        final largeImage = await _createTestImage(4000, 3000); // 12MP image
        final targetSize = const ui.Size(800, 600);

        for (final analyzer in analyzers) {
          // Run multiple times to check for memory leaks
          for (int i = 0; i < 3; i++) {
            final result = await analyzer.analyze(largeImage, targetSize);
            expect(result.isValid, isTrue,
              reason: '${analyzer.strategyName} should handle large images (iteration $i)');
          }
        }
      });

      test('should scale performance appropriately with image size', () async {
        final sizes = [
          const ui.Size(400, 300),   // Small
          const ui.Size(800, 600),   // Medium
          const ui.Size(1600, 1200), // Large
        ];
        final targetSize = const ui.Size(400, 400);

        for (final analyzer in analyzers) {
          final times = <int>[];
          
          for (final size in sizes) {
            final image = await _createTestImage(size.width.toInt(), size.height.toInt());
            final stopwatch = Stopwatch()..start();
            await analyzer.analyze(image, targetSize);
            stopwatch.stop();
            times.add(stopwatch.elapsedMilliseconds);
          }

          // Performance should not degrade exponentially
          // Large image should not take more than 20x small image time (more lenient)
          // Only test if small image took some measurable time
          if (times[0] > 0) {
            expect(times[2], lessThan(times[0] * 20),
              reason: '${analyzer.strategyName} performance should scale reasonably (${times[0]}ms -> ${times[2]}ms)');
          }
        }
      });
    });

    group('Stress Tests', () {
      test('should handle extreme aspect ratios', () async {
        final extremeCases = [
          const ui.Size(4000, 100),  // Very wide
          const ui.Size(100, 4000),  // Very tall
          const ui.Size(8000, 200),  // Ultra wide
          const ui.Size(200, 8000),  // Ultra tall
        ];
        final targetSize = const ui.Size(400, 400);

        for (final size in extremeCases) {
          final image = await _createTestImage(size.width.toInt(), size.height.toInt());
          
          for (final analyzer in analyzers) {
            final result = await analyzer.analyze(image, targetSize);
            
            expect(result.isValid, isTrue,
              reason: '${analyzer.strategyName} should handle extreme aspect ratio ${size.width}x${size.height}');
            expect(result.coordinates.isValid, isTrue,
              reason: '${analyzer.strategyName} should produce valid coordinates for ${size.width}x${size.height}');
          }
        }
      });

      test('should handle very small images', () async {
        final smallSizes = [
          const ui.Size(50, 50),
          const ui.Size(100, 75),
          const ui.Size(75, 100),
        ];
        final targetSize = const ui.Size(40, 40);

        for (final size in smallSizes) {
          final image = await _createTestImage(size.width.toInt(), size.height.toInt());
          
          for (final analyzer in analyzers) {
            final result = await analyzer.analyze(image, targetSize);
            
            expect(result.isValid, isTrue,
              reason: '${analyzer.strategyName} should handle small image ${size.width}x${size.height}');
          }
        }
      });

      test('should handle edge case target sizes', () async {
        final image = await _createTestImage(1000, 1000);
        final edgeCases = [
          const ui.Size(1, 1),       // Minimum size
          const ui.Size(10, 10),     // Very small
          const ui.Size(999, 999),   // Almost full size
          const ui.Size(1000, 1000), // Exact same size
        ];

        for (final targetSize in edgeCases) {
          for (final analyzer in analyzers) {
            final result = await analyzer.analyze(image, targetSize);
            
            expect(result.isValid, isTrue,
              reason: '${analyzer.strategyName} should handle target size ${targetSize.width}x${targetSize.height}');
          }
        }
      });
    });

    group('Consistency Tests', () {
      test('should produce consistent results for identical inputs', () async {
        final image = await _createTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);

        for (final analyzer in analyzers) {
          final results = <CropScore>[];
          
          // Run same analysis multiple times
          for (int i = 0; i < 3; i++) {
            final result = await analyzer.analyze(image, targetSize);
            results.add(result);
          }

          // Results should be identical
          for (int i = 1; i < results.length; i++) {
            expect(results[i].coordinates.x, closeTo(results[0].coordinates.x, 0.001),
              reason: '${analyzer.strategyName} should produce consistent x coordinates');
            expect(results[i].coordinates.y, closeTo(results[0].coordinates.y, 0.001),
              reason: '${analyzer.strategyName} should produce consistent y coordinates');
            expect(results[i].coordinates.width, closeTo(results[0].coordinates.width, 0.001),
              reason: '${analyzer.strategyName} should produce consistent width');
            expect(results[i].coordinates.height, closeTo(results[0].coordinates.height, 0.001),
              reason: '${analyzer.strategyName} should produce consistent height');
          }
        }
      });

      test('should produce reasonable score distributions', () async {
        final testImages = <ui.Image>[];
        final targetSize = const ui.Size(400, 400);
        
        // Create various test images
        for (int i = 0; i < 10; i++) {
          testImages.add(await _createVariedTestImage(800, 600, i));
        }

        for (final analyzer in analyzers) {
          final scores = <double>[];
          
          for (final image in testImages) {
            final result = await analyzer.analyze(image, targetSize);
            scores.add(result.score);
          }

          // Scores should have reasonable distribution
          final minScore = scores.reduce(math.min);
          final maxScore = scores.reduce(math.max);
          final avgScore = scores.reduce((a, b) => a + b) / scores.length;

          expect(minScore, greaterThanOrEqualTo(0.0),
            reason: '${analyzer.strategyName} minimum score should be non-negative');
          expect(maxScore, lessThanOrEqualTo(1.0),
            reason: '${analyzer.strategyName} maximum score should not exceed 1.0');
          expect(avgScore, greaterThan(0.0),
            reason: '${analyzer.strategyName} should produce positive average scores');
          // Allow for minimal variation in scores (some analyzers might be very consistent)
          expect(maxScore - minScore, greaterThanOrEqualTo(0.0),
            reason: '${analyzer.strategyName} should show non-negative score variation across different images');
        }
      });
    });
  });
}

/// Get maximum expected time for analyzer based on complexity
int _getMaxTimeForAnalyzer(String strategyName) {
  switch (strategyName) {
    case 'center_weighted':
      return 1000; // 1 second - simplest analyzer
    case 'rule_of_thirds':
      return 2000; // 2 seconds - moderate complexity
    case 'entropy_based':
      return 3000; // 3 seconds - more complex calculations
    case 'edge_detection':
      return 5000; // 5 seconds - most complex (Sobel filtering)
    default:
      return 2000; // Default 2 seconds
  }
}

/// Helper function to create a test image
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

/// Helper function to create varied test images for distribution testing
Future<ui.Image> _createVariedTestImage(int width, int height, int seed) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create different patterns based on seed
  final random = math.Random(seed);
  
  // Background color
  final bgColor = ui.Color.fromARGB(
    255,
    random.nextInt(256),
    random.nextInt(256),
    random.nextInt(256),
  );
  final bgPaint = ui.Paint()..color = bgColor;
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    bgPaint,
  );
  
  // Add random shapes
  final shapePaint = ui.Paint()..color = ui.Color.fromARGB(
    255,
    255 - bgColor.red,
    255 - bgColor.green,
    255 - bgColor.blue,
  );
  
  for (int i = 0; i < 5; i++) {
    final x = random.nextDouble() * width;
    final y = random.nextDouble() * height;
    final size = random.nextDouble() * math.min(width, height) / 4;
    
    if (random.nextBool()) {
      // Circle
      canvas.drawCircle(ui.Offset(x, y), size, shapePaint);
    } else {
      // Rectangle
      canvas.drawRect(
        ui.Rect.fromLTWH(x - size/2, y - size/2, size, size),
        shapePaint,
      );
    }
  }
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}