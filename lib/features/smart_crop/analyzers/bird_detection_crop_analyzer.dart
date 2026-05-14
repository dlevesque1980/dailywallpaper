import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import 'bird/bird_feature_detector.dart';
import 'bird/bird_scoring_logic.dart';

class BirdDetectionCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'bird_detection';

  @override
  double get weight => 0.10;

  @override
  bool get isEnabledByDefault => false;

  @override
  double get minConfidenceThreshold => 0.25;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    final imageData = await _getImageData(image);
    final birds = BirdFeatureDetector.detectBirds(imageSize, imageData);

    if (birds.isEmpty) {
      return _centerScore(imageSize, targetAspectRatio);
    }

    CropCoordinates? bestCrop;
    double bestScore = 0.0;

    for (final bird in birds) {
      final strategies = _generateStrategies(bird, imageSize, targetAspectRatio);
      for (final strategy in strategies) {
        final score = BirdScoringLogic.scoreBirdCrop(strategy, bird);
        if (score > bestScore) {
          bestScore = score;
          bestCrop = strategy;
        }
      }
    }

    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);

    return CropScore(
      coordinates: bestCrop,
      score: bestScore,
      strategy: strategyName,
      metrics: {'birds_detected': birds.length.toDouble()},
    );
  }

  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  List<CropCoordinates> _generateStrategies(DetectedBird bird, ui.Size imageSize, double targetAspectRatio) {
    final list = <CropCoordinates>[];
    final cW = _calculateCropWidth(imageSize, targetAspectRatio);
    final cH = _calculateCropHeight(imageSize, targetAspectRatio);

    // Head focus
    if (bird.hasHead) {
      list.add(CropCoordinates(
        x: (bird.center.dx - cW / 2).clamp(0.0, 1.0 - cW),
        y: (bird.center.dy - 0.3 * cH).clamp(0.0, 1.0 - cH),
        width: cW,
        height: cH,
        confidence: bird.confidence * 1.2,
        strategy: '${strategyName}_head_focus',
      ));
    }

    // Full bird
    list.add(CropCoordinates(
      x: (bird.center.dx - cW / 2).clamp(0.0, 1.0 - cW),
      y: (bird.center.dy - cH / 2).clamp(0.0, 1.0 - cH),
      width: cW,
      height: cH,
      confidence: bird.confidence,
      strategy: '${strategyName}_full_bird',
    ));

    return list;
  }

  CropScore _centerScore(ui.Size imageSize, double targetAspectRatio) {
    final center = _getCenterCrop(imageSize, targetAspectRatio);
    return CropScore(coordinates: center, score: 0.05, strategy: strategyName, metrics: {'birds_detected': 0.0});
  }

  CropCoordinates _getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final cW = _calculateCropWidth(imageSize, targetAspectRatio);
    final cH = _calculateCropHeight(imageSize, targetAspectRatio);
    return CropCoordinates(x: (1.0 - cW) / 2, y: (1.0 - cH) / 2, width: cW, height: cH, confidence: 0.5, strategy: 'fallback_center');
  }

  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspect ? 1.0 : targetAspectRatio / imageAspect;
  }

  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspect ? 1.0 : imageAspect / targetAspectRatio;
  }
}
