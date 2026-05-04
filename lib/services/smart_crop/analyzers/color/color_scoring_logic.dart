import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'color_feature_detector.dart';

class ColorScoringLogic {
  static double scoreColorCrop(CropCoordinates crop, ui.Size size, Uint8List data, ImageColorAnalysis analysis) {
    final vibrancy = scoreVibrancy(crop, size, data);
    if (vibrancy < 0.05) return 0.0;

    double score = 0.0;
    score += vibrancy * 0.4;
    score += scoreHarmony(crop, size, data) * 0.3;
    score += scoreDistribution(crop, size, data) * 0.2;
    score += scoreContrast(crop, size, data) * 0.1;
    return math.min(1.0, score);
  }

  static Map<String, double> getDetailedScores(CropCoordinates crop, ui.Size size, Uint8List data) {
    return {
      'color_vibrancy_score': scoreVibrancy(crop, size, data),
      'color_harmony_score': scoreHarmony(crop, size, data),
      'color_distribution_score': scoreDistribution(crop, size, data),
      'color_contrast_score': scoreContrast(crop, size, data),
    };
  }

  static double scoreVibrancy(CropCoordinates crop, ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    double total = 0; int count = 0;
    for (int y = (crop.y * h).round(); y < ((crop.y + crop.height) * h).round(); y += 3) {
      for (int x = (crop.x * w).round(); x < ((crop.x + crop.width) * w).round(); x += 3) {
        if (x < w && y < h) {
          final idx = (y * w + x) * 4;
          if (idx + 2 < data.length) {
            final hsv = ColorFeatureDetector.rgbToHsv(data[idx], data[idx + 1], data[idx + 2]);
            total += hsv.saturation * hsv.value; count++;
          }
        }
      }
    }
    return count > 0 ? total / count : 0.0;
  }

  static double scoreHarmony(CropCoordinates crop, ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final hues = <double>[];
    for (int y = (crop.y * h).round(); y < ((crop.y + crop.height) * h).round(); y += 5) {
      for (int x = (crop.x * w).round(); x < ((crop.x + crop.width) * w).round(); x += 5) {
        if (x < w && y < h) {
          final idx = (y * w + x) * 4;
          if (idx + 2 < data.length) hues.add(ColorFeatureDetector.rgbToHsv(data[idx], data[idx + 1], data[idx + 2]).hue);
        }
      }
    }
    if (hues.isEmpty) return 0.5;
    double score = 0; int comps = 0;
    for (int i = 0; i < hues.length && comps < 50; i += 10) {
      for (int j = i + 10; j < hues.length && comps < 50; j += 10) {
        final diff = math.min((hues[i] - hues[j]).abs(), 360 - (hues[i] - hues[j]).abs());
        if (diff < 30) score += 1.0;
        else if (diff > 150 && diff < 210) score += 0.8;
        else if (diff > 110 && diff < 130) score += 0.6;
        else score += 0.2;
        comps++;
      }
    }
    return comps > 0 ? score / comps : 0.5;
  }

  static double scoreDistribution(CropCoordinates crop, ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final hist = <int, int>{}; int total = 0;
    for (int y = (crop.y * h).round(); y < ((crop.y + crop.height) * h).round(); y += 4) {
      for (int x = (crop.x * w).round(); x < ((crop.x + crop.width) * w).round(); x += 4) {
        if (x < w && y < h) {
          final idx = (y * w + x) * 4;
          if (idx + 2 < data.length) {
            final q = ((data[idx] ~/ 32) << 16) | ((data[idx + 1] ~/ 32) << 8) | (data[idx + 2] ~/ 32);
            hist[q] = (hist[q] ?? 0) + 1; total++;
          }
        }
      }
    }
    if (total == 0) return 0.0;
    double entropy = 0;
    for (final c in hist.values) {
      final p = c / total;
      if (p > 0) entropy -= p * math.log(p) / math.ln2;
    }
    final maxE = math.log(hist.length) / math.ln2;
    return 1.0 - ((maxE > 0 ? entropy / maxE : 0.0) - 0.7).abs();
  }

  static double scoreContrast(CropCoordinates crop, ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final bs = <double>[];
    for (int y = (crop.y * h).round(); y < ((crop.y + crop.height) * h).round(); y += 5) {
      for (int x = (crop.x * w).round(); x < ((crop.x + crop.width) * w).round(); x += 5) {
        if (x < w && y < h) {
          final idx = (y * w + x) * 4;
          if (idx + 2 < data.length) bs.add((0.299 * data[idx] + 0.587 * data[idx + 1] + 0.114 * data[idx + 2]) / 255.0);
        }
      }
    }
    if (bs.length < 4) return 0.0;
    bs.sort();
    return math.min(1.0, (bs[(bs.length * 3) ~/ 4] - bs[bs.length ~/ 4]) * 2);
  }
}
