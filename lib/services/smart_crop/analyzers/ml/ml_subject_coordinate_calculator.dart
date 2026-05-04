import 'dart:ui' as ui;
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import '../../cache/ml_subject_cache.dart' show SubjectBounds;

class MlSubjectCoordinateCalculator {
  static CropCoordinates calculateCrop({
    required SubjectBounds bounds,
    required ui.Size imageSize,
    required double targetAspectRatio,
    required String strategyName,
  }) {
    final cropWidth = _calcCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calcCropHeight(imageSize, targetAspectRatio);

    final subjectCenterX = bounds.x + bounds.width / 2;
    final subjectCenterY = bounds.y + bounds.height / 2;

    final cropX = (subjectCenterX - cropWidth / 2).clamp(0.0, 1.0 - cropWidth);
    final cropY = (subjectCenterY - cropHeight / 2).clamp(0.0, 1.0 - cropHeight);

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.9,
      strategy: strategyName,
      subjectBounds: ui.Rect.fromLTWH(bounds.x, bounds.y, bounds.width, bounds.height),
    );
  }

  static double _calcCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspectRatio ? 1.0 : targetAspectRatio / imageAspectRatio;
  }

  static double _calcCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspectRatio ? 1.0 : imageAspectRatio / targetAspectRatio;
  }
}
