import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/center_weighted_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:math' as math;

void main() {
  group('CenterWeightedCropAnalyzer', () {
    late CenterWeightedCropAnalyzer analyzer;

    setUp(() {
      analyzer = CenterWeightedCropAnalyzer();
    });

    group('Basic Properties', () {
      test('should have correct strategy name', () {
        expect(analyzer.strategyName, equals('center_weighted'));
      });

      test('should have appropriate weight', () {
        expect(analyzer.weight, equals(0.6));
        expect(analyzer.weight, greaterThan(0.0));
        expect(analyzer.weight, lessThanOrEqualTo(1.0));
      });

      test('should be enabled by default', () {
        expect(analyzer.isEnabledByDefault, isTrue);
      });

      test('should have reasonable confidence threshold', () {
        expect(analyzer.minConfidenceThreshold, equals(0.2));
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
        expect(result.strategy, equals('center_weighted'));
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

    group('Center Bias Behavior', () {
      test('should prefer center crops over edge crops', () async {
        final image = await _createTestImage(1200, 800);
        final targetSize = const ui.Size(600, 600);
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Check that crop is reasonably centered
        final centerX = result.coordinates.x + result.coordinates.width / 2;
        final centerY = result.coordinates.y + result.coordinates.height / 2;
        
        // Should be closer to center than to edges
        expect(centerX, closeTo(0.5, 0.3)); // Within 30% of center
        expect(centerY, closeTo(0.5, 0.3)); // Within 30% of center
      });

      test('should have high center distance score for centered crops', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(800, 800);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('center_distance_score'), isTrue);
        expect(result.metrics['center_distance_score'], greaterThan(0.7));
      });

      test('should score distance from center correctly', () async {
        final image = await _createTestImage(800, 600);
        final targetSize = const ui.Size(400, 400);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('distance_from_center'), isTrue);
        expect(result.metrics['distance_from_center'], greaterThanOrEqualTo(0.0));
        
        // For center-weighted analyzer, distance should be relatively small
        expect(result.metrics['distance_from_center'], lessThan(0.3));
      });
    });

    group('Content Preservation', () {
      test('should include content preservation metrics', () async {
        final image = await _createTestImage(1200, 900);
        final targetSize = const ui.Size(600, 600);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('content_preservation_score'), isTrue);
        expect(result.metrics['content_preservation_score'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['content_preservation_score'], lessThanOrEqualTo(1.0));
      });

      test('should prefer crops that preserve more content', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(900, 900); // Large crop preserves more content
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Should have high content preservation score
        expect(result.metrics['content_preservation_score'], greaterThan(0.8));
        expect(result.metrics['crop_area_ratio'], greaterThan(0.8));
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

    group('Edge Safety', () {
      test('should include edge safety metrics', () async {
        final image = await _createTestImage(1000, 800);
        final targetSize = const ui.Size(500, 500);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('edge_safety_score'), isTrue);
        expect(result.metrics['edge_safety_score'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['edge_safety_score'], lessThanOrEqualTo(1.0));
      });

      test('should calculate minimum edge margin correctly', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(600, 600);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('min_edge_margin'), isTrue);
        
        // Calculate expected minimum margin
        final leftMargin = result.coordinates.x;
        final rightMargin = 1.0 - (result.coordinates.x + result.coordinates.width);
        final topMargin = result.coordinates.y;
        final bottomMargin = 1.0 - (result.coordinates.y + result.coordinates.height);
        
        final expectedMinMargin = math.min(
          math.min(leftMargin, rightMargin),
          math.min(topMargin, bottomMargin)
        );
        
        expect(result.metrics['min_edge_margin'], closeTo(expectedMinMargin, 0.001));
      });

      test('should avoid crops too close to edges', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(950, 950); // Very large crop
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Should maintain some margin from edges
        expect(result.metrics['min_edge_margin'], greaterThanOrEqualTo(0.0));
        
        // Edge safety score should reflect the tight margins
        expect(result.metrics['edge_safety_score'], lessThanOrEqualTo(1.0));
      });
    });

    group('Aspect Ratio Preservation', () {
      test('should include aspect ratio preservation metrics', () async {
        final image = await _createTestImage(1600, 900); // 16:9 ratio
        final targetSize = const ui.Size(800, 450); // Same 16:9 ratio
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.metrics.containsKey('aspect_ratio_preservation_score'), isTrue);
        expect(result.metrics['aspect_ratio_preservation_score'], greaterThanOrEqualTo(0.0));
        expect(result.metrics['aspect_ratio_preservation_score'], lessThanOrEqualTo(1.0));
      });

      test('should score same aspect ratios highly', () async {
        final image = await _createTestImage(800, 600); // 4:3 ratio
        final targetSize = const ui.Size(400, 300); // Same 4:3 ratio
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Should have high aspect ratio preservation
        expect(result.metrics['aspect_ratio_preservation_score'], greaterThan(0.7));
      });

      test('should penalize significant aspect ratio changes', () async {
        final image = await _createTestImage(1600, 900); // 16:9 ratio
        final targetSize = const ui.Size(500, 500); // 1:1 ratio (big change)
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Should have lower aspect ratio preservation score
        expect(result.metrics['aspect_ratio_preservation_score'], lessThan(0.8));
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

      test('should handle same aspect ratio efficiently', () async {
        final image = await _createTestImage(800, 600); // 4:3 ratio
        final targetSize = const ui.Size(400, 300); // Same 4:3 ratio
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.coordinates.width, equals(1.0));
        expect(result.coordinates.height, equals(1.0));
        expect(result.coordinates.x, equals(0.0));
        expect(result.coordinates.y, equals(0.0));
        expect(result.score, greaterThan(0.7)); // Should have high score
      });

      test('should handle very small target sizes', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(50, 50);
        
        final result = await analyzer.analyze(image, targetSize);
        
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThan(0.0));
      });
    });

    group('Conservative Behavior', () {
      test('should provide conservative cropping with center bias', () async {
        final image = await _createTestImage(1200, 800);
        final targetSize = const ui.Size(800, 800);
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Should be centered and conservative
        final centerX = result.coordinates.x + result.coordinates.width / 2;
        expect(centerX, closeTo(0.5, 0.2)); // Close to center
        
        // Should preserve reasonable amount of content
        expect(result.metrics['crop_area_ratio'], greaterThan(0.5));
        
        // Should maintain safe margins
        expect(result.metrics['min_edge_margin'], greaterThanOrEqualTo(0.0));
      });

      test('should have high confidence for center crops', () async {
        final image = await _createTestImage(1000, 1000);
        final targetSize = const ui.Size(800, 800);
        
        final result = await analyzer.analyze(image, targetSize);
        
        // Center crops should have high confidence
        expect(result.coordinates.confidence, greaterThan(0.5));
      });
    });

    group('Metrics Validation', () {
      test('should provide comprehensive metrics', () async {
        final image = await _createTestImage(1200, 800);
        final targetSize = const ui.Size(600, 600);
        
        final result = await analyzer.analyze(image, targetSize);
        
        final expectedMetrics = [
          'center_distance_score',
          'content_preservation_score',
          'edge_safety_score',
          'aspect_ratio_preservation_score',
          'crop_area_ratio',
          'distance_from_center',
          'min_edge_margin',
        ];
        
        for (final metric in expectedMetrics) {
          expect(result.metrics.containsKey(metric), isTrue,
            reason: 'Should include $metric in metrics');
          expect(result.metrics[metric], greaterThanOrEqualTo(0.0),
            reason: '$metric should be non-negative');
        }
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

/// Helper function to create a test image
Future<ui.Image> _createTestImage(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  
  // Create a radial gradient pattern for testing center-weighted behavior
  final paint = ui.Paint()
    ..shader = ui.Gradient.radial(
      ui.Offset(width / 2, height / 2),
      math.min(width, height) / 2,
      [const ui.Color(0xFFFFFFFF), const ui.Color(0xFF000000)],
    );
  
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    paint,
  );
  
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}