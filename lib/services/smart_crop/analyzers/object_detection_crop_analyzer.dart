import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import 'utils/analyzer_utils.dart';
import 'object/object_detector.dart';

class ObjectDetectionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'object_detection';
  static const int _analyzerPriority = 800;
  static const double _analyzerWeight = 0.85;

  ObjectDetectionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 600),
          metadata: const AnalyzerMetadata(
            description: 'Detects and preserves important objects and subjects in crop areas',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            isCpuIntensive: true,
            minImageWidth: 100,
            minImageHeight: 100,
          ),
        );

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      final imageData = await _getImageData(image);
      final objects = ObjectDetector.detectObjects(imageSize, imageData);

      if (objects.isEmpty) {
        final centerCrop = AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName);
        return CropScore(
          coordinates: centerCrop,
          score: 0.2,
          strategy: strategyName,
          metrics: {
            'objects_detected': 0.0,
            'object_count': 0.0,
            'detection_confidence': 0.0,
            'crop_area_ratio': (centerCrop.width * centerCrop.height) / (imageSize.width * imageSize.height),
          },
        );
      }

      final primary = objects.first;
      final crop = _createCrop(primary, imageSize, targetAspectRatio);
      final score = _scoreCrop(crop, objects);

      return CropScore(
        coordinates: crop,
        score: score,
        strategy: strategyName,
        metrics: {
          'objects_detected': objects.length.toDouble(),
          'object_count': objects.length.toDouble(),
          'detection_confidence': primary.confidence,
          'primary_object_confidence': primary.confidence,
          'subject_x': primary.bounds.left,
          'subject_y': primary.bounds.top,
          'subject_width': primary.bounds.width,
          'subject_height': primary.bounds.height,
          'crop_area_ratio': (crop.width * crop.height) / (imageSize.width * imageSize.height),
        },
      );
    } catch (e) {
      return CropScore(
        coordinates: AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName),
        score: 0.2,
        strategy: strategyName,
        metrics: {'error': e.toString()},
      );
    }
  }

  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  CropCoordinates _createCrop(DetectedObject object, ui.Size size, double aspect) {
    final cW = AnalyzerUtils.calculateCropWidth(size, aspect);
    final cH = AnalyzerUtils.calculateCropHeight(size, aspect);
    return CropCoordinates(
      x: (object.center.dx - cW / 2).clamp(0.0, 1.0 - cW),
      y: (object.center.dy - cH / 2).clamp(0.0, 1.0 - cH),
      width: cW,
      height: cH,
      confidence: object.confidence,
      strategy: '${strategyName}_object_focused',
    );
  }

  double _scoreCrop(CropCoordinates crop, List<DetectedObject> objects) {
    final cropRect = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height);
    double totalI = 0, totalInc = 0;
    for (final o in objects) {
      totalInc += (cropRect.intersect(o.bounds).isEmpty ? 0.0 : 1.0) * o.importance;
      totalI += o.importance;
    }
    final incScore = totalI > 0 ? totalInc / totalI : 0.0;
    final avgConf = objects.map((o) => o.confidence).reduce((a, b) => a + b) / objects.length;
    double quality = 1.0;
    if (crop.x <= 0.01) quality -= 0.1;
    if (crop.y <= 0.01) quality -= 0.1;
    if (crop.x + crop.width >= 0.99) quality -= 0.1;
    if (crop.y + crop.height >= 0.99) quality -= 0.1;

    return (incScore * 0.5 + avgConf * 0.3 + math.max(0.0, quality) * 0.2);
  }
}
