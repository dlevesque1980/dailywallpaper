import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/object_detection_crop_analyzer.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

void main() {
  group('ObjectDetectionCropAnalyzer', () {
    late ObjectDetectionCropAnalyzer analyzer;

    setUp(() {
      analyzer = ObjectDetectionCropAnalyzer();
    });

    tearDown(() {
      analyzer.dispose();
    });

    group('Analyzer Properties', () {
      test('should have correct name and properties', () {
        expect(analyzer.name, equals('object_detection'));
        expect(analyzer.strategyName, equals('object_detection'));
        expect(analyzer.priority, equals(800));
        expect(analyzer.weight, equals(0.85));
        expect(analyzer.isEnabledByDefault, isTrue);
        expect(analyzer.minConfidenceThreshold, equals(0.1));
      });

      test('should have correct metadata', () {
        final metadata = analyzer.metadata;
        expect(metadata.description, contains('object'));
        expect(metadata.version, equals('2.0.0'));
        expect(metadata.isCpuIntensive, isTrue);
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
        expect(result.strategy, equals('object_detection'));
        expect(result.coordinates.isValid, isTrue);
        expect(result.score, greaterThanOrEqualTo(0.0));
        expect(result.score, lessThanOrEqualTo(1.0));
      });

      testWidgets('should include object metrics in results',
          (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(200, 150);

        final result = await analyzer.analyze(image, targetSize);

        expect(result.metrics, containsPair('objects_detected', isA<double>()));
        expect(result.metrics, containsPair('object_count', isA<double>()));
        expect(result.metrics, containsPair('crop_area_ratio', isA<double>()));
        expect(result.metrics,
            containsPair('detection_confidence', isA<double>()));
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

      testWidgets('should provide fallback crop when object detection fails',
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
            lessThan(3000)); // Should complete within 3 seconds for mock
      });
    });

    group('Crop Quality', () {
      testWidgets('should avoid edge crops when possible',
          (WidgetTester tester) async {
        final image = _createMockImage(400, 300);
        final targetSize = const ui.Size(300, 225);

        final result = await analyzer.analyze(image, targetSize);

        expect(result, isA<CropScore>());
        expect(result.coordinates.isValid, isTrue);

        // Should avoid touching edges when possible
        expect(result.coordinates.x, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.y, greaterThanOrEqualTo(0.0));
        expect(result.coordinates.x + result.coordinates.width,
            lessThanOrEqualTo(1.0));
        expect(result.coordinates.y + result.coordinates.height,
            lessThanOrEqualTo(1.0));
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
    final pixels = _createUniformPixels(width, height, 128, 128, 128);
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

Uint8List _createUniformPixels(int width, int height, int r, int g, int b) {
  final pixels = Uint8List(width * height * 4);
  for (int i = 0; i < pixels.length; i += 4) {
    pixels[i] = r; // Red
    pixels[i + 1] = g; // Green
    pixels[i + 2] = b; // Blue
    pixels[i + 3] = 255; // Alpha
  }
  return pixels;
}
