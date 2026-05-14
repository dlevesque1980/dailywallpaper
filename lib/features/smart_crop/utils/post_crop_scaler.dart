import 'dart:math' as math;
import 'dart:ui' as ui;

/// Scales a cropped image down if its dimensions exceed the device's physical
/// screen resolution, preserving the aspect ratio.
///
/// Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.7
class PostCropScaler {
  /// Default fallback resolution used when the device resolution cannot be
  /// determined (1080 × 1920 pixels).
  static const ui.Size _fallbackResolution = ui.Size(1080, 1920);

  /// Returns the physical screen resolution of the device.
  ///
  /// Obtained via [ui.PlatformDispatcher.instance.views.first.physicalSize]
  /// divided by [devicePixelRatio].
  /// Falls back to 1080 × 1920 if the resolution is unavailable or zero.
  static ui.Size getDeviceResolution() {
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final physicalSize = view.physicalSize;
      final dpr = view.devicePixelRatio;

      if (physicalSize.width <= 0 || physicalSize.height <= 0 || dpr <= 0) {
        return _fallbackResolution;
      }

      return ui.Size(physicalSize.width / dpr, physicalSize.height / dpr);
    } catch (_) {
      return _fallbackResolution;
    }
  }

  /// Scales [image] down if either of its dimensions exceeds [deviceResolution].
  ///
  /// - If both dimensions are within the device resolution, the original image
  ///   is returned unchanged (Requirement 4.3).
  /// - If at least one dimension exceeds the device resolution, a uniform scale
  ///   factor `min(deviceWidth / imageWidth, deviceHeight / imageHeight)` is
  ///   applied so the result fits within the device resolution while preserving
  ///   the aspect ratio (Requirements 4.1, 4.2).
  /// - [ui.FilterQuality.medium] (bilinear interpolation) is used for the
  ///   resize (Requirement 4.7).
  /// - On any error during resizing, the original image is returned unchanged.
  ///
  /// [deviceResolution] defaults to [getDeviceResolution()] when omitted.
  static Future<ui.Image> scaleIfNeeded(
    ui.Image image, {
    ui.Size? deviceResolution,
  }) async {
    final resolution = deviceResolution ?? getDeviceResolution();

    final deviceWidth = resolution.width;
    final deviceHeight = resolution.height;
    final imageWidth = image.width.toDouble();
    final imageHeight = image.height.toDouble();

    // No scaling needed — image fits within device resolution.
    if (imageWidth <= deviceWidth && imageHeight <= deviceHeight) {
      return image;
    }

    try {
      final scale =
          math.min(deviceWidth / imageWidth, deviceHeight / imageHeight);
      final targetWidth = (imageWidth * scale).round();
      final targetHeight = (imageHeight * scale).round();

      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

      canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, imageWidth, imageHeight),
        ui.Rect.fromLTWH(0, 0, targetWidth.toDouble(), targetHeight.toDouble()),
        paint,
      );

      final picture = recorder.endRecording();
      final scaledImage = await picture.toImage(targetWidth, targetHeight);
      picture.dispose();

      return scaledImage;
    } catch (_) {
      // On any error, return the original image unchanged.
      return image;
    }
  }
}
