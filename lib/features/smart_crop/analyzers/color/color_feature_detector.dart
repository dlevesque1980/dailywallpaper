import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

class HSV {
  final double hue, saturation, value;
  HSV({required this.hue, required this.saturation, required this.value});
}

class VibrantRegion {
  final ui.Offset center;
  final ui.Color color;
  final double saturation, brightness;
  VibrantRegion({required this.center, required this.color, required this.saturation, required this.brightness});
}

class ImageColorAnalysis {
  final List<ui.Color> dominantColors;
  final List<VibrantRegion> vibrantRegions;
  final double averageSaturation, averageBrightness, colorVariety;
  ImageColorAnalysis({required this.dominantColors, required this.vibrantRegions, required this.averageSaturation, required this.averageBrightness, required this.colorVariety});
}

class ColorFeatureDetector {
  static ImageColorAnalysis analyze(ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final counts = <int, int>{};
    final vibrant = <VibrantRegion>[];
    double totalS = 0, totalV = 0;
    int pixels = 0;

    for (int y = 0; y < h; y += 4) {
      for (int x = 0; x < w; x += 4) {
        final idx = (y * w + x) * 4;
        if (idx + 2 >= data.length) continue;
        final r = data[idx], g = data[idx + 1], b = data[idx + 2];
        final q = ((r ~/ 32) << 16) | ((g ~/ 32) << 8) | (b ~/ 32);
        counts[q] = (counts[q] ?? 0) + 1;
        final hsv = rgbToHsv(r, g, b);
        totalS += hsv.saturation; totalV += hsv.value; pixels++;
        if (hsv.saturation > 0.5 && hsv.value > 0.4) {
          vibrant.add(VibrantRegion(center: ui.Offset(x / w, y / h), color: ui.Color.fromARGB(255, r, g, b), saturation: hsv.saturation, brightness: hsv.value));
        }
      }
    }
    final sorted = counts.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final dominant = sorted.take(5).map((e) => ui.Color.fromARGB(255, (e.key >> 16) & 0xFF, (e.key >> 8) & 0xFF, e.key & 0xFF)).toList();
    return ImageColorAnalysis(dominantColors: dominant, vibrantRegions: vibrant, averageSaturation: pixels > 0 ? totalS / pixels : 0, averageBrightness: pixels > 0 ? totalV / pixels : 0, colorVariety: counts.length / math.max(1, pixels ~/ 100));
  }

  static HSV rgbToHsv(int r, int g, int b) {
    final rN = r / 255.0, gN = g / 255.0, bN = b / 255.0;
    final max = math.max(rN, math.max(gN, bN)), min = math.min(rN, math.min(gN, bN)), d = max - min;
    double h = 0;
    if (d != 0) {
      if (max == rN) h = 60 * (((gN - bN) / d) % 6);
      else if (max == gN) h = 60 * (((bN - rN) / d) + 2);
      else h = 60 * (((rN - gN) / d) + 4);
    }
    return HSV(hue: h, saturation: max == 0 ? 0 : d / max, value: max);
  }
}
