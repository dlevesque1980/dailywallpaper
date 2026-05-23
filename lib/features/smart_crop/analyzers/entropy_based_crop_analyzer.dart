import 'dart:ui' as ui;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../interfaces/analysis_context.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';
import 'entropy/entropy_analyzer_helpers.dart';
import '../utils/analyzer_isolate_pool.dart';

/// Crop analyzer that uses image entropy to detect content density
///
/// This analyzer calculates the information content (entropy) of different
/// image regions and prefers crops that contain areas with high visual
/// complexity and information density.
class EntropyBasedCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'entropy_based';
  static const int _analyzerPriority = 200;
  static const double _analyzerWeight = 0.7;

  EntropyBasedCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 1000),
          metadata: const AnalyzerMetadata(
            description: 'Analyzes information entropy/complexity of crop areas',
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
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.15;

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

    // Get image data for entropy calculation (lazy-cached)
    final imageData = await _getImageData(image, context);

    final result = await AnalyzerIsolatePool.instance.run(performEntropyAnalysisIsolate, {
      'imageWidth': imageSize.width,
      'imageHeight': imageSize.height,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
    });

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

  /// Gets image pixel data for entropy calculations (lazy-cached)
  Future<Uint8List> _getImageData(ui.Image image, AnalysisContext context) async {
    if (context.metadata.containsKey('rawRgba')) {
      return context.metadata['rawRgba'] as Uint8List;
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = byteData!.buffer.asUint8List();
    context.metadata['rawRgba'] = bytes;
    return bytes;
  }

  /// Helper for center crop (must be available on main thread)
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
      confidence: 0.4,
      strategy: strategyName,
    );
  }
}
