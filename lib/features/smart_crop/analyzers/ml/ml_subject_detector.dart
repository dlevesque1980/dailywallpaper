import 'dart:math' as math;
import '../../cache/ml_subject_cache.dart' show SubjectBounds;

class MlSubjectDetectorResult {
  final SubjectBounds bounds;
  final double confidence;
  MlSubjectDetectorResult(this.bounds, this.confidence);
}

class MlSubjectDetector {
  static MlSubjectDetectorResult? detectFromMask(Map<String, dynamic> params) {
    final List<double>? mask = params['mask'];
    final int width = params['width'];
    final int height = params['height'];

    if (mask == null || mask.isEmpty || mask.length != width * height) return null;

    int minX = width, minY = height, maxX = 0, maxY = 0;
    bool found = false;
    double weightedSumX = 0.0, weightedSumY = 0.0, totalWeight = 0.0, sumConfidence = 0.0;
    int foregroundPixels = 0;

    for (int y = 0; y < height; y++) {
      for (int x = 0; x < width; x++) {
        final confidence = mask[y * width + x];
        if (confidence > 0.5) {
          if (x < minX) minX = x;
          if (y < minY) minY = y;
          if (x > maxX) maxX = x;
          if (y > maxY) maxY = y;
          found = true;

          final w = confidence * confidence;
          weightedSumX += x * w;
          weightedSumY += y * w;
          totalWeight += w;
          sumConfidence += confidence;
          foregroundPixels++;
        }
      }
    }

    if (!found) return null;

    final normMinX = minX / width;
    final normMinY = minY / height;
    final normMaxX = (maxX + 1) / width;
    final normMaxY = (maxY + 1) / height;
    final normBoundsW = normMaxX - normMinX;
    final normBoundsH = normMaxY - normMinY;

    final centroidX = totalWeight > 0 ? (weightedSumX / totalWeight) / width : normMinX + normBoundsW / 2;
    final centroidY = totalWeight > 0 ? (weightedSumY / totalWeight) / height : normMinY + normBoundsH / 2;

    final halfW = math.min(normBoundsW / 2, normBoundsW * 0.60);
    final halfH = math.min(normBoundsH / 2, normBoundsH * 0.60);

    final tightMinX = math.max(normMinX, centroidX - halfW);
    final tightMinY = math.max(normMinY, centroidY - halfH);
    final tightMaxX = math.min(normMaxX, centroidX + halfW);
    final tightMaxY = math.min(normMaxY, centroidY + halfH);

    final bounds = SubjectBounds(
      x: tightMinX,
      y: tightMinY,
      width: tightMaxX - tightMinX,
      height: tightMaxY - tightMinY,
    );

    final avgConfidence = sumConfidence / foregroundPixels;
    double sizeMultiplier = 1.0;
    final area = normBoundsW * normBoundsH;
    if (area < 0.01) sizeMultiplier = 0.3;
    else if (area < 0.04) sizeMultiplier = 0.7;
    else if (area > 0.85) sizeMultiplier = 0.6;

    double edgePenalty = 1.0;
    if (normMinX < 0.01 || normMaxX > 0.99 || normMinY < 0.01 || normMaxY > 0.99) {
      edgePenalty = area < 0.1 ? 0.7 : 0.9;
    }

    final finalConfidence = (avgConfidence * sizeMultiplier * edgePenalty).clamp(0.0, 1.0);
    return MlSubjectDetectorResult(bounds, finalConfidence);
  }
}
