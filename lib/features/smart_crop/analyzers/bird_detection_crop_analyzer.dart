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
import 'bird/bird_feature_detector.dart';
import 'bird/bird_scoring_logic.dart';

class BirdDetectionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'bird_detection';
  static const int _analyzerPriority = 150;
  static const double _analyzerWeight = 0.10;

  BirdDetectionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 800),
          metadata: const AnalyzerMetadata(
            description: 'Detects and scores birds in crop areas',
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
  bool get isEnabledByDefault => false;

  @override
  double get minConfidenceThreshold => 0.25;

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

    final imageData = await _getImageData(image, context);
    
    final result = await Isolate.run(() => _performBirdAnalysisIsolate({
      'imageWidth': imageSize.width,
      'imageHeight': imageSize.height,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
    }));

    final birds = result['birds'] as List;
    final bestCrop = result['best'] as CropCoordinates? ??
        _getCenterCrop(imageSize, targetAspectRatio);
    final bestScore = result['bestScore'] as double;

    return CropScore(
      coordinates: bestCrop,
      score: bestScore,
      strategy: strategyName,
      metrics: {'birds_detected': birds.length.toDouble()},
    );
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


  CropCoordinates _getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final cW = _calculateCropWidth(imageSize, targetAspectRatio);
    final cH = _calculateCropHeight(imageSize, targetAspectRatio);
    return CropCoordinates(
        x: (1.0 - cW) / 2,
        y: (1.0 - cH) / 2,
        width: cW,
        height: cH,
        confidence: 0.5,
        strategy: 'fallback_center');
  }

  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspect
        ? 1.0
        : targetAspectRatio / imageAspect;
  }

  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspect
        ? 1.0
        : imageAspect / targetAspectRatio;
  }
}

/// Top-level function executed in background isolate
Map<String, dynamic> _performBirdAnalysisIsolate(Map<String, dynamic> params) {
  final ui.Size imageSize = ui.Size(params['imageWidth'] as double, params['imageHeight'] as double);
  final double targetAspectRatio = params['targetAspectRatio'];
  final Uint8List imageData = params['imageData'];
  final String strategyName = params['strategyName'];

  final birds = BirdFeatureDetector.detectBirds(imageSize, imageData);

  if (birds.isEmpty) {
    return {
      'birds': <DetectedBird>[],
      'best': null,
      'bestScore': 0.05,
    };
  }

  double calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspect
        ? 1.0
        : targetAspectRatio / imageAspect;
  }

  double calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspect
        ? 1.0
        : imageAspect / targetAspectRatio;
  }

  CropCoordinates getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final cW = calculateCropWidth(imageSize, targetAspectRatio);
    final cH = calculateCropHeight(imageSize, targetAspectRatio);
    return CropCoordinates(
        x: (1.0 - cW) / 2,
        y: (1.0 - cH) / 2,
        width: cW,
        height: cH,
        confidence: 0.5,
        strategy: 'fallback_center');
  }

  List<CropCoordinates> generateStrategies(DetectedBird bird) {
    final list = <CropCoordinates>[];
    final cW = calculateCropWidth(imageSize, targetAspectRatio);
    final cH = calculateCropHeight(imageSize, targetAspectRatio);

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

  CropCoordinates? bestCrop;
  double bestScore = 0.0;

  for (final bird in birds) {
    final strategies = generateStrategies(bird);
    for (final strategy in strategies) {
      final score = BirdScoringLogic.scoreBirdCrop(strategy, bird);
      if (score > bestScore) {
        bestScore = score;
        bestCrop = strategy;
      }
    }
  }

  bestCrop ??= getCenterCrop(imageSize, targetAspectRatio);

  return {
    'birds': birds,
    'best': bestCrop,
    'bestScore': bestScore,
  };
}
