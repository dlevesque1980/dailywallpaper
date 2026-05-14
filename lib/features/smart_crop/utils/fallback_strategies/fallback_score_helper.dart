import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/crop_coordinates.dart';

class FallbackScoreHelper {
  static double scoreCrop({
    required CropCoordinates crop,
    required ui.Size targetSize,
    required String strategyType,
  }) {
    double score = 0.5;

    final targetAspectRatio = targetSize.width / targetSize.height;
    final cropAspectRatio = crop.width / crop.height;
    final aspectRatioDiff = (targetAspectRatio - cropAspectRatio).abs();

    if (aspectRatioDiff < 0.1) {
      score += 0.2;
    } else if (aspectRatioDiff < 0.3) {
      score += 0.1;
    }

    if (strategyType != 'safe_zone') {
      final edgeDistance = math.min(
        math.min(crop.x, 1.0 - crop.x - crop.width),
        math.min(crop.y, 1.0 - crop.y - crop.height),
      );

      if (edgeDistance > 0.1) {
        score += 0.1;
      }
    }

    final cropArea = crop.width * crop.height;
    if (cropArea > 0.3 && cropArea < 0.9) {
      score += 0.1;
    }

    switch (strategyType) {
      case 'intelligent_center':
        score += 0.1;
        break;
      case 'aspect_ratio_aware':
        score += 0.05;
        break;
      case 'user_preference':
        score += 0.15;
        break;
    }

    return math.max(0.0, math.min(1.0, score));
  }
}
