import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import 'utils/analyzer_utils.dart';
import 'landscape/landscape_feature_detector.dart';
import 'landscape/landscape_scoring_logic.dart';

class LandscapeAwareCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'landscape_aware';

  @override
  double get weight => 1.0;

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.2;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    if (imageSize.width / imageSize.height < 1.3) {
      return CropScore(
        coordinates: AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName),
        score: 0.1,
        strategy: strategyName,
        metrics: {'landscape_detected': 0.0},
      );
    }

    final imageData = await _getImageData(image);
    final candidates = _generateCandidates(imageSize, targetAspectRatio, imageData);

    CropCoordinates? best;
    double bestScore = 0.0;
    Map<String, double> metrics = {};

    for (final c in candidates) {
      final score = LandscapeScoringLogic.scoreLandscapeCrop(c, imageSize, imageData);
      if (score > bestScore) {
        bestScore = score;
        best = c;
      }
    }

    best ??= AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName);
    metrics = _calculateMetrics(best, imageSize, imageData);

    return CropScore(coordinates: best, score: bestScore, strategy: strategyName, metrics: metrics);
  }

  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  List<CropCoordinates> _generateCandidates(ui.Size imageSize, double targetAspectRatio, Uint8List data) {
    final list = <CropCoordinates>[];
    final cW = AnalyzerUtils.calculateCropWidth(imageSize, targetAspectRatio);
    final cH = AnalyzerUtils.calculateCropHeight(imageSize, targetAspectRatio);

    final horizonY = LandscapeFeatureDetector.detectHorizon(imageSize, data);
    for (final pos in [1 / 3, 0.5, 2 / 3]) {
      final cropY = (horizonY - pos * cH).clamp(0.0, 1.0 - cH);
      for (final cropX in [0.0, 0.25, 0.5, 0.75, 1.0 - cW]) {
        list.add(CropCoordinates(x: cropX, y: cropY, width: cW, height: cH, confidence: 0.6, strategy: strategyName));
      }
    }

    final subjects = LandscapeFeatureDetector.detectSubjectAreas(imageSize, data);
    if (subjects.isNotEmpty) {
      double avgX = subjects.map((s) => s.dx).reduce((a, b) => a + b) / subjects.length;
      double avgY = subjects.map((s) => s.dy).reduce((a, b) => a + b) / subjects.length;
      list.add(CropCoordinates(x: (avgX - cW / 2).clamp(0.0, 1.0 - cW), y: (avgY - cH / 2).clamp(0.0, 1.0 - cH), width: cW, height: cH, confidence: 0.8, strategy: '${strategyName}_mean_subjects'));
      for (final s in subjects) {
        list.add(CropCoordinates(x: (s.dx - cW / 2).clamp(0.0, 1.0 - cW), y: (s.dy - cH / 2).clamp(0.0, 1.0 - cH), width: cW, height: cH, confidence: 0.7, strategy: strategyName));
      }
    }

    return list;
  }

  Map<String, double> _calculateMetrics(CropCoordinates crop, ui.Size size, Uint8List data) {
    final subjects = LandscapeFeatureDetector.detectSubjectAreas(size, data);
    final metrics = <String, double>{
      'landscape_detected': 1.0,
      'horizon_preservation': LandscapeScoringLogic.scoreLandscapeCrop(crop, size, data),
      'crop_area_ratio': crop.width * crop.height,
    };

    if (subjects.isNotEmpty) {
      double minX = 1, minY = 1, maxX = 0, maxY = 0;
      bool found = false;
      for (final s in subjects) {
        if (s.dx >= crop.x && s.dx <= crop.x + crop.width && s.dy >= crop.y && s.dy <= crop.y + crop.height) {
          minX = math.min(minX, s.dx); minY = math.min(minY, s.dy);
          maxX = math.max(maxX, s.dx); maxY = math.max(maxY, s.dy);
          found = true;
        }
      }
      if (found) {
        metrics['subject_x'] = math.max(0.0, minX - 0.05);
        metrics['subject_y'] = math.max(0.0, minY - 0.05);
        metrics['subject_width'] = math.min(1.0 - metrics['subject_x']!, (maxX - minX) + 0.1);
        metrics['subject_height'] = math.min(1.0 - metrics['subject_y']!, (maxY - minY) + 0.1);
      }
    }
    return metrics;
  }
}
