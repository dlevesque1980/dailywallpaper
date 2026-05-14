import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/crop_coordinates.dart';
import '../../models/crop_settings.dart';
import 'fallback_strategy.dart';
import 'fallback_score_helper.dart';

class UserPreferenceStrategy implements FallbackStrategy {
  @override
  CropCoordinates createCrop({
    required ui.Image image,
    required ui.Size targetSize,
    CropSettings? settings,
    Map<String, dynamic>? context,
  }) {
    final cropBias = _getCropBiasFromAggressiveness(settings?.aggressiveness);

    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    double cropWidth, cropHeight;
    double offsetX, offsetY;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
      offsetX = 0.0;
      offsetY = (1.0 - cropHeight) * cropBias.vertical;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
      offsetY = 0.0;
      offsetX = (1.0 - cropWidth) * cropBias.horizontal;
    }

    cropWidth = math.max(0.1, math.min(1.0, cropWidth));
    cropHeight = math.max(0.1, math.min(1.0, cropHeight));
    offsetX = math.max(0.0, math.min(1.0 - cropWidth, offsetX));
    offsetY = math.max(0.0, math.min(1.0 - cropHeight, offsetY));

    return CropCoordinates(
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.65,
      strategy: 'user_preference_fallback',
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
      strategyType: 'user_preference',
    );
  }

  _CropBias _getCropBiasFromAggressiveness(CropAggressiveness? aggressiveness) {
    switch (aggressiveness) {
      case CropAggressiveness.conservative:
        return const _CropBias(horizontal: 0.5, vertical: 0.5);
      case CropAggressiveness.balanced:
        return const _CropBias(horizontal: 0.5, vertical: 0.33);
      case CropAggressiveness.aggressive:
        return const _CropBias(horizontal: 0.5, vertical: 0.25);
      default:
        return const _CropBias(horizontal: 0.5, vertical: 0.5);
    }
  }
}

class _CropBias {
  final double horizontal;
  final double vertical;

  const _CropBias({
    required this.horizontal,
    required this.vertical,
  });
}
