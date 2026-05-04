import 'dart:ui' as ui;
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/utils/subject_fit_checker.dart';

class CropPostProcessor {
  CropCoordinates postProcess({
    required CropCoordinates bestCrop,
    required List<CropScore> allScores,
    required ui.Image image,
    required ui.Size targetSize,
    required CropSettings settings,
  }) {
    var result = bestCrop;

    // 1. Subject Fit Scaling
    if (settings.enableSubjectScaling) {
      result = _applySubjectScaling(result, allScores, image, targetSize, settings);
    }

    // 2. Letterbox Expansion
    if (settings.allowLetterbox) {
      result = _applyLetterboxExpansion(result, image);
    }

    return result;
  }

  CropCoordinates _applySubjectScaling(
    CropCoordinates bestCrop,
    List<CropScore> allScores,
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) {
    try {
      final originalScore = allScores.firstWhere(
          (s) => s.coordinates.strategy == bestCrop.strategy,
          orElse: () => allScores.first);
      final metrics = originalScore.metrics;

      if (metrics.containsKey('subject_x') &&
          metrics.containsKey('subject_y') &&
          metrics.containsKey('subject_width') &&
          metrics.containsKey('subject_height')) {
        final subjectBounds = ui.Rect.fromLTWH(
            metrics['subject_x']!,
            metrics['subject_y']!,
            metrics['subject_width']!,
            metrics['subject_height']!);

        final fitResult = SubjectFitChecker.checkSubjectFit(
          bestCrop,
          subjectBounds,
          ui.Size(image.width.toDouble(), image.height.toDouble()),
          targetSize,
          minCoverage: settings.minSubjectCoverage,
          maxScale: settings.maxScaleFactor,
          allowLetterbox: settings.allowLetterbox,
        );

        if (fitResult.needsScaling) {
          return fitResult.adjustedCrop;
        }
      }
    } catch (e) {
      // Ignore scaling errors
    }
    return bestCrop;
  }

  CropCoordinates _applyLetterboxExpansion(CropCoordinates bestCrop, ui.Image image) {
    try {
      final imageAspect = image.width / image.height;
      if (imageAspect > 1.3) {
        const targetLetterboxWidth = 0.50;
        if (bestCrop.width < targetLetterboxWidth) {
          final cropCenterX = bestCrop.x + bestCrop.width / 2;
          final newX = (cropCenterX - targetLetterboxWidth / 2).clamp(0.0, 1.0 - targetLetterboxWidth);
          return bestCrop.copyWith(
            x: newX,
            width: targetLetterboxWidth,
            strategy: '${bestCrop.strategy}_letterbox',
          );
        }
      }
    } catch (e) {
      // Ignore
    }
    return bestCrop;
  }
}
