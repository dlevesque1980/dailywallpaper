import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import 'utils/analyzer_utils.dart';
import 'color/color_feature_detector.dart';
import 'color/color_scoring_logic.dart';

class ColorCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'color_analysis';
  static const int _analyzerPriority = 700;
  static const double _analyzerWeight = 0.75;

  ColorCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 400),
          metadata: const AnalyzerMetadata(
            description: 'Analyzes color distribution, harmony, and vibrant areas for optimal cropping',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
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
      final colorAnalysis = ColorFeatureDetector.analyze(imageSize, imageData);
      final candidates = _generateCandidates(imageSize, targetAspectRatio, colorAnalysis);

      CropCoordinates? best;
      double bestScore = 0.0;
      for (final c in candidates) {
        final score = ColorScoringLogic.scoreColorCrop(c, imageSize, imageData, colorAnalysis);
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }

      best ??= AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName);
      
      final metrics = ColorScoringLogic.getDetailedScores(best, imageSize, imageData);
      metrics['color_score'] = bestScore;
      metrics['vibrant_regions_count'] = colorAnalysis.vibrantRegions.length.toDouble();
      metrics['average_saturation'] = colorAnalysis.averageSaturation;
      metrics['average_brightness'] = colorAnalysis.averageBrightness;
      metrics['crop_area_ratio'] = (best.width * best.height) / (imageSize.width * imageSize.height);

      return CropScore(
        coordinates: best,
        score: bestScore,
        strategy: strategyName,
        metrics: metrics,
      );
    } catch (e) {
      return CropScore(
        coordinates: AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName),
        score: 0.3,
        strategy: strategyName,
        metrics: {'error': e.toString()},
      );
    }
  }

  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  List<CropCoordinates> _generateCandidates(ui.Size size, double aspect, ImageColorAnalysis analysis) {
    final list = <CropCoordinates>[];
    final cW = AnalyzerUtils.calculateCropWidth(size, aspect);
    final cH = AnalyzerUtils.calculateCropHeight(size, aspect);

    for (final v in analysis.vibrantRegions.take(5)) {
      list.add(CropCoordinates(x: (v.center.dx - cW / 2).clamp(0.0, 1.0 - cW), y: (v.center.dy - cH / 2).clamp(0.0, 1.0 - cH), width: cW, height: cH, confidence: v.saturation * v.brightness, strategy: '${strategyName}_vibrant'));
    }

    for (final p in [const ui.Offset(0.618, 0.382), const ui.Offset(0.382, 0.618), const ui.Offset(0.3, 0.3), const ui.Offset(0.7, 0.7)]) {
      list.add(CropCoordinates(x: (p.dx - cW / 2).clamp(0.0, 1.0 - cW), y: (p.dy - cH / 2).clamp(0.0, 1.0 - cH), width: cW, height: cH, confidence: 0.5, strategy: '${strategyName}_harmony'));
    }

    list.add(AnalyzerUtils.getCenterCrop(size, aspect, strategyName));
    return list;
  }
}
