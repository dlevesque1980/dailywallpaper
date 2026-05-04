import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../utils/analyzer_utils.dart';

class LandscapeFeatureDetector {
  static double detectHorizon(ui.Size imageSize, Uint8List data) {
    final w = imageSize.width.toInt();
    final h = imageSize.height.toInt();
    final gradients = <double>[];

    for (int y = h ~/ 4; y < (h * 3) ~/ 4; y++) {
      double rowB = 0.0;
      int count = 0;
      for (int x = 0; x < w; x += 4) {
        final b = AnalyzerUtils.getPixelBrightness(data, w, x, y);
        if (b >= 0) {
          rowB += b;
          count++;
        }
      }
      if (count > 0) gradients.add(rowB / count);
    }

    double maxG = 0.0;
    int index = gradients.length ~/ 2;
    for (int i = 1; i < gradients.length - 1; i++) {
      final g = (gradients[i + 1] - gradients[i - 1]).abs();
      if (g > maxG) {
        maxG = g;
        index = i;
      }
    }
    return ((h ~/ 4) + index) / h;
  }

  static List<ui.Offset> detectSubjectAreas(ui.Size imageSize, Uint8List data) {
    final w = imageSize.width.toInt();
    final h = imageSize.height.toInt();
    final subjects = <ui.Offset>[];
    for (int gy = 0; gy < 6; gy++) {
      for (int gx = 0; gx < 8; gx++) {
        final sX = (gx * w) ~/ 8, eX = ((gx + 1) * w) ~/ 8;
        final sY = (gy * h) ~/ 6, eY = ((gy + 1) * h) ~/ 6;
        if (_calculateColorVariance(data, w, sX, eX, sY, eY) > 800) {
          subjects.add(ui.Offset((sX + eX) / 2 / w, (sY + eY) / 2 / h));
        }
      }
    }
    return subjects;
  }

  static double _calculateColorVariance(Uint8List data, int w, int sX, int eX, int sY, int eY) {
    final grays = <int>[];
    for (int y = sY; y < eY; y += 2) {
      for (int x = sX; x < eX; x += 2) {
        final b = AnalyzerUtils.getPixelBrightness(data, w, x, y);
        if (b >= 0) grays.add(b);
      }
    }
    if (grays.isEmpty) return 0.0;
    final mean = grays.reduce((a, b) => a + b) / grays.length;
    return grays.map((c) => math.pow(c - mean, 2)).reduce((a, b) => a + b) / grays.length;
  }

  static double calculateLocalComplexity(Uint8List data, int w, int h, int cx, int cy, int r) {
    final samples = <int>[];
    for (int dy = -r; dy <= r; dy += 4) {
      for (int dx = -r; dx <= r; dx += 4) {
        final b = AnalyzerUtils.getPixelBrightness(data, w, cx + dx, cy + dy);
        if (b >= 0) samples.add(b);
      }
    }
    if (samples.isEmpty) return 0.0;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / samples.length;
    return math.min(1.0, math.sqrt(variance) / 128.0);
  }
}
