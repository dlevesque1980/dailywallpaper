import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/analyzers/utils/analyzer_utils.dart';

void main() {
  group('AnalyzerUtils', () {
    const imageSize = ui.Size(1000, 1000); // 1:1

    test('calculateCropWidth for square image and 16:9 target', () {
      final width = AnalyzerUtils.calculateCropWidth(imageSize, 16 / 9);
      expect(width, 1.0);
    });

    test('calculateCropWidth for square image and 9:16 target', () {
      final width = AnalyzerUtils.calculateCropWidth(imageSize, 9 / 16);
      expect(width, closeTo(9 / 16, 0.001));
    });

    test('calculateCropHeight for square image and 16:9 target', () {
      final height = AnalyzerUtils.calculateCropHeight(imageSize, 16 / 9);
      expect(height, closeTo(9 / 16, 0.001));
    });

    test('calculateCropHeight for square image and 9:16 target', () {
      final height = AnalyzerUtils.calculateCropHeight(imageSize, 9 / 16);
      expect(height, 1.0);
    });

    test('getCenterCrop returns a centered crop', () {
      final crop = AnalyzerUtils.getCenterCrop(imageSize, 16 / 9, 'center');
      expect(crop.x, 0.0);
      expect(crop.y, closeTo((1.0 - 9 / 16) / 2, 0.001));
      expect(crop.width, 1.0);
      expect(crop.height, closeTo(9 / 16, 0.001));
    });

    test('getPixelBrightness returns correct brightness', () {
      final data = Uint8List.fromList([255, 255, 255, 255]); // White pixel
      final b = AnalyzerUtils.getPixelBrightness(data, 1, 0, 0);
      expect(b, 255);

      final dataBlack = Uint8List.fromList([0, 0, 0, 255]); // Black pixel
      final bBlack = AnalyzerUtils.getPixelBrightness(dataBlack, 1, 0, 0);
      expect(bBlack, 0);

      final dataRed = Uint8List.fromList([255, 0, 0, 255]); // Red pixel
      final bRed = AnalyzerUtils.getPixelBrightness(dataRed, 1, 0, 0);
      expect(bRed, (255 * 0.299).round());
    });

    test('getPixelBrightness returns -1 for out of bounds', () {
      final data = Uint8List.fromList([255, 255, 255, 255]);
      expect(AnalyzerUtils.getPixelBrightness(data, 1, 1, 0), -1);
      expect(AnalyzerUtils.getPixelBrightness(data, 1, 0, 1), -1);
    });

    test('getPositionWeight is max at center', () {
      final weight = AnalyzerUtils.getPositionWeight(0.5, 0.5);
      expect(weight, 1.0);
    });

    test('getPositionWeight is min at corners', () {
      final weight = AnalyzerUtils.getPositionWeight(0.0, 0.0);
      expect(weight, 0.1);
    });
  });
}
