import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/features/smart_crop/utils/fallback_strategies/safe_zone_strategy.dart';

class MockImage extends Mock implements ui.Image {}

void main() {
  group('SafeZoneStrategy', () {
    late SafeZoneStrategy strategy;
    late MockImage mockImage;

    setUp(() {
      strategy = SafeZoneStrategy();
      mockImage = MockImage();
      when(() => mockImage.width).thenReturn(1000);
      when(() => mockImage.height).thenReturn(1000);
    });

    test('creates crop within safe zone for portrait target', () {
      final targetSize = const ui.Size(1000, 2000);
      
      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
      );

      // Safe width/height are 0.8.
      // Target is taller, so cropHeight = min(0.8, 1.0) = 0.8
      // cropWidth = min(0.8, 0.5 * 0.8) = 0.4
      expect(crop.height, closeTo(0.8, 0.001));
      expect(crop.width, closeTo(0.4, 0.001));
      
      // Center offsets
      expect(crop.y, closeTo(0.1, 0.001)); // (1.0 - 0.8) / 2
      expect(crop.x, closeTo(0.3, 0.001)); // (1.0 - 0.4) / 2
    });

    test('creates crop within safe zone for landscape target', () {
      final targetSize = const ui.Size(2000, 1000);
      
      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
      );

      // Target is wider, so cropWidth = min(0.8, 1.0) = 0.8
      // cropHeight = min(0.8, 0.5 * 0.8) = 0.4
      expect(crop.width, closeTo(0.8, 0.001));
      expect(crop.height, closeTo(0.4, 0.001));
      
      expect(crop.x, closeTo(0.1, 0.001)); // (1.0 - 0.8) / 2
      expect(crop.y, closeTo(0.3, 0.001)); // (1.0 - 0.4) / 2
    });
  });
}
