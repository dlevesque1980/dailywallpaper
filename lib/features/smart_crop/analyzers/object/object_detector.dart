import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../utils/analyzer_utils.dart';

enum ObjectType { highContrast, edgeDense, colorDistinct }

class DetectedObject {
  final ui.Offset center;
  final ui.Rect bounds;
  final double confidence;
  final double size;
  final ObjectType type;
  final double importance;

  DetectedObject({
    required this.center,
    required this.bounds,
    required this.confidence,
    required this.size,
    required this.type,
    required this.importance,
  });
}

class ObjectDetector {
  static List<DetectedObject> detectObjects(ui.Size size, Uint8List data) {
    final w = size.width.toInt(), h = size.height.toInt();
    final list = <DetectedObject>[];
    list.addAll(_detectByContrast(w, h, data));
    list.addAll(_detectByEdges(w, h, data));
    list.addAll(_detectByColor(w, h, data));
    final merged = _merge(list);
    final filtered = merged.where((o) => o.confidence > 0.25 && o.size > 0.01 && o.size < 0.9).toList();
    filtered.sort((a, b) => b.importance.compareTo(a.importance));
    return filtered.take(3).toList();
  }

  static List<DetectedObject> _detectByContrast(int w, int h, Uint8List data) {
    final list = <DetectedObject>[];
    const grid = 8;
    final cW = w / grid, cH = h / grid;
    for (int gy = 0; gy < grid; gy++) {
      for (int gx = 0; gx < grid; gx++) {
        final sX = (gx * cW).round(), eX = math.min(((gx + 1) * cW).round(), w);
        final sY = (gy * cH).round(), eY = math.min(((gy + 1) * cH).round(), h);
        if (sX >= eX || sY >= eY) continue;
        final contrast = _calcContrast(data, w, h, sX, eX, sY, eY);
        if (contrast > 0.4) {
          final cX = (sX + eX) / 2 / w, cY = (sY + eY) / 2 / h;
          final s = math.sqrt((cW * cH) / (w * h));
          list.add(DetectedObject(center: ui.Offset(cX, cY), bounds: ui.Rect.fromLTWH(sX / w, sY / h, (eX - sX) / w, (eY - sY) / h), confidence: contrast, size: s, type: ObjectType.highContrast, importance: contrast * AnalyzerUtils.getPositionWeight(cX, cY) * s));
        }
      }
    }
    return list;
  }

  static double _calcContrast(Uint8List data, int w, int h, int sX, int eX, int sY, int eY) {
    final bs = <int>[];
    for (int y = sY; y < eY; y += 3) {
      for (int x = sX; x < eX; x += 3) {
        final b = AnalyzerUtils.getPixelBrightness(data, w, x, y);
        if (b >= 0) bs.add(b);
      }
    }
    if (bs.length < 4) return 0.0;
    bs.sort();
    return (bs[(bs.length * 3) ~/ 4] - bs[bs.length ~/ 4]) / 255.0;
  }

  static List<DetectedObject> _detectByEdges(int w, int h, Uint8List data) {
    final list = <DetectedObject>[];
    const grid = 6;
    final cW = w / grid, cH = h / grid;
    for (int gy = 0; gy < grid; gy++) {
      for (int gx = 0; gx < grid; gx++) {
        final sX = (gx * cW).round(), eX = math.min(((gx + 1) * cW).round(), w);
        final sY = (gy * cH).round(), eY = math.min(((gy + 1) * cH).round(), h);
        int edges = 0, total = 0;
        for (int y = sY; y < eY - 1; y += 2) {
          for (int x = sX; x < eX - 1; x += 2) {
            final b = AnalyzerUtils.getPixelBrightness(data, w, x, y);
            final r = AnalyzerUtils.getPixelBrightness(data, w, x + 1, y);
            final d = AnalyzerUtils.getPixelBrightness(data, w, x, y + 1);
            if (b >= 0 && r >= 0 && d >= 0) {
              if ((b - r).abs() > 30 || (b - d).abs() > 30) edges++;
              total++;
            }
          }
        }
        final density = total > 0 ? edges / total : 0.0;
        if (density > 0.3) {
          final cX = (sX + eX) / 2 / w, cY = (sY + eY) / 2 / h;
          final s = math.sqrt((cW * cH) / (w * h));
          list.add(DetectedObject(center: ui.Offset(cX, cY), bounds: ui.Rect.fromLTWH(sX / w, sY / h, (eX - sX) / w, (eY - sY) / h), confidence: density, size: s, type: ObjectType.edgeDense, importance: density * AnalyzerUtils.getPositionWeight(cX, cY) * s * 0.8));
        }
      }
    }
    return list;
  }

  static List<DetectedObject> _detectByColor(int w, int h, Uint8List data) {
    final list = <DetectedObject>[];
    const grid = 6;
    final cW = w / grid, cH = h / grid;
    for (int gy = 0; gy < grid; gy++) {
      for (int gx = 0; gx < grid; gx++) {
        final sX = (gx * cW).round(), eX = math.min(((gx + 1) * cW).round(), w);
        final sY = (gy * cH).round(), eY = math.min(((gy + 1) * cH).round(), h);
        final cs = <int>[];
        for (int y = sY; y < eY; y += 4) {
          for (int x = sX; x < eX; x += 4) {
            final idx = (y * w + x) * 4;
            if (idx + 2 < data.length) cs.add(((data[idx] ~/ 32) << 10) | ((data[idx + 1] ~/ 32) << 5) | (data[idx + 2] ~/ 32));
          }
        }
        final variance = cs.isEmpty ? 0.0 : cs.toSet().length / cs.length;
        if (variance > 0.35) {
          final cX = (sX + eX) / 2 / w, cY = (sY + eY) / 2 / h;
          final s = math.sqrt((cW * cH) / (w * h));
          list.add(DetectedObject(center: ui.Offset(cX, cY), bounds: ui.Rect.fromLTWH(sX / w, sY / h, (eX - sX) / w, (eY - sY) / h), confidence: variance, size: s, type: ObjectType.colorDistinct, importance: variance * AnalyzerUtils.getPositionWeight(cX, cY) * s * 0.9));
        }
      }
    }
    return list;
  }

  static List<DetectedObject> _merge(List<DetectedObject> objs) {
    final merged = <DetectedObject>[];
    final processed = List.filled(objs.length, false);
    for (int i = 0; i < objs.length; i++) {
      if (processed[i]) continue;
      final group = <DetectedObject>[objs[i]];
      processed[i] = true;
      for (int j = i + 1; j < objs.length; j++) {
        if (!processed[j] && (objs[i].center - objs[j].center).distance < 0.15) {
          group.add(objs[j]);
          processed[j] = true;
        }
      }
      merged.add(_mergeGroup(group));
    }
    return merged;
  }

  static DetectedObject _mergeGroup(List<DetectedObject> group) {
    if (group.length == 1) return group.first;
    double totalI = 0, wX = 0, wY = 0, minX = 1, minY = 1, maxX = 0, maxY = 0, maxC = 0, totalW = 0;
    ObjectType type = group.first.type;
    for (final o in group) {
      totalI += o.importance;
      final w = math.pow(o.importance, 2.0).toDouble();
      wX += o.center.dx * w; wY += o.center.dy * w; totalW += w;
      minX = math.min(minX, o.bounds.left); minY = math.min(minY, o.bounds.top);
      maxX = math.max(maxX, o.bounds.right); maxY = math.max(maxY, o.bounds.bottom);
      if (o.confidence > maxC) { maxC = o.confidence; type = o.type; }
    }
    return DetectedObject(center: ui.Offset(wX / totalW, wY / totalW), bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY), confidence: maxC, size: (maxX - minX) * (maxY - minY), type: type, importance: totalI);
  }
}
