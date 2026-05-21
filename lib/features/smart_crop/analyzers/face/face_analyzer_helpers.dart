import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';

class DetectedFace {
  final ui.Offset center;
  final ui.Rect bounds;
  final double confidence;
  final double size;
  final double importance;

  DetectedFace({
    required this.center,
    required this.bounds,
    required this.confidence,
    required this.size,
    required this.importance,
  });
}

/// Top-level function executed in background isolate
List<DetectedFace> performFaceAnalysisIsolate(Map<String, dynamic> params) {
  final ui.Size imageSize = ui.Size(params['imageWidth'] as double, params['imageHeight'] as double);
  final Uint8List imageData = params['imageData'];
  final width = imageSize.width.toInt();
  final height = imageSize.height.toInt();
  final faces = <DetectedFace>[];

  const gridSize = 6;
  final cellWidth = width / gridSize;
  final cellHeight = height / gridSize;

  double getPositionWeight(double x, double y) {
    final distanceFromCenter =
        math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2));
    return math.max(0.4, 1.0 - distanceFromCenter);
  }

  bool isSkinToneSimple(int r, int g, int b) {
    return r > 95 &&
        g > 40 &&
        b > 20 &&
        r > g &&
        g > b &&
        (r - g) > 15 &&
        (r - g) < 100 &&
        r < 250;
  }

  double quickSkinToneCheck(int startX, int endX, int startY, int endY) {
    int skinPixels = 0;
    int totalPixels = 0;
    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        if (x >= width || y >= height) continue;
        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;
        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];
        if (isSkinToneSimple(r, g, b)) {
          skinPixels++;
        }
        totalPixels++;
      }
    }
    return totalPixels > 0 ? skinPixels / totalPixels : 0.0;
  }

  for (int gy = 0; gy < gridSize; gy++) {
    for (int gx = 0; gx < gridSize; gx++) {
      final startX = (gx * cellWidth).round();
      final endX = math.min(((gx + 1) * cellWidth).round(), width);
      final startY = (gy * cellHeight).round();
      final endY = math.min(((gy + 1) * cellHeight).round(), height);

      if (startX >= endX ||
          startY >= endY ||
          startX >= width ||
          startY >= height) {
        continue;
      }

      final skinScore = quickSkinToneCheck(startX, endX, startY, endY);

      if (skinScore > 0.6) {
        final centerX = (startX + endX) / 2 / width;
        final centerY = (startY + endY) / 2 / height;
        final size = math.sqrt((cellWidth * cellHeight) / (width * height));

        faces.add(DetectedFace(
          center: ui.Offset(centerX, centerY),
          bounds: ui.Rect.fromLTWH(startX / width, startY / height,
              (endX - startX) / width, (endY - startY) / height),
          confidence: skinScore,
          size: size,
          importance: skinScore * getPositionWeight(centerX, centerY),
        ));
      }
    }
  }

  faces.sort((a, b) => b.importance.compareTo(a.importance));
  return faces.take(2).toList();
}
