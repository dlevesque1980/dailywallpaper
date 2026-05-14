import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

enum BirdPartType { head, body, plumage }

class DetectedBird {
  final ui.Offset center;
  final ui.Rect bounds;
  final BirdPartType type;
  final double confidence;
  final double size;
  final bool hasHead;
  final bool hasBeak;

  DetectedBird({
    required this.center,
    required this.bounds,
    required this.type,
    required this.confidence,
    required this.size,
    required this.hasHead,
    required this.hasBeak,
  });
}

class BirdFeatureDetector {
  static List<DetectedBird> detectBirds(ui.Size imageSize, Uint8List imageData) {
    final birds = <DetectedBird>[];
    birds.addAll(_detectBirdHeads(imageSize, imageData));
    birds.addAll(_detectBirdBodies(imageSize, imageData));
    birds.addAll(_detectByPlumageColor(imageSize, imageData));
    
    final merged = _mergeBirdParts(birds);
    final valid = merged.where((bird) => bird.confidence > 0.75).toList();
    valid.sort((a, b) => b.confidence.compareTo(a.confidence));
    return valid.take(2).toList();
  }

  static List<DetectedBird> _detectBirdHeads(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final heads = <DetectedBird>[];
    final headSizes = [8, 12, 16, 24, 32];

    for (final headSize in headSizes) {
      final step = headSize ~/ 2;
      int checks = 0;
      for (int y = headSize; y < height - headSize && checks < 200; y += step) {
        for (int x = headSize; x < width - headSize && checks < 200; x += step) {
          checks++;
          final score = _calculateHeadScore(imageData, width, x, y, headSize);
          if (score > 0.8) {
            final beak = _detectBeak(imageData, width, x, y, headSize);
            final total = score * 0.7 + beak * 0.3;
            if (total > 0.75) {
              heads.add(DetectedBird(
                center: ui.Offset(x / width, y / height),
                bounds: ui.Rect.fromLTWH((x - headSize) / width, (y - headSize) / height, (headSize * 2) / width, (headSize * 2) / height),
                type: BirdPartType.head,
                confidence: total,
                size: (headSize * 2) / math.min(width, height),
                hasHead: true,
                hasBeak: beak > 0.2,
              ));
            }
          }
        }
      }
    }
    return heads;
  }

  static double _calculateHeadScore(Uint8List data, int w, int cx, int cy, int r) {
    final circularity = _calculateCircularity(data, w, cx, cy, r);
    final contrast = _calculateHeadContrast(data, w, cx, cy, r);
    final texture = _calculateFeatherTexture(data, w, cx, cy, r);
    return (circularity * 0.4 + contrast * 0.4 + texture * 0.2);
  }

  static double _calculateCircularity(Uint8List data, int w, int cx, int cy, int r) {
    final centerB = _getPixelBrightness(data, w, cx, cy);
    if (centerB < 0) return 0.0;
    final edgeBs = <int>[];
    double totalV = 0.0;
    for (int a = 0; a < 360; a += 20) {
      final rad = a * math.pi / 180;
      final ex = cx + (r * math.cos(rad)).round();
      final ey = cy + (r * math.sin(rad)).round();
      final eb = _getPixelBrightness(data, w, ex, ey);
      if (eb >= 0) {
        totalV += (centerB - eb).abs();
        edgeBs.add(eb);
      }
    }
    if (edgeBs.length < 10) return 0.0;
    final mean = edgeBs.reduce((a, b) => a + b) / edgeBs.length;
    final variance = edgeBs.map((b) => math.pow(b - mean, 2)).reduce((a, b) => a + b) / edgeBs.length;
    final consistency = math.max(0.0, 1.0 - math.sqrt(variance) / 64.0);
    return (math.min(1.0, (totalV / edgeBs.length) / 128.0) * 0.6 + consistency * 0.4);
  }

  static double _calculateHeadContrast(Uint8List data, int w, int cx, int cy, int r) {
    final hB = _getRegionBrightness(data, w, cx, cy, r);
    final bB = _getRegionBrightness(data, w, cx, cy, r * 2) - hB;
    return math.min(1.0, (hB - bB).abs() / 255.0);
  }

  static double _calculateFeatherTexture(Uint8List data, int w, int cx, int cy, int r) {
    final samples = <int>[];
    for (int dy = -r ~/ 2; dy <= r ~/ 2; dy += 2) {
      for (int dx = -r ~/ 2; dx <= r ~/ 2; dx += 2) {
        final b = _getPixelBrightness(data, w, cx + dx, cy + dy);
        if (b >= 0) samples.add(b);
      }
    }
    if (samples.length < 4) return 0.0;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / samples.length;
    return math.min(1.0, math.sqrt(variance) / 64.0);
  }

  static double _detectBeak(Uint8List data, int w, int hX, int hY, int hR) {
    double best = 0.0;
    for (int a = 0; a < 360; a += 30) {
      final rad = a * math.pi / 180;
      final dist = hR * 1.3;
      final score = _calculateBeakScore(data, w, (hX + dist * math.cos(rad)).round(), (hY + dist * math.sin(rad)).round(), hR ~/ 3);
      best = math.max(best, score);
    }
    return best;
  }

  static double _calculateBeakScore(Uint8List data, int w, int bX, int bY, int bS) {
    final bB = _getRegionBrightness(data, w, bX, bY, bS);
    final sB = _getRegionBrightness(data, w, bX, bY, bS * 2) - bB;
    final darkness = math.max(0.0, (sB - bB) / 255.0);
    final hV = _getDirectionalVariance(data, w, bX, bY, bS, true);
    final vV = _getDirectionalVariance(data, w, bX, bY, bS, false);
    final asymmetry = (hV - vV).abs() / math.max(hV, vV);
    return (darkness * 0.6 + math.min(1.0, asymmetry) * 0.4);
  }

  static List<DetectedBird> _detectBirdBodies(ui.Size imageSize, Uint8List data) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final bodies = <DetectedBird>[];
    final bodySizes = [20, 30, 40, 60];

    for (final bSize in bodySizes) {
      final step = bSize ~/ 3;
      int checks = 0;
      for (int y = bSize; y < height - bSize && checks < 150; y += step) {
        for (int x = bSize; x < width - bSize && checks < 150; x += step) {
          checks++;
          final hV = _getDirectionalVariance(data, width, x, y, bSize, true);
          final vV = _getDirectionalVariance(data, width, x, y, bSize, false);
          final elongation = math.min(1.0, (math.max(hV, vV) / math.min(hV, vV) - 1.0) / 2.0);
          final score = (elongation * 0.5 + _calculateFeatherTexture(data, width, x, y, bSize) * 0.3 + _calculateHeadContrast(data, width, x, y, bSize) * 0.2);
          if (score > 0.8) {
            bodies.add(DetectedBird(
              center: ui.Offset(x / width, y / height),
              bounds: ui.Rect.fromLTWH((x - bSize) / width, (y - bSize) / height, (bSize * 2) / width, (bSize * 2) / height),
              type: BirdPartType.body,
              confidence: score,
              size: (bSize * 2) / math.min(width, height),
              hasHead: false,
              hasBeak: false,
            ));
          }
        }
      }
    }
    return bodies;
  }

  static List<DetectedBird> _detectByPlumageColor(ui.Size imageSize, Uint8List data) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final colorBirds = <DetectedBird>[];
    const regionSize = 24;
    final step = regionSize ~/ 2;
    int checks = 0;

    for (int y = regionSize; y < height - regionSize && checks < 100; y += step) {
      for (int x = regionSize; x < width - regionSize && checks < 100; x += step) {
        checks++;
        double totalSat = 0.0;
        int count = 0;
        for (int dy = -regionSize ~/ 2; dy <= regionSize ~/ 2; dy += 3) {
          for (int dx = -regionSize ~/ 2; dx <= regionSize ~/ 2; dx += 3) {
            final c = _getPixelColor(data, width, x + dx, y + dy);
            if (c != null) {
              final max = math.max(c.red, math.max(c.green, c.blue));
              final min = math.min(c.red, math.min(c.green, c.blue));
              totalSat += (max == 0) ? 0 : (max - min) / max;
              count++;
            }
          }
        }
        final score = count == 0 ? 0.0 : math.min(1.0, (totalSat / count) * 1.5);
        if (score > 0.85) {
          colorBirds.add(DetectedBird(
            center: ui.Offset(x / width, y / height),
            bounds: ui.Rect.fromLTWH((x - regionSize) / width, (y - regionSize) / height, (regionSize * 2) / width, (regionSize * 2) / height),
            type: BirdPartType.plumage,
            confidence: score,
            size: (regionSize * 2) / math.min(width, height),
            hasHead: false,
            hasBeak: false,
          ));
        }
      }
    }
    return colorBirds;
  }

  static List<DetectedBird> _mergeBirdParts(List<DetectedBird> parts) {
    final merged = <DetectedBird>[];
    final processed = List.filled(parts.length, false);
    for (int i = 0; i < parts.length; i++) {
      if (processed[i]) continue;
      final group = <DetectedBird>[parts[i]];
      processed[i] = true;
      for (int j = i + 1; j < parts.length; j++) {
        if (!processed[j] && (parts[i].center - parts[j].center).distance < 0.2) {
          group.add(parts[j]);
          processed[j] = true;
        }
      }
      merged.add(_mergeGroup(group));
    }
    return merged;
  }

  static DetectedBird _mergeGroup(List<DetectedBird> group) {
    if (group.length == 1) return group.first;
    double totalConf = 0, wX = 0, wY = 0, minX = 1, minY = 1, maxX = 0, maxY = 0;
    bool hasH = false, hasB = false;
    BirdPartType bType = group.first.type;
    for (final p in group) {
      totalConf += p.confidence;
      wX += p.center.dx * p.confidence;
      wY += p.center.dy * p.confidence;
      minX = math.min(minX, p.bounds.left);
      minY = math.min(minY, p.bounds.top);
      maxX = math.max(maxX, p.bounds.right);
      maxY = math.max(maxY, p.bounds.bottom);
      if (p.hasHead) hasH = true;
      if (p.hasBeak) hasB = true;
      if (p.type == BirdPartType.head) bType = BirdPartType.head;
    }
    return DetectedBird(
      center: ui.Offset(wX / totalConf, wY / totalConf),
      bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY),
      type: bType,
      confidence: totalConf / group.length,
      size: (maxX - minX) * (maxY - minY),
      hasHead: hasH,
      hasBeak: hasB,
    );
  }

  static int _getPixelBrightness(Uint8List data, int w, int x, int y) {
    final idx = (y * w + x) * 4;
    if (idx < 0 || idx + 2 >= data.length) return -1;
    return (data[idx] * 0.299 + data[idx + 1] * 0.587 + data[idx + 2] * 0.114).round();
  }

  static double _getRegionBrightness(Uint8List data, int w, int cx, int cy, int r) {
    double sum = 0;
    int count = 0;
    for (int dy = -r; dy <= r; dy++) {
      for (int dx = -r; dx <= r; dx++) {
        final b = _getPixelBrightness(data, w, cx + dx, cy + dy);
        if (b >= 0) {
          sum += b;
          count++;
        }
      }
    }
    return count == 0 ? 0 : sum / count;
  }

  static double _getDirectionalVariance(Uint8List data, int w, int cx, int cy, int size, bool horizontal) {
    final samples = <int>[];
    for (int i = -size; i <= size; i++) {
      final b = horizontal ? _getPixelBrightness(data, w, cx + i, cy) : _getPixelBrightness(data, w, cx, cy + i);
      if (b >= 0) samples.add(b);
    }
    if (samples.length < 2) return 1.0;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    return samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / samples.length;
  }

  static ui.Color? _getPixelColor(Uint8List data, int w, int x, int y) {
    final idx = (y * w + x) * 4;
    if (idx < 0 || idx + 3 >= data.length) return null;
    return ui.Color.fromARGB(data[idx + 3], data[idx], data[idx + 1], data[idx + 2]);
  }
}
