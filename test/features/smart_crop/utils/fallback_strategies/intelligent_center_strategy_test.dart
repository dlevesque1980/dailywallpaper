import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/features/smart_crop/utils/fallback_strategies/intelligent_center_strategy.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';

class MockImage extends Mock implements ui.Image {}

void main() {
  group('IntelligentCenterStrategy', () {
    late IntelligentCenterStrategy strategy;
    late MockImage mockImage;

    setUp(() {
      strategy = IntelligentCenterStrategy();
      mockImage = MockImage();
      when(() => mockImage.width).thenReturn(1000);
      when(() => mockImage.height).thenReturn(1000);
    });

    test('creates center crop for portrait target on square image', () {
      final targetSize = const ui.Size(1000, 2000);
      
      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
      );

      expect(crop.width, 0.5);
      expect(crop.height, 1.0);
      expect(crop.x, 0.25);
      expect(crop.y, 0.0);
    });

    test('creates top-biased crop for landscape target on square image', () {
      final targetSize = const ui.Size(2000, 1000);
      
      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
      );

      expect(crop.width, 1.0);
      expect(crop.height, 0.5);
      expect(crop.x, 0.0);
      expect(crop.y, 0.2); // (1.0 - 0.5) * 0.4
    });
  });
}
