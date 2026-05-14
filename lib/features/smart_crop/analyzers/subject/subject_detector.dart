import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../utils/analyzer_utils.dart';

enum SubjectType { highContrast, colorDistinct, circularShape }

class DetectedSubject {
  final ui.Offset center;
  final ui.Rect bounds;
  final SubjectType type;
  final double confidence, importance;
  DetectedSubject({required this.center, required this.bounds, required this.type, required this.confidence, required this.importance});
}

class SubjectDetector {
  static List<DetectedSubject> detectSubjects(ui.Size size, Uint8List data) {
    final list = <DetectedSubject>[];
    list.addAll(_detectByContrast(size, data));
    list.addAll(_detectByColor(size, data));
    list.addAll(_detectByShape(size, data));
    final merged = _merge(list);
    merged.sort((a, b) => b.importance.compareTo(a.importance));
    return merged.take(5).toList();
  }

  static List<DetectedSubject> _detectByContrast(ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final list = <DetectedSubject>[];
    const grid = 16;
    final cW = w / grid, cH = h / grid;
    for (int gy = 0; gy < grid; gy++) {
      for (int gx = 0; gx < grid; gx++) {
        final sX = (gx * cW).round(), eX = ((gx + 1) * cW).round(), sY = (gy * cH).round(), eY = ((gy + 1) * cH).round();
        final contrast = _calcContrast(data, w, sX, eX, sY, eY);
        if (contrast > 0.25) {
          final cX = (sX + eX) / 2 / w, cY = (sY + eY) / 2 / h;
          final s = math.sqrt((cW * cH) / (w * h));
          list.add(DetectedSubject(center: ui.Offset(cX, cY), bounds: ui.Rect.fromLTWH(sX / w, sY / h, (eX - sX) / w, (eY - sY) / h), type: SubjectType.highContrast, confidence: contrast, importance: contrast * AnalyzerUtils.getPositionWeight(cX, cY) * s));
        }
      }
    }
    return list;
  }

  static double _calcContrast(Uint8List data, int w, int sX, int eX, int sY, int eY) {
    final ps = <int>[];
    for (int y = sY; y < eY; y += 2) {
      for (int x = sX; x < eX; x += 2) {
        final b = AnalyzerUtils.getPixelBrightness(data, w, x, y);
        if (b >= 0) ps.add(b);
      }
    }
    if (ps.length < 4) return 0.0;
    ps.sort();
    return (ps[(ps.length * 3) ~/ 4] - ps[ps.length ~/ 4]) / 255.0;
  }

  static List<DetectedSubject> _detectByColor(ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final list = <DetectedSubject>[];
    const rSize = 32;
    for (int ry = 0; ry < h ~/ rSize; ry++) {
      for (int rx = 0; rx < w ~/ rSize; rx++) {
        final sX = rx * rSize, eX = math.min((rx + 1) * rSize, w), sY = ry * rSize, eY = math.min((ry + 1) * rSize, h);
        final dom = _getDomColor(data, w, sX, eX, sY, eY);
        final distinct = _calcDistinct(dom, data, w, h);
        if (distinct > 0.3) {
          final s = (eX - sX) * (eY - sY) / (w * h);
          final cX = (sX + eX) / 2 / w, cY = (sY + eY) / 2 / h;
          list.add(DetectedSubject(center: ui.Offset(cX, cY), bounds: ui.Rect.fromLTWH(sX / w, sY / h, (eX - sX) / w, (eY - sY) / h), type: SubjectType.colorDistinct, confidence: distinct, importance: distinct * s * AnalyzerUtils.getPositionWeight(cX, cY)));
        }
      }
    }
    return list;
  }

  static ui.Color _getDomColor(Uint8List data, int w, int sX, int eX, int sY, int eY) {
    int r = 0, g = 0, b = 0, c = 0;
    for (int y = sY; y < eY; y += 2) {
      for (int x = sX; x < eX; x += 2) {
        final idx = (y * w + x) * 4;
        if (idx + 2 < data.length) { r += data[idx]; g += data[idx + 1]; b += data[idx + 2]; c++; }
      }
    }
    return c == 0 ? const ui.Color(0xFF808080) : ui.Color.fromARGB(255, r ~/ c, g ~/ c, b ~/ c);
  }

  static double _calcDistinct(ui.Color col, Uint8List data, int w, int h) {
    int sim = 0, tot = 0;
    for (int y = 0; y < h; y += 8) {
      for (int x = 0; x < w; x += 8) {
        final idx = (y * w + x) * 4;
        if (idx + 2 < data.length) {
          final d = math.sqrt(math.pow(data[idx] - (col.r * 255).round(), 2) + math.pow(data[idx+1] - (col.g * 255).round(), 2) + math.pow(data[idx+2] - (col.b * 255).round(), 2));
          if (d < 50) sim++; tot++;
        }
      }
    }
    return tot == 0 ? 0 : 1.0 - (sim / tot);
  }

  static List<DetectedSubject> _detectByShape(ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final list = <DetectedSubject>[];
    for (final scale in [16, 24, 32, 48]) {
      final step = scale ~/ 2;
      for (int y = scale; y < h - scale; y += step) {
        for (int x = scale; x < w - scale; x += step) {
          final circ = _calcCirc(data, w, x, y, scale);
          if (circ > 0.3) {
            list.add(DetectedSubject(center: ui.Offset(x / w, y / h), bounds: ui.Rect.fromLTWH((x - scale) / w, (y - scale) / h, (scale * 2) / w, (scale * 2) / h), type: SubjectType.circularShape, confidence: circ, importance: circ * (scale * 2 / math.min(w, h)) * AnalyzerUtils.getPositionWeight(x / w, y / h) * 1.2));
          }
        }
      }
    }
    return list;
  }

  static double _calcCirc(Uint8List data, int w, int cx, int cy, int r) {
    final centerB = AnalyzerUtils.getPixelBrightness(data, w, cx, cy);
    if (centerB < 0) return 0.0;
    final edges = <int>[];
    for (int a = 0; a < 360; a += 15) {
      final rad = a * math.pi / 180;
      final eb = AnalyzerUtils.getPixelBrightness(data, w, cx + (r * math.cos(rad)).round(), cy + (r * math.sin(rad)).round());
      if (eb >= 0) edges.add(eb);
    }
    if (edges.isEmpty) return 0.0;
    final mean = edges.reduce((a, b) => a + b) / edges.length;
    final varB = edges.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / edges.length;
    return (centerB - mean).abs() / 255.0 * (1.0 - math.min(1.0, varB / (255 * 255)));
  }

  static List<DetectedSubject> _merge(List<DetectedSubject> list) {
    final merged = <DetectedSubject>[];
    final processed = List.filled(list.length, false);
    for (int i = 0; i < list.length; i++) {
      if (processed[i]) continue;
      final group = <DetectedSubject>[list[i]]; processed[i] = true;
      for (int j = i + 1; j < list.length; j++) {
        if (!processed[j] && (list[i].center - list[j].center).distance < 0.15) { group.add(list[j]); processed[j] = true; }
      }
      merged.add(_mergeGroup(group));
    }
    return merged;
  }

  static DetectedSubject _mergeGroup(List<DetectedSubject> group) {
    if (group.length == 1) return group.first;
    double totalI = 0, wX = 0, wY = 0, totalW = 0, minX = 1, minY = 1, maxX = 0, maxY = 0, maxC = 0;
    SubjectType type = group.first.type;
    for (final s in group) {
      totalI += s.importance; final w = math.pow(s.importance, 2.0);
      wX += s.center.dx * w; wY += s.center.dy * w; totalW += w;
      minX = math.min(minX, s.bounds.left); minY = math.min(minY, s.bounds.top);
      maxX = math.max(maxX, s.bounds.right); maxY = math.max(maxY, s.bounds.bottom);
      if (s.confidence > maxC) { maxC = s.confidence; type = s.type; }
    }
    return DetectedSubject(center: ui.Offset(wX / totalW, wY / totalW), bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY), type: type, confidence: maxC, importance: totalI);
  }
}
