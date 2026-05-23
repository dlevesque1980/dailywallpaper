import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../interfaces/analysis_context.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';
import 'utils/analyzer_utils.dart';
import 'landscape/landscape_feature_detector.dart';
import 'landscape/landscape_scoring_logic.dart';
import '../utils/analyzer_isolate_pool.dart';

class LandscapeAwareCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'landscape_aware';
  static const int _analyzerPriority = 500;
  static const double _analyzerWeight = 1.0;

  LandscapeAwareCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 600),
          metadata: const AnalyzerMetadata(
            description:
                'Detects natural horizons, linear compositions, and landscape features',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            minImageWidth: 100,
            minImageHeight: 100,
          ),
        );

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.2;

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

    if (imageSize.width / imageSize.height < 1.3) {
      return CropScore(
        coordinates: AnalyzerUtils.getCenterCrop(
            imageSize, targetAspectRatio, strategyName),
        score: 0.1,
        strategy: strategyName,
        metrics: {'landscape_detected': 0.0},
      );
    }

    final imageData = await _getImageData(image, context);

    final result = await AnalyzerIsolatePool.instance.run(_performLandscapeAnalysisIsolate, {
      'imageWidth': imageSize.width,
      'imageHeight': imageSize.height,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
    });

    return CropScore(
        coordinates: result['best'] as CropCoordinates,
        score: result['bestScore'] as double,
        strategy: strategyName,
        metrics: Map<String, double>.from(result['metrics'] as Map));
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

}

/// Top-level function executed in background isolate
Map<String, dynamic> _performLandscapeAnalysisIsolate(Map<String, dynamic> params) {
  final ui.Size imageSize = ui.Size(params['imageWidth'] as double, params['imageHeight'] as double);
  final double targetAspectRatio = params['targetAspectRatio'];
  final Uint8List imageData = params['imageData'];
  final String strategyName = params['strategyName'];

  List<CropCoordinates> generateCandidates() {
    final list = <CropCoordinates>[];
    final cW = AnalyzerUtils.calculateCropWidth(imageSize, targetAspectRatio);
    final cH = AnalyzerUtils.calculateCropHeight(imageSize, targetAspectRatio);

    final horizonY = LandscapeFeatureDetector.detectHorizon(imageSize, imageData);
    for (final pos in [1 / 3, 0.5, 2 / 3]) {
      final cropY = (horizonY - pos * cH).clamp(0.0, 1.0 - cH);
      for (final cropX in [0.0, 0.25, 0.5, 0.75, 1.0 - cW]) {
        list.add(CropCoordinates(
            x: cropX,
            y: cropY,
            width: cW,
            height: cH,
            confidence: 0.6,
            strategy: strategyName));
      }
    }

    final subjects =
        LandscapeFeatureDetector.detectSubjectAreas(imageSize, imageData);
    if (subjects.isNotEmpty) {
      double avgX =
          subjects.map((s) => s.dx).reduce((a, b) => a + b) / subjects.length;
      double avgY =
          subjects.map((s) => s.dy).reduce((a, b) => a + b) / subjects.length;
      list.add(CropCoordinates(
          x: (avgX - cW / 2).clamp(0.0, 1.0 - cW),
          y: (avgY - cH / 2).clamp(0.0, 1.0 - cH),
          width: cW,
          height: cH,
          confidence: 0.8,
          strategy: '${strategyName}_mean_subjects'));
      for (final s in subjects) {
        list.add(CropCoordinates(
            x: (s.dx - cW / 2).clamp(0.0, 1.0 - cW),
            y: (s.dy - cH / 2).clamp(0.0, 1.0 - cH),
            width: cW,
            height: cH,
            confidence: 0.7,
            strategy: strategyName));
      }
    }

    return list;
  }

  Map<String, double> calculateMetrics(CropCoordinates crop) {
    final subjects = LandscapeFeatureDetector.detectSubjectAreas(imageSize, imageData);
    final metrics = <String, double>{
      'landscape_detected': 1.0,
      'horizon_preservation':
          LandscapeScoringLogic.scoreLandscapeCrop(crop, imageSize, imageData),
      'crop_area_ratio': crop.width * crop.height,
    };

    if (subjects.isNotEmpty) {
      double minX = 1, minY = 1, maxX = 0, maxY = 0;
      bool found = false;
      for (final s in subjects) {
        if (s.dx >= crop.x &&
            s.dx <= crop.x + crop.width &&
            s.dy >= crop.y &&
            s.dy <= crop.y + crop.height) {
          minX = math.min(minX, s.dx);
          minY = math.min(minY, s.dy);
          maxX = math.max(maxX, s.dx);
          maxY = math.max(maxY, s.dy);
          found = true;
        }
      }
      if (found) {
        metrics['subject_x'] = math.max(0.0, minX - 0.05);
        metrics['subject_y'] = math.max(0.0, minY - 0.05);
        metrics['subject_width'] =
            math.min(1.0 - metrics['subject_x']!, (maxX - minX) + 0.1);
        metrics['subject_height'] =
            math.min(1.0 - metrics['subject_y']!, (maxY - minY) + 0.1);
      }
    }
    return metrics;
  }

  final candidates = generateCandidates();

  CropCoordinates? best;
  double bestScore = 0.0;

  for (final c in candidates) {
    final score =
        LandscapeScoringLogic.scoreLandscapeCrop(c, imageSize, imageData);
    if (score > bestScore) {
      bestScore = score;
      best = c;
    }
  }

  best ??=
      AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName);
  final metrics = calculateMetrics(best);

  return {
    'best': best,
    'bestScore': bestScore,
    'metrics': metrics,
  };
}
