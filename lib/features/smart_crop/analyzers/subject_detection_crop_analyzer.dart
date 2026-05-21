import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import 'utils/analyzer_utils.dart';
import 'subject/subject_detector.dart';
import 'subject/subject_scoring_logic.dart';

import '../interfaces/analyzer_metadata.dart';
import '../interfaces/analysis_context.dart';
import '../models/crop_settings.dart';
import 'utils/analyzer_utils.dart';
import 'subject/subject_detector.dart';
import 'subject/subject_scoring_logic.dart';

class SubjectDetectionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'subject_detection';
  static const int _analyzerPriority = 600;
  static const double _analyzerWeight = 0.75;

  SubjectDetectionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 800),
          metadata: const AnalyzerMetadata(
            description:
                'Detects and scores high-frequency subject points in crop areas',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            minImageWidth: 100,
            minImageHeight: 100,
          ),
        );

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.3;

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

    final result = await Isolate.run(() => _performAnalysisIsolate({
      'imageWidth': imageSize.width,
      'imageHeight': imageSize.height,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
    }));

    final bestCrop = result['bestCrop'] as CropCoordinates? ??
        AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName);
    return CropScore(
      coordinates: bestCrop,
      score: result['bestScore'] as double,
      strategy: strategyName,
      metrics: Map<String, double>.from(result['bestMetrics'] as Map),
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

}

Map<String, dynamic> _performAnalysisIsolate(Map<String, dynamic> params) {
  final ui.Size imageSize = ui.Size(params['imageWidth'] as double, params['imageHeight'] as double);
  final double targetAspectRatio = params['targetAspectRatio'];
  final Uint8List imageData = params['imageData'];
  final String strategyName = params['strategyName'];

  final subjects = SubjectDetector.detectSubjects(imageSize, imageData);

  if (subjects.isEmpty) {
    return {
      'bestCrop': null,
      'bestScore': 0.1,
      'bestMetrics': {'subjects_detected': 0.0}
    };
  }

  CropCoordinates? best;
  double bestScore = 0.0;
  Map<String, double> metrics = {};
  double maxImp = subjects.map((s) => s.importance).reduce(math.max);

  for (final s in subjects) {
    final strategies =
        _generateStrategies(s, imageSize, targetAspectRatio, strategyName);
    for (final strat in strategies) {
      final score = SubjectScoringLogic.scoreSubjectCrop(
          strat, s, maxImp, targetAspectRatio, imageSize);
      if (score > bestScore) {
        bestScore = score;
        best = strat;
        metrics = {
          'subjects_detected': subjects.length.toDouble(),
          'subject_inclusion':
              (ui.Rect.fromLTWH(strat.x, strat.y, strat.width, strat.height)
                      .intersect(s.bounds)
                      .isEmpty
                  ? 0.0
                  : 1.0),
          'subject_importance': s.importance,
          'subject_target_x': s.center.dx,
          'subject_target_y': s.center.dy,
        };
      }
    }
  }

  return {'bestCrop': best, 'bestScore': bestScore, 'bestMetrics': metrics};
}

List<CropCoordinates> _generateStrategies(
    DetectedSubject s, ui.Size size, double aspect, String name) {
  final list = <CropCoordinates>[];
  final cW = AnalyzerUtils.calculateCropWidth(size, aspect),
      cH = AnalyzerUtils.calculateCropHeight(size, aspect);

  // Tight
  double sw = s.bounds.width * 1.3, sh = s.bounds.height * 1.3;
  final rel = aspect / (size.width / size.height);
  if (sw / sh > rel)
    sh = sw / rel;
  else
    sw = sh * rel;
  if (sw > 1 || sh > 1) {
    final f = math.min(1.0 / sw, 1.0 / sh);
    sw *= f;
    sh *= f;
  }
  list.add(CropCoordinates(
      x: (s.center.dx - sw / 2).clamp(0.0, 1.0 - sw),
      y: (s.center.dy - sh / 2).clamp(0.0, 1.0 - sh),
      width: sw,
      height: sh,
      confidence: s.confidence * 0.9,
      strategy: '${name}_tight'));

  // Context
  list.add(CropCoordinates(
      x: (s.center.dx - cW / 2).clamp(0.0, 1.0 - cW),
      y: (s.center.dy - cH / 2).clamp(0.0, 1.0 - cH),
      width: cW,
      height: cH,
      confidence: s.confidence,
      strategy: '${name}_context'));

  return list;
}
