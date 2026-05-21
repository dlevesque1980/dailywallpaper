import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:isolate';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../interfaces/analysis_context.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';
import 'face/face_analyzer_helpers.dart';

/// Face detection analyzer for smart cropping
class FaceDetectionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'face_detection';
  static const int _analyzerPriority = 400;
  static const double _analyzerWeight = 0.40;

  FaceDetectionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 800),
          metadata: const AnalyzerMetadata(
            description: 'Detects and preserves human faces in crop areas',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            minImageWidth: 100,
            minImageHeight: 100,
            maxImageWidth: 2048,
            maxImageHeight: 2048,
            isCpuIntensive: true,
            isMemoryIntensive: false,
            supportsParallelExecution: false,
          ),
        );

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

    try {
      final imageData = await _getImageData(image, context);

      // Execute CPU-heavy grid check inside background Isolate
      final faces = await Isolate.run(() => performFaceAnalysisIsolate({
        'imageWidth': imageSize.width,
        'imageHeight': imageSize.height,
        'imageData': imageData,
      }));

      if (faces.isEmpty) {
        final centerCrop = _getCenterCrop(imageSize, targetAspectRatio);
        return CropScore(
          coordinates: centerCrop,
          score: 0.1,
          strategy: strategyName,
          metrics: {
            'faces_detected': 0.0,
            'face_count': 0.0,
            'detection_confidence': 0.0,
            'crop_area_ratio': centerCrop.width * centerCrop.height,
          },
        );
      }

      final bestFace = faces.first;
      final cropCoordinates =
          _createFaceCrop(bestFace, imageSize, targetAspectRatio);
      final score = _scoreFaceCrop(cropCoordinates, bestFace);

      return CropScore(
        coordinates: cropCoordinates,
        score: score,
        strategy: strategyName,
        metrics: {
          'faces_detected': faces.length.toDouble(),
          'face_count': faces.length.toDouble(),
          'detection_confidence': bestFace.confidence,
          'primary_face_confidence': bestFace.confidence,
          'crop_area_ratio': cropCoordinates.width * cropCoordinates.height,
          'subject_x': bestFace.bounds.left,
          'subject_y': bestFace.bounds.top,
          'subject_width': bestFace.bounds.width,
          'subject_height': bestFace.bounds.height,
        },
      );
    } catch (e) {
      return CropScore(
        coordinates: _getCenterCrop(imageSize, targetAspectRatio),
        score: 0.1,
        strategy: strategyName,
        metrics: {
          'faces_detected': 0.0,
          'error': e.toString(),
        },
      );
    }
  }

  Future<Uint8List> _getImageData(ui.Image image, AnalysisContext context) async {
    if (context.metadata.containsKey('rawRgba')) {
      return context.metadata['rawRgba'] as Uint8List;
    }
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    final bytes = byteData!.buffer.asUint8List();
    context.metadata['rawRgba'] = bytes;
    return bytes;
  }

  CropCoordinates _createFaceCrop(
    DetectedFace face,
    ui.Size imageSize,
    double targetAspectRatio,
  ) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    final offsetX = face.size > 0.2 ? 0.1 : 0.0;
    final offsetY = face.size > 0.2 ? -0.1 : 0.0;

    final targetX = face.center.dx + offsetX;
    final targetY = face.center.dy + offsetY;

    final cropX =
        math.max(0.0, math.min(1.0 - cropWidth, targetX - cropWidth / 2));
    final cropY =
        math.max(0.0, math.min(1.0 - cropHeight, targetY - cropHeight / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: face.confidence,
      strategy: '${strategyName}_face_focused',
    );
  }

  double _scoreFaceCrop(CropCoordinates crop, DetectedFace face) {
    double score = 0.0;
    final cropRect = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height);
    final intersection = cropRect.intersect(face.bounds);
    final inclusionRatio = intersection.isEmpty
        ? 0.0
        : (intersection.width * intersection.height) /
            (face.bounds.width * face.bounds.height);
    score += inclusionRatio * 0.6;
    score += face.confidence * 0.3;
    score += _scoreCropQuality(crop) * 0.1;
    return math.min(1.0, score);
  }

  double _scoreCropQuality(CropCoordinates crop) {
    double score = 1.0;
    if (crop.x <= 0.01) score -= 0.1;
    if (crop.y <= 0.01) score -= 0.1;
    if (crop.x + crop.width >= 0.99) score -= 0.1;
    if (crop.y + crop.height >= 0.99) score -= 0.1;
    return math.max(0.0, score);
  }

  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspectRatio
        ? 1.0
        : targetAspectRatio / imageAspectRatio;
  }

  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspectRatio
        ? 1.0
        : imageAspectRatio / targetAspectRatio;
  }

  CropCoordinates _getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);
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
