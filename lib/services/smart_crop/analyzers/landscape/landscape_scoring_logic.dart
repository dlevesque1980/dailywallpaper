import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import '../utils/analyzer_utils.dart';
import 'landscape_feature_detector.dart';

class LandscapeScoringLogic {
  static double scoreLandscapeCrop(CropCoordinates crop, ui.Size imageSize, Uint8List data) {
    double score = 0.0;
    score += _scoreHorizon(crop, imageSize, data) * 0.3;
    score += _scoreSubjects(crop, imageSize, data) * 0.25;
    score += _scoreComplexity(crop, imageSize, data) * 0.2;
    score += _scoreComposition(crop) * 0.15;
    score += _scoreDiversity(crop, imageSize, data) * 0.1;
    return math.min(1.0, score);
  }

  static double _scoreHorizon(CropCoordinates crop, ui.Size imageSize, Uint8List data) {
    final horizonY = LandscapeFeatureDetector.detectHorizon(imageSize, data);
    if (horizonY >= crop.y && horizonY <= crop.y + crop.height) {
      final pos = (horizonY - crop.y) / crop.height;
      return math.max(0.0, 1.0 - math.min((pos - 1/3).abs(), (pos - 2/3).abs()) * 3);
    }
    return 0.6;
  }

  static double _scoreSubjects(CropCoordinates crop, ui.Size imageSize, Uint8List data) {
    final subjects = LandscapeFeatureDetector.detectSubjectAreas(imageSize, data);
    if (subjects.isEmpty) return 0.8;
    int count = subjects.where((s) => s.dx >= crop.x && s.dx <= crop.x + crop.width && s.dy >= crop.y && s.dy <= crop.y + crop.height).length;
    return count / subjects.length;
  }

  static double _scoreComplexity(CropCoordinates crop, ui.Size imageSize, Uint8List data) {
    double total = 0.0;
    int count = 0;
    for (double y = crop.y + 0.1; y < crop.y + crop.height - 0.1; y += 0.2) {
      for (double x = crop.x + 0.1; x < crop.x + crop.width - 0.1; x += 0.2) {
        total += LandscapeFeatureDetector.calculateLocalComplexity(data, imageSize.width.toInt(), imageSize.height.toInt(), (x * imageSize.width).round(), (y * imageSize.height).round(), 15);
        count++;
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  static double _scoreComposition(CropCoordinates crop) {
    final c = ui.Offset(crop.x + crop.width / 2, crop.y + crop.height / 2);
    final thirds = [const ui.Offset(1/3, 1/3), const ui.Offset(2/3, 1/3), const ui.Offset(1/3, 2/3), const ui.Offset(2/3, 2/3)];
    double minD = thirds.map((p) => (c - p).distance).reduce(math.min);
    return math.max(0.0, 1.0 - minD * 2);
  }

  static double _scoreDiversity(CropCoordinates crop, ui.Size imageSize, Uint8List data) {
    final w = imageSize.width.toInt(), h = imageSize.height.toInt();
    final hist = <int, int>{};
    int total = 0;
    for (int y = (crop.y * h).round(); y < ((crop.y + crop.height) * h).round(); y += 8) {
      for (int x = (crop.x * w).round(); x < ((crop.x + crop.width) * w).round(); x += 8) {
        final b = AnalyzerUtils.getPixelBrightness(data, w, x, y);
        if (b >= 0) {
          final bucket = b ~/ 32;
          hist[bucket] = (hist[bucket] ?? 0) + 1;
          total++;
        }
      }
    }
    if (total == 0) return 0.0;
    double entropy = 0.0;
    for (final count in hist.values) {
      final p = count / total;
      if (p > 0) entropy -= p * math.log(p) / math.ln2;
    }
    final maxE = math.log(hist.length) / math.ln2;
    return maxE > 0 ? entropy / maxE : 0.0;
  }
}
