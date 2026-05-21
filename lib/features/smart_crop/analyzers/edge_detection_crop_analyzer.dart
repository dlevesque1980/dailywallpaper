import 'dart:ui' as ui;
import 'dart:typed_data';
import 'dart:isolate';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../interfaces/analysis_context.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';
import 'edge/edge_analyzer_helpers.dart';

/// Crop analyzer that uses edge detection to identify important image features
///
/// This analyzer applies Sobel edge detection to find areas with strong edges
/// and boundaries, preferring crops that contain significant edge content
/// which typically indicates important visual features.
class EdgeDetectionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'edge_detection';
  static const int _analyzerPriority = 300;
  static const double _analyzerWeight = 0.65;

  EdgeDetectionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 1000),
          metadata: const AnalyzerMetadata(
            description: 'Analyzes edge distribution and Sobel energy for crop scoring',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            minImageWidth: 100,
            minImageHeight: 100,
            isCpuIntensive: true,
            isMemoryIntensive: false,
            supportsParallelExecution: false,
          ),
        );

  @override
  bool get isEnabledByDefault => false; // More CPU intensive, disabled by default

  @override
  double get minConfidenceThreshold => 0.1;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) {
    return analyzeWithContext(
      image,
      targetSize,
      AnalysisContext(
        imageId: '',
        settings: CropSettings.defaultSettings,
        metadata: {},
      ),
    );
  }

  @override
  Future<CropScore> analyzeWithContext(
      ui.Image image, ui.Size targetSize, AnalysisContext context) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    // Get image data for edge detection (lazy-cached)
    final imageData = await _getImageData(image, context);

    final result = await Isolate.run(() => performEdgeAnalysisIsolate({
      'imageWidth': imageSize.width,
      'imageHeight': imageSize.height,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
      'width': image.width,
      'height': image.height,
    }));

    final bestCrop = result['bestCrop'] as CropCoordinates? ??
        _getCenterCrop(imageSize, targetAspectRatio);
    final bestScore = result['bestScore'] as double;
    final bestMetrics = Map<String, double>.from(result['bestMetrics'] as Map);

    return CropScore(
      coordinates: bestCrop,
      score: bestScore,
      strategy: strategyName,
      metrics: bestMetrics,
    );
  }

  /// Gets image pixel data for edge detection (lazy-cached)
  Future<Uint8List> _getImageData(ui.Image image, AnalysisContext context) async {
    if (context.metadata.containsKey('rawRgba')) {
      return context.metadata['rawRgba'] as Uint8List;
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = byteData!.buffer.asUint8List();
    context.metadata['rawRgba'] = bytes;
    return bytes;
  }

  /// Creates a center crop as fallback (Main thread)
  CropCoordinates _getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    double cropWidth, cropHeight;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }

    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.3,
      strategy: strategyName,
    );
  }
}
