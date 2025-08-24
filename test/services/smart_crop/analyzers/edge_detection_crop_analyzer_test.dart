import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/edge_detection_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  group('EdgeDetectionCropAnalyzer', () {
    late EdgeDetectionCropAnalyzer analyzer;

    setUp(() {
      analyzer = EdgeDetectionCropAnalyzer();
    });

    group('Basic Properties', () {
      test('should have correct strategy name', () {
        expect(analyzer.strategyName, equals('edge_detection'));
      });

      test('should have appropriate weight', () {
        expect(analyzer.weight, equals(0.65));
        expect(analyzer.weight, greaterThan(0.0));
        expect(analyzer.weight, lessThanOrEqualTo(1.0));
      });

      test('should be disabled by default (CPU intensive)', () {
        expect(analyzer.isEnabledByDefault, isFalse);
      });

      test('should have reasonable confidence threshold', () {
        expect(analyzer.minConfidenceThreshold, equals(0.1));
        expect(analyzer.minConfidenceThreshold, greaterThanOrEqualTo(0.0));
        expect(analyzer.minConfidenceThreshold, lessThanOrEqualTo(1.0));
      });
    });

    group('Crop Analysis', () {
      test('should analyze square image for portrait target', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(400, 600); // Portrait 2:3 ratio
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result, isA<CropScore>());
        expect(result.strategy, equals('edge_detection'));
        expect(result.score, greaterThanOrEqualTo(0.0));
        expect(result.score, lessThanOrEqualTo(1.0));
        expect(result.coordinates.isValid, isTrue);
        expect(result.isValid, isTrue);
      });

      test('should analyze landscape image for square target', () async {
        final image = await _createTestImage(1600, 900);
        final targetSize = const ui.Size(500, 500); // Square 1:1 ratio
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThan(0.0));
        
        // For landscape to square, should crop from sides
        expect(result.coordinates.width, lessThan(1.0));
        expect(result.coordinates.height, equals(1.0));
      });

      test('should analyze portrait image for landscape target', () async {
        final image = await _createTestImage(600, 1000);
        final targetSize = const ui.Size(800, 450); // Landscape 16:9 ratio
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThan(0.0));
        
        // For portrait to landscape, should crop from top/bottom
        expect(result.coordinates.width, equals(1.0));
        expect(result.coordinates.height, lessThan(1.0));
      });
    });

    group('Edge Detection', () {
      test('should include edge strength metrics', () async {
        final image = await _createEdgeTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('average_edge_strength'), isTrue);
        expect(result.metrics['average_edge_strength'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['average_edge_strength'], lessThanOrEqualTo(1.0));
      });

      test('should include edge distribution metrics', () async {
        final image = await _createEdgeTestImage(1000, 800);
        final targetSize = const ui.Size(500, 500);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('edge_distribution'), isTrue);
        expect(result.metrics['edge_distribution'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['edge_distribution'], lessThanOrEqualTo(1.0));
      });

      test('should include strong edge ratio metrics', () async {
        final image = await _createHighContrastTestImage(1200, 900);
        final targetSize = const ui.Size(600, 600);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('strong_edge_ratio'), isTrue);
        expect(result.metrics['strong_edge_ratio'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['strong_edge_ratio'], lessThanOrEqualTo(1.0));
      });

      test('should detect edges in high-contrast images', () async {
        final image = await _createHighContrastTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        // High contrast image should have some edge content
        expect(result.metrics['average_edge_strength'], greaterThanOrEqualTo(0.0));
        expect(result.score, greaterThan(0.0));
      });
    });

    group('Feature Detection', () {
      test('should prefer areas with strong edges', () async {
        final image = await _createShapeTestImage(1000, 800);
        final targetSize = const ui.Size(600, 600);
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Image with geometric shapes should have decent edge scores
        expect(result.metrics['average_edge_strength'], greaterThanOrEqualTo(0.0));
        expect(result.score, greaterThan(0.0));
      });

      test('should handle images with few edges gracefully', () async {
        final image = await _createSmoothTestImage(1000, 1000);
        final targetSize = const ui.Size(500, 500);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.0));
        
        // Smooth image should have low edge scores but still produce valid crop
        expect(result.metrics['average_edge_strength'], lessThan(0.5));
      });

      test('should calculate crop area ratio correctly', () async {
        final image = await _createTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        final expectedRatio = result.coordinates.width * result.coordinates.height;
        expect(result.metrics['crop_area_ratio'], equals(expectedRatio));
        expect(result.metrics['crop_area_ratio'], lessThanOrEqualTo(1.0));
      });
    });

    group('Edge Cases', () {
      test('should handle very wide images', () async {
        final image = await _createTestImage(2000, 500); // 4:1 ratio
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThan(0.0));
        expect(result.coordinates.height, equals(1.0)); // Should use full height
      });

      test('should handle very tall images', () async {
        final image = await _createTestImage(500, 2000); // 1:4 ratio
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThan(0.0));
        expect(result.coordinates.width, equals(1.0)); // Should use full width
      });

      test('should handle same aspect ratio', () async {
        final image = await _createTestImage(800, 600); // 4:3 ratio
        final targetSize = const ui.Size(400, 300); // Same 4:3 ratio
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.coordinates.width, equals(1.0));
        expect(result.coordinates.height, equals(1.0));
        expect(result.coordinates.x, equals(0.0));
        expect(result.coordinates.y, equals(0.0));
      });

      test('should handle very small target sizes', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(50, 50);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThan(0.0));
      });

      test('should handle small images', () async {
        final image = await _createTestImage(100, 100);
        final targetSize = const ui.Size(80, 80);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.0));
      });
    });

    group('Performance and Robustness', () {
      test('should complete analysis within reasonable time', () async {
        final image = await _createEdgeTestImage(1000, 800);
        final targetSize = const ui.Size(500, 500);
        
        final stopwatch = Stopwatch()..start();
        final result = await analyzer.analyze(image, targetSize);
        stopwatch.stop();
        
        expect(result.coordinates.isValid, isTrue);
        expect(stopwatch.elapsedMilliseconds, lessThan(10000)); // Should complete within 10 seconds
      });

      test('should handle edge coordinates correctly', () async {
        final image = await _createTestImage(400, 300);
        final targetSize = const ui.Size(350, 250); // Large crop
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.coordinates.x, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.y, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.x + result.coordinates.width, lessThanOrEqualTo(1.0));
        expect(result.coordinates.y + result.coordinates.height, lessThanOrEqualTo(1.0));
      });
    });

    group('Metrics Validation', () {
      test('should provide comprehensive metrics', () async {
        final image = await _createEdgeTestImage(1000, 800);
        final targetSize = const ui.Size(500, 500);
        
        final result = await analyzer.analyze(image, targetSize);
        
        final expectedMetrics = [
          'average_edge_strength',
          'edge_distribution',
          'strong_edge_ratio',
          'crop_area_ratio',
          'center_distance',
        ];
        
        for (final metric in expectedMetrics) {
          expect(result.metrics.containsKey(metric), isTrue,
            reason: 'Should include $metric in metrics');
          expect(result.metrics[metric], greaterThanOrEqualTo(0.0),
            reason: '$metric should be non-negative');
        }
      });

      test('should calculate center distance correctly', () async {
        final image = await _createTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        final centerX = result.coordinates.x + result.coordinates.width / 2;
        final centerY = result.coordinates.y + result.coordinates.height / 2;
        final expectedDistance = math.sqrt((centerX - 0.5) * (centerX - 0.5) + 
                                          (centerY - 0.5) * (centerY - 0.5));
        
        expect(result.metrics['center_distance'], closeTo(expectedDistance, 0.001));
      });

      test('should return valid scores for all test cases', () async {
        final testCases = [
          {'imageSize': const ui.Size(1920, 1080), 'targetSize': const ui.Size(400, 400)},
          {'imageSize': const ui.Size(800, 1200), 'targetSize': const ui.Size(300, 400)},
          {'imageSize': const ui.Size(1000, 1000), 'targetSize': const ui.Size(500, 300)},
        ];
        
        for (final testCase in testCases) {
          final imageSize = testCase['imageSize'] as ui.Size;
          final targetSize = testCase['targetSize'] as ui.Size;
          final image = await _createTestImage(imageSize.width.toInt(), imageSize.height.toInt());
          
          final result = await analyzer.analyze(image, targetSize);
          
          expect(result.isValid, isTrue,
            reason: 'Result should be valid for image ${imageSize} -> target ${targetSize}');
          expect(result.score, greaterThan(0.0),
            reason: 'Score should be positive for image ${imageSize} -> target ${targetSize}');
        }
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

/// Helper function to create an image with strong edges
Future<ui.Image> _createEdgeTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create background
  final bgPaint = ui.Paint()..color = const ui.Color(0xFF808080);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    bgPaint,
  );
  
  // Add rectangles with strong edges
  final edgePaint = ui.Paint()..color = const ui.Color(0xFF000000);
  
  // Vertical rectangles
  for (int i = 0; i < 3; i++) {
    canvas.drawRect(
      ui.Rect.fromLTWH(
        (i + 1) * width / 4,
        height / 4,
        width / 8,
        height / 2,
      ),
      edgePaint,
    );
  }
  
  // Horizontal rectangles
  for (int i = 0; i < 2; i++) {
    canvas.drawRect(
      ui.Rect.fromLTWH(
        width / 6,
        (i + 1) * height / 3,
        width * 2 / 3,
        height / 12,
      ),
      edgePaint,
    );
  }
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Helper function to create a high contrast test image
Future<ui.Image> _createHighContrastTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create checkerboard pattern for high contrast edges
  final blackPaint = ui.Paint()..color = const ui.Color(0xFF000000);
  final whitePaint = ui.Paint()..color = const ui.Color(0xFFFFFFFF);
  
  final tileSize = math.min(width, height) / 12;
  
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

/// Helper function to create an image with geometric shapes (strong edges)
Future<ui.Image> _createShapeTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create background
  final bgPaint = ui.Paint()..color = const ui.Color(0xFFCCCCCC);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    bgPaint,
  );
  
  // Add geometric shapes with strong edges
  final shapePaint = ui.Paint()..color = const ui.Color(0xFF000000);
  
  // Circles
  for (int i = 0; i < 3; i++) {
    canvas.drawCircle(
      ui.Offset(
        (i + 1) * width / 4,
        height / 3,
      ),
      width / 12,
      shapePaint,
    );
  }
  
  // Triangles (using paths)
  for (int i = 0; i < 2; i++) {
    final path = ui.Path();
    final centerX = (i + 1) * width / 3;
    final centerY = height * 2 / 3;
    final size = width / 10;
    
    path.moveTo(centerX, centerY - size);
    path.lineTo(centerX - size, centerY + size);
    path.lineTo(centerX + size, centerY + size);
    path.close();
    
    canvas.drawPath(path, shapePaint);
  }
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Helper function to create a smooth test image (few edges)
Future<ui.Image> _createSmoothTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create smooth radial gradient (minimal edges)
  final paint = ui.Paint()
    ..shader = ui.Gradient.radial(
      ui.Offset(width / 2, height / 2),
      math.min(width, height) / 2,
      [
        const ui.Color(0xFF4080FF),
        const ui.Color(0xFF8040FF),
        const ui.Color(0xFF4080FF),
      ],
      [0.0, 0.5, 1.0],
    );
  
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}