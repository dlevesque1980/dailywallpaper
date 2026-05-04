import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import '../utils/analyzer_utils.dart';

class CompositionScoringLogic {
  static const double goldenRatio = 0.618033988749;

  static double scoreComposition(CropCoordinates crop, ui.Size size, Uint8List data) {
    double score = 0.0;
    score += scoreRuleOfThirds(crop) * 0.25;
    score += scoreGoldenRatio(crop) * 0.25;
    score += scoreVisualWeight(crop, size, data) * 0.20;
    score += scoreDynamicSymmetry(crop) * 0.15;
    score += scoreBalance(crop) * 0.15;
    return math.min(1.0, score);
  }

  static Map<String, double> getDetailedScores(CropCoordinates crop, ui.Size size, Uint8List data) {
    return {
      'rule_of_thirds_score': scoreRuleOfThirds(crop),
      'golden_ratio_score': scoreGoldenRatio(crop),
      'visual_weight_score': scoreVisualWeight(crop, size, data),
      'dynamic_symmetry_score': scoreDynamicSymmetry(crop),
      'balance_score': scoreBalance(crop),
    };
  }

  static double scoreRuleOfThirds(CropCoordinates crop) {
    final c = ui.Offset(crop.x + crop.width / 2, crop.y + crop.height / 2);
    final thirds = [const ui.Offset(1/3, 1/3), const ui.Offset(2/3, 1/3), const ui.Offset(1/3, 2/3), const ui.Offset(2/3, 2/3)];
    double minD = thirds.map((p) => (c - p).distance).reduce(math.min);
    return math.max(0.0, 1.0 - minD * 3);
  }

  static double scoreGoldenRatio(CropCoordinates crop) {
    final c = ui.Offset(crop.x + crop.width / 2, crop.y + crop.height / 2);
    final points = [const ui.Offset(goldenRatio, goldenRatio), ui.Offset(1 - goldenRatio, goldenRatio), ui.Offset(goldenRatio, 1 - goldenRatio), ui.Offset(1 - goldenRatio, 1 - goldenRatio)];
    double minD = points.map((p) => (c - p).distance).reduce(math.min);
    return math.max(0.0, 1.0 - minD * 2.5);
  }

  static double scoreVisualWeight(CropCoordinates crop, ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final cL = (crop.x * w).round(), cT = (crop.y * h).round(), cR = ((crop.x + crop.width) * w).round(), cB = ((crop.y + crop.height) * h).round();
    final mX = (cL + cR) ~/ 2, mY = (cT + cB) ~/ 2;
    final qs = [
      _calcWeight(data, w, h, cL, mX, cT, mY), _calcWeight(data, w, h, mX, cR, cT, mY),
      _calcWeight(data, w, h, cL, mX, mY, cB), _calcWeight(data, w, h, mX, cR, mY, cB)
    ];
    final total = qs.reduce((a, b) => a + b);
    if (total == 0) return 0.5;
    final mean = total / 4;
    final variance = qs.map((v) => math.pow(v / total - 0.25, 2)).reduce((a, b) => a + b) / 4;
    return math.max(0.0, 1.0 - (variance - 0.15).abs() * 5);
  }

  static double _calcWeight(Uint8List data, int w, int h, int sX, int eX, int sY, int eY) {
    double total = 0; int count = 0;
    for (int y = sY; y < eY; y += 3) {
      for (int x = sX; x < eX; x += 3) {
        final b = AnalyzerUtils.getPixelBrightness(data, w, x, y);
        if (b >= 0) {
          final idx = (y * w + x) * 4;
          final max = math.max(data[idx], math.max(data[idx + 1], data[idx + 2]));
          final min = math.min(data[idx], math.min(data[idx + 1], data[idx + 2]));
          final s = max == 0 ? 0.0 : (max - min) / max;
          total += (b / 255.0 * 0.7 + s * 0.3); count++;
        }
      }
    }
    return count > 0 ? total / count : 0;
  }

  static double scoreDynamicSymmetry(CropCoordinates crop) {
    final cX = crop.x + crop.width / 2, cY = crop.y + crop.height / 2;
    return math.max(1.0 - (cX + cY - 1.0).abs(), 1.0 - (cX - cY).abs()) * 0.5;
  }

  static double scoreBalance(CropCoordinates crop) {
    double score = 1.0;
    if (crop.x < 0.05) score -= 0.2; if (crop.y < 0.05) score -= 0.2;
    if (crop.x + crop.width > 0.95) score -= 0.2; if (crop.y + crop.height > 0.95) score -= 0.2;
    final dist = (ui.Offset(crop.x + crop.width / 2, crop.y + crop.height / 2) - const ui.Offset(0.5, 0.5)).distance;
    score += math.max(0.0, 1.0 - (dist - 0.1).abs() * 3) * 0.3;
    return math.max(0.0, score);
  }
}
