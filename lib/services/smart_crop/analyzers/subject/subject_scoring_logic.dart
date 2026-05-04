import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import '../utils/analyzer_utils.dart';
import 'subject_detector.dart';

class SubjectScoringLogic {
  static double scoreSubjectCrop(CropCoordinates crop, DetectedSubject subject, double maxImp, double targetAspect, ui.Size size) {
    double score = 0.0;
    score += _scoreInclusion(crop, subject) * 0.25;
    score += subject.confidence * _getTypeBonus(subject.type) * 0.15;
    score += _scoreComposition(crop, subject) * 0.15;
    score += _scoreEdgeAvoidance(crop) * 0.05;
    score += (maxImp > 0 ? subject.importance / maxImp : 1.0) * 0.20;
    final cW = AnalyzerUtils.calculateCropWidth(size, targetAspect), cH = AnalyzerUtils.calculateCropHeight(size, targetAspect);
    score += ((crop.width * crop.height) / (cW * cH)) * 0.10;
    return score;
  }

  static double _scoreInclusion(CropCoordinates crop, DetectedSubject subject) {
    final i = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height).intersect(subject.bounds);
    return i.isEmpty ? 0.0 : (i.width * i.height) / (subject.bounds.width * subject.bounds.height);
  }

  static double _getTypeBonus(SubjectType type) {
    switch (type) {
      case SubjectType.circularShape: return 1.2;
      case SubjectType.highContrast: return 1.1;
      default: return 1.0;
    }
  }

  static double _scoreComposition(CropCoordinates crop, DetectedSubject subject) {
    final sx = (subject.center.dx - crop.x) / crop.width, sy = (subject.center.dy - crop.y) / crop.height;
    double bx = 1, by = 1;
    for (final p in [1/3, 2/3]) { bx = math.min(bx, (sx - p).abs()); by = math.min(by, (sy - p).abs()); }
    return (1 - bx) * (1 - by);
  }

  static double _scoreEdgeAvoidance(CropCoordinates crop) {
    double p = 0;
    if (crop.x <= 0.01) p += 0.2; if (crop.y <= 0.01) p += 0.2;
    if (crop.x + crop.width >= 0.99) p += 0.2; if (crop.y + crop.height >= 0.99) p += 0.2;
    return math.max(0.0, 1.0 - p);
  }
}
