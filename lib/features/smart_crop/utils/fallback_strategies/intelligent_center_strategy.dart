import 'dart:ui' as ui;
import 'dart:math' as math;
import '../../models/crop_coordinates.dart';
import '../../models/crop_settings.dart';
import 'fallback_strategy.dart';
import 'fallback_score_helper.dart';

class IntelligentCenterStrategy implements FallbackStrategy {
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
    double offsetX = 0.0, offsetY = 0.0;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
      offsetY = _getIntelligentVerticalOffset(cropHeight, settings);
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
      offsetX = _getIntelligentHorizontalOffset(cropWidth, settings);
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
      confidence: 0.7,
      strategy: 'intelligent_center_fallback',
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
      strategyType: 'intelligent_center',
    );
  }

  double _getIntelligentVerticalOffset(
      double cropHeight, CropSettings? settings) {
    final verticalBias = settings?.enableRuleOfThirds == true ? 0.33 : 0.4;
    return (1.0 - cropHeight) * verticalBias;
  }

  double _getIntelligentHorizontalOffset(
      double cropWidth, CropSettings? settings) {
    return (1.0 - cropWidth) * 0.5;
  }
}
