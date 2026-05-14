import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/crop_coordinates.dart';
import '../../models/crop_settings.dart';
import 'fallback_strategy.dart';
import 'fallback_score_helper.dart';

class UltimateCenterStrategy implements FallbackStrategy {
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

    double cropWidth, cropHeight;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }

    cropWidth = math.max(0.1, math.min(1.0, cropWidth));
    cropHeight = math.max(0.1, math.min(1.0, cropHeight));

    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.3,
      strategy: 'ultimate_center_fallback',
    );
  }

  @override
  double scoreCrop({
    required CropCoordinates crop,
    required ui.Image image,
    required ui.Size targetSize,
  }) {
    // Ultimate center has the base score only
    return FallbackScoreHelper.scoreCrop(
      crop: crop,
      targetSize: targetSize,
      strategyType: 'ultimate_center',
    );
  }
}
