import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/features/smart_crop/utils/fallback_strategies/aspect_ratio_aware_strategy.dart';

class MockImage extends Mock implements ui.Image {}

void main() {
  group('AspectRatioAwareStrategy', () {
    late AspectRatioAwareStrategy strategy;
    late MockImage mockImage;

    setUp(() {
      strategy = AspectRatioAwareStrategy();
      mockImage = MockImage();
      when(() => mockImage.width).thenReturn(1000);
      when(() => mockImage.height).thenReturn(1000);
    });

    test('creates crop with padding for portrait target', () {
      final targetSize = const ui.Size(1000, 2000); // Taller target
      
      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
      );

      // cropHeight = 1.0 - 0.05 = 0.95
      // cropWidth = 0.5 * 0.95 = 0.475
      expect(crop.height, closeTo(0.95, 0.001));
      expect(crop.width, closeTo(0.475, 0.001));
      
      // offsetY = (1.0 - 0.95) / 2 = 0.025
      // offsetX = (1.0 - 0.475) / 2 = 0.2625
      expect(crop.y, closeTo(0.025, 0.001));
      expect(crop.x, closeTo(0.2625, 0.001));
    });

    test('creates crop with padding for landscape target', () {
      final targetSize = const ui.Size(2000, 1000); // Wider target
      
      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
      );

      // cropWidth = 1.0 - 0.05 = 0.95
      // cropHeight = 0.5 * 0.95 = 0.475
      expect(crop.width, closeTo(0.95, 0.001));
      expect(crop.height, closeTo(0.475, 0.001));
      
      // offsetX = (1.0 - 0.95) / 2 = 0.025
      // offsetY uses rule of thirds for small crops (< 0.8)
      // position = (1.0 - 0.475) * (1/3) = 0.175
      expect(crop.x, closeTo(0.025, 0.001));
      expect(crop.y, closeTo(0.175, 0.001));
    });
  });
}
