import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';
import 'utils/analyzer_utils.dart';
import 'composition/composition_scoring_logic.dart';

class EnhancedCompositionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'enhanced_composition';
  static const int _analyzerPriority = 750;
  static const double _analyzerWeight = 0.8;

  EnhancedCompositionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 500),
          metadata: const AnalyzerMetadata(
            description: 'Enhanced composition analyzer with rule of thirds, golden ratio, and other composition rules',
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
      final candidates = _generateCandidates(imageSize, targetAspectRatio);

      CropCoordinates? best;
      double bestScore = 0.0;
      for (final c in candidates) {
        final score = CompositionScoringLogic.scoreComposition(c, imageSize, imageData);
        if (score > bestScore) {
          bestScore = score;
          best = c;
        }
      }

      best ??= AnalyzerUtils.getCenterCrop(imageSize, targetAspectRatio, strategyName);
      
      final metrics = CompositionScoringLogic.getDetailedScores(best, imageSize, imageData);
      metrics['composition_score'] = bestScore;
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

  List<CropCoordinates> _generateCandidates(ui.Size size, double aspect) {
    final list = <CropCoordinates>[];
    final cW = AnalyzerUtils.calculateCropWidth(size, aspect);
    final cH = AnalyzerUtils.calculateCropHeight(size, aspect);

    final points = [
      const ui.Offset(1 / 3, 1 / 3), const ui.Offset(2 / 3, 1 / 3), const ui.Offset(1 / 3, 2 / 3), const ui.Offset(2 / 3, 2 / 3),
      const ui.Offset(CompositionScoringLogic.goldenRatio, CompositionScoringLogic.goldenRatio), ui.Offset(1 - CompositionScoringLogic.goldenRatio, CompositionScoringLogic.goldenRatio),
      const ui.Offset(0.25, 0.25), const ui.Offset(0.75, 0.25), const ui.Offset(0.25, 0.75), const ui.Offset(0.75, 0.75),
      const ui.Offset(0.2, 0.8), const ui.Offset(0.8, 0.2), const ui.Offset(0.3, 0.7), const ui.Offset(0.7, 0.3)
    ];

    for (final p in points) {
      list.add(CropCoordinates(x: (p.dx - cW / 2).clamp(0.0, 1.0 - cW), y: (p.dy - cH / 2).clamp(0.0, 1.0 - cH), width: cW, height: cH, confidence: 0.5, strategy: strategyName));
    }
    return list;
  }
}
