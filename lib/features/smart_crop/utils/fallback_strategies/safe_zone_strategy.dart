import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/crop_coordinates.dart';
import '../../models/crop_settings.dart';
import 'fallback_strategy.dart';
import 'fallback_score_helper.dart';

class SafeZoneStrategy implements FallbackStrategy {
  @override
  CropCoordinates createCrop({
    required ui.Image image,
    required ui.Size targetSize,
    CropSettings? settings,
    Map<String, dynamic>? context,
  }) {
    const safeZoneMargin = 0.1;

    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    final safeWidth = 1.0 - (2 * safeZoneMargin);
    final safeHeight = 1.0 - (2 * safeZoneMargin);

    double cropWidth, cropHeight;
    double offsetX, offsetY;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = math.min(safeWidth, 1.0);
      cropHeight = math.min(
          safeHeight, (imageAspectRatio / targetAspectRatio) * cropWidth);
    } else {
      cropHeight = math.min(safeHeight, 1.0);
      cropWidth = math.min(
          safeWidth, (targetAspectRatio / imageAspectRatio) * cropHeight);
    }

    offsetX = (1.0 - cropWidth) / 2;
    offsetY = (1.0 - cropHeight) / 2;

    cropWidth = math.max(0.2, cropWidth);
    cropHeight = math.max(0.2, cropHeight);

    return CropCoordinates(
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.5,
      strategy: 'safe_zone_fallback',
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
      strategyType: 'safe_zone',
    );
  }
}
