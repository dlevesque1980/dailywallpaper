import 'dart:ui' as ui;
import '../../models/crop_coordinates.dart';
import '../../models/crop_settings.dart';

/// Interface for fallback crop strategies
abstract class FallbackStrategy {
  /// Creates a fallback crop
  CropCoordinates createCrop({
    required ui.Image image,
    required ui.Size targetSize,
    CropSettings? settings,
    Map<String, dynamic>? context,
  });

  /// Scores the quality of the fallback crop
  double scoreCrop({
    required CropCoordinates crop,
    required ui.Image image,
    required ui.Size targetSize,
  });
}
