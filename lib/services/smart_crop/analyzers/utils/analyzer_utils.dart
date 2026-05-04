import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

class AnalyzerUtils {
  static double calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspect ? 1.0 : targetAspectRatio / imageAspect;
  }

  static double calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspect = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspect ? 1.0 : imageAspect / targetAspectRatio;
  }

  static CropCoordinates getCenterCrop(ui.Size imageSize, double targetAspectRatio, String strategy) {
    final cW = calculateCropWidth(imageSize, targetAspectRatio);
    final cH = calculateCropHeight(imageSize, targetAspectRatio);
    return CropCoordinates(x: (1.0 - cW) / 2, y: (1.0 - cH) / 2, width: cW, height: cH, confidence: 0.1, strategy: strategy);
  }

  static int getPixelBrightness(Uint8List data, int w, int x, int y) {
    final idx = (y * w + x) * 4;
    if (idx < 0 || idx + 2 >= data.length) return -1;
    return (data[idx] * 0.299 + data[idx + 1] * 0.587 + data[idx + 2] * 0.114).round();
  }

  static double getPositionWeight(double x, double y) {
    final dist = math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2));
    return math.max(0.1, 1.0 - (dist * 2.5));
  }
}
