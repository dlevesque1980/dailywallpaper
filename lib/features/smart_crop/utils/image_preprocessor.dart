import 'dart:ui' as ui;
import '../models/crop_settings.dart';

class ImagePreprocessor {
  /// Preprocesses image for optimal analysis
  static Future<ui.Image> preprocessImage(
      ui.Image image, CropSettings settings) async {
    // Always enhance for better analysis in aggressive mode
    if (settings.aggressiveness == CropAggressiveness.aggressive) {
      return await enhanceImageForAnalysis(image, settings);
    }

    return image;
  }

  /// Enhances image for better analysis results
  static Future<ui.Image> enhanceImageForAnalysis(
      ui.Image image, CropSettings settings) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Apply color matrix for better contrast
    final paint = ui.Paint()
      ..colorFilter = const ui.ColorFilter.matrix([
        1.2, 0, 0, 0, 0, // Red channel (slight boost)
        0, 1.2, 0, 0, 0, // Green channel (slight boost)
        0, 0, 1.2, 0, 0, // Blue channel (slight boost)
        0, 0, 0, 1, 0, // Alpha channel (unchanged)
      ]);

    canvas.drawImage(image, ui.Offset.zero, paint);

    final picture = recorder.endRecording();
    return await picture.toImage(image.width, image.height);
  }

  static Future<ui.Image> resizeImage(
      ui.Image image, ui.Size targetSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
      paint,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(
        targetSize.width.toInt(), targetSize.height.toInt());
  }
}
