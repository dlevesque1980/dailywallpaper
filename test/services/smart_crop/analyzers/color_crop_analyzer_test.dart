import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/color_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

void main() {
  group('ColorCropAnalyzer', () {
    late ColorCropAnalyzer analyzer;

    setUp(() {
      analyzer = ColorCropAnalyzer();
    });

    tearDown(() {
      analyzer.dispose();
    });

    group('Analyzer Properties', () {
      test('should have correct name and properties', () {
        expect(analyzer.name, equals('color_analysis'));
        expect(analyzer.strategyName, equals('color_analysis'));
        expect(analyzer.priority, equals(700));
        expect(analyzer.weight, equals(0.75));
        expect(analyzer.isEnabledByDefault, isTrue);
        expect(analyzer.minConfidenceThreshold, equals(0.1));
      });

      test('should have correct metadata', () {
        final metadata = analyzer.metadata;
        expect(metadata.description, contains('color'));
        expect(metadata.description, contains('harmony'));
        expect(metadata.version, equals('2.0.0'));
        expect(metadata.isCpuIntensive, isFalse);
        expect(metadata.isMemoryIntensive, isFalse);
        expect(metadata.supportsParallelExecution, isTrue);
        expect(metadata.minImageWidth, equals(100));
        expect(metadata.minImageHeight, equals(100));
      });

      test('should validate correctly', () {
        expect(analyzer.validate(), isTrue);
      });
    });

    group('Image Compatibility', () {
      test('should handle valid image sizes', () {
        expect(
            analyzer.canAnalyze(
                _createMockImage(200, 200), _createMockSettings()),
            isTrue);
        expect(
            analyzer.canAnalyze(
                _createMockImage(1000, 800), _createMockSettings()),
            isTrue);
        expect(
            analyzer.canAnalyze(
                _createMockImage(2048, 2048), _createMockSettings()),
            isTrue);
      });

      test('should reject invalid image sizes', () {
        expect(
            analyzer.canAnalyze(_createMockImage(0, 0), _createMockSettings()),
            isFalse);
        expect(
            analyzer.canAnalyze(
                _createMockImage(-1, 100), _createMockSettings()),
            isFalse);
      });
    });

    group('Basic Functionality', () {
      testWidgets('should return valid crop score for simple image',
          (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());
        expect(result.strategy, equals('color_analysis'));
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.0));
        expect(result.score, lessThanOrEqualTo(1.0));
      });

      testWidgets('should include color metrics in results',
          (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result.metrics,
            containsPair('color_vibrancy_score', isA<double>()));
        expect(
            result.metrics, containsPair('color_harmony_score', isA<double>()));
        expect(result.metrics,
            containsPair('color_distribution_score', isA<double>()));
        expect(result.metrics,
            containsPair('color_contrast_score', isA<double>()));
        expect(result.metrics, containsPair('color_score', isA<double>()));
        expect(result.metrics, containsPair('crop_area_ratio', isA<double>()));
        expect(
            result.metrics, containsPair('average_saturation', isA<double>()));
        expect(
            result.metrics, containsPair('average_brightness', isA<double>()));
      });

      testWidgets('should handle different aspect ratios',
          (WidgetTester tester) async {
        final image = _createMockImage(400, 600);

        // Test portrait aspect ratio
        final portraitResult =
            await analyzer.analyze(image, const ui.Size(200, 300));
        expect(portraitResult.coordinates.isValid, isTrue);

        // Test landscape aspect ratio
        final landscapeResult =
            await analyzer.analyze(image, const ui.Size(300, 200));
        expect(landscapeResult.coordinates.isValid, isTrue);

        // Test square aspect ratio
        final squareResult =
            await analyzer.analyze(image, const ui.Size(250, 250));
        expect(squareResult.coordinates.isValid, isTrue);
      });
    });

    group('Color Analysis', () {
      testWidgets('should analyze color vibrancy', (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());

        // Should have reasonable vibrancy score
        final vibrancyScore =
            result.metrics['color_vibrancy_score'] as double? ?? 0.0;
        expect(vibrancyScore, greaterThanOrEqualTo(0.0));
        expect(vibrancyScore, lessThanOrEqualTo(1.0));
      });

      testWidgets('should analyze color harmony', (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());

        // Should have reasonable harmony score
        final harmonyScore =
            result.metrics['color_harmony_score'] as double? ?? 0.0;
        expect(harmonyScore, greaterThanOrEqualTo(0.0));
        expect(harmonyScore, lessThanOrEqualTo(1.0));
      });

      testWidgets('should analyze color distribution',
          (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());

        // Should have reasonable distribution score
        final distributionScore =
            result.metrics['color_distribution_score'] as double? ?? 0.0;
        expect(distributionScore, greaterThanOrEqualTo(0.0));
        expect(distributionScore, lessThanOrEqualTo(1.0));
      });

      testWidgets('should analyze color contrast', (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());

        // Should have reasonable contrast score
        final contrastScore =
            result.metrics['color_contrast_score'] as double? ?? 0.0;
        expect(contrastScore, greaterThanOrEqualTo(0.0));
        expect(contrastScore, lessThanOrEqualTo(1.0));
      });
    });

    group('Error Handling', () {
      testWidgets('should handle analysis errors gracefully',
          (WidgetTester tester) async {
        final image = _createMockImage(1, 1);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.0));
      });

      testWidgets('should provide fallback crop when color analysis fails',
          (WidgetTester tester) async {
        final image = _createMockImage(100, 100);
        final targetSize = const ui.Size(50, 50);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());
        expect(result.coordinates.isValid, isTrue);
        expect(result.coordinates.x, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.y, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.width, greaterThan(0.0));
        expect(result.coordinates.height, greaterThan(0.0));
      });
    });

    group('Performance', () {
      testWidgets('should complete analysis within reasonable time',
          (WidgetTester tester) async {
        final image = _createMockImage(800, 600);
        final targetSize = const ui.Size(400, 300);

        final stopwatch = Stopwatch()..start();
        final result = await analyzer.analyze(image, targetSize);
        stopwatch.stop();

        expect(result, isA<CropScore>());
        expect(stopwatch.elapsedMilliseconds,
            lessThan(2000)); // Should complete within 2 seconds for mock
      });
    });

    group('Crop Quality', () {
      testWidgets('should prefer colorful regions',
          (WidgetTester tester) async {
        final image = _createMockImage(600, 400);
        final targetSize = const ui.Size(400, 300);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());
        expect(result.coordinates.isValid, isTrue);

        // Should have reasonable color score
        final colorScore = result.metrics['color_score'] as double? ?? 0.0;
        expect(colorScore, greaterThan(0.2)); // Should be better than random
      });

      testWidgets('should maintain color balance', (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(300, 225);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());
        expect(result.coordinates.isValid, isTrue);

        // Should have reasonable distribution score
        final distributionScore =
            result.metrics['color_distribution_score'] as double? ?? 0.0;
        expect(distributionScore,
            greaterThan(0.1)); // Should maintain some color balance
      });
    });
  });
}

// Helper functions for testing

ui.Image _createMockImage(int width, int height) {
  return _MockImage(width, height);
}

CropSettings _createMockSettings() {
  return const CropSettings();
}

// Mock image class for testing
class _MockImage implements ui.Image {
  @override
  final int width;

  @override
  final int height;

  _MockImage(this.width, this.height);

  @override
  void dispose() {}

  @override
  ui.ColorSpace get colorSpace => ui.ColorSpace.sRGB;

  @override
  Future<ByteData?> toByteData(
      {ui.ImageByteFormat format = ui.ImageByteFormat.rawRgba}) async {
    final pixels = _createColorfulPixels(width, height);
    return ByteData.view(pixels.buffer);
  }

  @override
  ui.Image clone() => _MockImage(width, height);

  @override
  bool get debugDisposed => false;

  @override
  List<StackTrace>? debugGetOpenHandleStackTraces() => null;

  @override
  bool isCloneOf(ui.Image other) => false;
}

Uint8List _createColorfulPixels(int width, int height) {
  final pixels = Uint8List(width * height * 4);

  // Create a gradient with some color variation for more interesting color analysis
  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final index = (y * width + x) * 4;

      // Create a simple gradient with color variation
      final r = ((x / width) * 255).round();
      final g = ((y / height) * 255).round();
      final b = (((x + y) / (width + height)) * 255).round();

      pixels[index] = r; // Red
      pixels[index + 1] = g; // Green
      pixels[index + 2] = b; // Blue
      pixels[index + 3] = 255; // Alpha
    }
  }

  return pixels;
}
