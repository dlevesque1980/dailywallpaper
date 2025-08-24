import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/rule_of_thirds_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  group('RuleOfThirdsCropAnalyzer', () {
    late RuleOfThirdsCropAnalyzer analyzer;

    setUp(() {
      analyzer = RuleOfThirdsCropAnalyzer();
    });

    group('Basic Properties', () {
      test('should have correct strategy name', () {
        expect(analyzer.strategyName, equals('rule_of_thirds'));
      });

      test('should have appropriate weight', () {
        expect(analyzer.weight, equals(0.8));
        expect(analyzer.weight, greaterThan(0.0));
        expect(analyzer.weight, lessThanOrEqualTo(1.0));
      });

      test('should be enabled by default', () {
        expect(analyzer.isEnabledByDefault, isTrue);
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
        expect(result.strategy, equals('rule_of_thirds'));
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

    group('Rule of Thirds Grid Calculations', () {
      test('should prefer crops aligned with intersection points', () async {
        final image = await _createTestImage(1200, 800);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Check if crop center is near a rule of thirds intersection
        final centerX = result.coordinates.x + result.coordinates.width / 2;
        final centerY = result.coordinates.y + result.coordinates.height / 2;
        
        final intersections = [
          const ui.Offset(1/3, 1/3),
          const ui.Offset(2/3, 1/3),
          const ui.Offset(1/3, 2/3),
          const ui.Offset(2/3, 2/3),
          const ui.Offset(0.5, 0.5), // Center as fallback
        ];
        
        bool nearIntersection = false;
        for (final intersection in intersections) {
          final distance = (centerX - intersection.dx).abs() + (centerY - intersection.dy).abs();
          if (distance < 0.2) { // Within reasonable tolerance
            nearIntersection = true;
            break;
          }
        }
        
        expect(nearIntersection, isTrue, 
          reason: 'Crop center ($centerX, $centerY) should be near a rule of thirds intersection');
      });

      test('should include intersection alignment in metrics', () async {
        final image = await _createTestImage(900, 600);
        final targetSize = const ui.Size(300, 300);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('intersection_alignment'), isTrue);
        expect(result.metrics['intersection_alignment'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['intersection_alignment'], lessThanOrEqualTo(1.0));
      });

      test('should include grid line alignment in metrics', () async {
        final image = await _createTestImage(1200, 900);
        final targetSize = const ui.Size(400, 300);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('grid_line_alignment'), isTrue);
        expect(result.metrics['grid_line_alignment'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['grid_line_alignment'], lessThanOrEqualTo(1.0));
      });
    });

    group('Content Distribution Scoring', () {
      test('should include content distribution metrics', () async {
        final image = await _createTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('content_distribution'), isTrue);
        expect(result.metrics['content_distribution'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['content_distribution'], lessThanOrEqualTo(1.0));
      });

      test('should penalize crops too close to edges', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(800, 800); // Large crop but not maximum
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Should prefer center crop over edge crop for large targets
        // For same aspect ratio, coordinates should be centered
        expect(result.coordinates.x, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.y, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.x + result.coordinates.width, lessThanOrEqualTo(1.0));
        expect(result.coordinates.y + result.coordinates.height, lessThanOrEqualTo(1.0));
        
        // The crop should be reasonably centered (not at extreme edges)
        final centerX = result.coordinates.x + result.coordinates.width / 2;
        final centerY = result.coordinates.y + result.coordinates.height / 2;
        expect(centerX, closeTo(0.5, 0.3)); // Within 30% of center
        expect(centerY, closeTo(0.5, 0.3)); // Within 30% of center
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
    });

    group('Metrics Validation', () {
      test('should provide comprehensive metrics', () async {
        final image = await _createTestImage(1200, 800);
        final targetSize = const ui.Size(600, 600);
        
        final result = await analyzer.analyze(image, targetSize);
        
        final expectedMetrics = [
          'intersection_alignment',
          'grid_line_alignment', 
          'content_distribution',
          'edge_avoidance',
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

      test('should calculate crop area ratio correctly', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(500, 500);
        
        final result = await analyzer.analyze(image, targetSize);
        
        final expectedRatio = result.coordinates.width * result.coordinates.height;
        expect(result.metrics['crop_area_ratio'], equals(expectedRatio));
        expect(result.metrics['crop_area_ratio'], lessThanOrEqualTo(1.0));
      });

      test('should calculate center distance correctly', () async {
        final image = await _createTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        final centerX = result.coordinates.x + result.coordinates.width / 2;
        final centerY = result.coordinates.y + result.coordinates.height / 2;
        final expectedDistance = math.sqrt((centerX - 0.5) * (centerX - 0.5) + 
                                           (centerY - 0.5) * (centerY - 0.5));
        
        expect(result.metrics['center_distance'], 
          closeTo(expectedDistance, 0.001));
      });
    });

    group('Score Validation', () {
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

      test('should prefer rule of thirds aligned crops over center crops', () async {
        final image = await _createTestImage(1200, 900);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        // The score should reflect rule of thirds preference
        expect(result.metrics['intersection_alignment'], greaterThan(0.0));
        
        // Center distance should indicate some offset from pure center
        expect(result.metrics['center_distance'], greaterThan(0.05));
      });
    });
  });
}

/// Helper function to create a test image
Future<ui.Image> _createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create a simple gradient pattern for testing
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