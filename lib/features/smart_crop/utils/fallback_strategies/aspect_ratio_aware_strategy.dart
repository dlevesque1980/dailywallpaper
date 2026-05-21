import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/crop_coordinates.dart';
import '../../models/crop_settings.dart';
import 'fallback_strategy.dart';
import 'fallback_score_helper.dart';

class AspectRatioAwareStrategy implements FallbackStrategy {
  @override
  CropCoordinates createCrop({
    required ui.Image image,
    required ui.Size targetSize,
    CropSettings? settings,
    Map<String, dynamic>? context,
  }) {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    const padding = 0.05;
    double cropWidth, cropHeight;
    double offsetX, offsetY;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = math.max(0.1, 1.0 - padding);
      cropHeight =
          math.max(0.1, (imageAspectRatio / targetAspectRatio) * cropWidth);

      offsetX = (1.0 - cropWidth) / 2;
      offsetY = _getOptimalVerticalPosition(cropHeight);
    } else {
      cropHeight = math.max(0.1, 1.0 - padding);
      cropWidth =
          math.max(0.1, (targetAspectRatio / imageAspectRatio) * cropHeight);

      offsetY = (1.0 - cropHeight) / 2;
      offsetX = _getOptimalHorizontalPosition(cropWidth);
    }

    offsetX = math.max(0.0, math.min(1.0 - cropWidth, offsetX));
    offsetY = math.max(0.0, math.min(1.0 - cropHeight, offsetY));

    return CropCoordinates(
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.6,
      strategy: 'aspect_ratio_aware_fallback',
    );
  }

  @override
  double scoreCrop({
    required CropCoordinates crop,
    required ui.Image image,
    required ui.Size targetSize,
  }) {
    return FallbackScoreHelper.scoreCrop(
      crop: crop,
      targetSize: targetSize,
      strategyType: 'aspect_ratio_aware',
    );
  }

  double _getOptimalVerticalPosition(double cropHeight) {
    const ruleOfThirdsPosition = 1.0 / 3.0;

    if (cropHeight >= 0.8) {
      return (1.0 - cropHeight) / 2;
    } else {
      final position = (1.0 - cropHeight) * ruleOfThirdsPosition;
      return math.max(0.0, math.min(1.0 - cropHeight, position));
    }
  }

  double _getOptimalHorizontalPosition(double cropWidth) {
    return (1.0 - cropWidth) / 2;
  }
}
