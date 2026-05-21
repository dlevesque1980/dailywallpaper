import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/features/smart_crop/utils/fallback_strategies.dart';

class MockImage extends Mock implements ui.Image {}

void main() {
  group('FallbackCropStrategies', () {
    late FallbackCropStrategies factory;
    late MockImage mockImage;

    setUp(() {
      factory = FallbackCropStrategies();
      mockImage = MockImage();
      when(() => mockImage.width).thenReturn(1000);
      when(() => mockImage.height).thenReturn(1000);
    });

    test('selects intelligent center for memory pressure', () {
      final crop = factory.createFallbackCrop(
        image: mockImage,
        targetSize: const ui.Size(1000, 2000),
        reason: 'memory_pressure',
      );

      expect(crop.strategy, 'intelligent_center_fallback');
    });

    test('selects aspect ratio aware for analyzer failure', () {
      final crop = factory.createFallbackCrop(
        image: mockImage,
        targetSize: const ui.Size(1000, 2000),
        reason: 'analyzer_failure',
      );

      expect(crop.strategy, 'aspect_ratio_aware_fallback');
    });

    test('selects safe zone for corrupted image', () {
      final crop = factory.createFallbackCrop(
        image: mockImage,
        targetSize: const ui.Size(1000, 2000),
        reason: 'corrupted_image',
      );

      expect(crop.strategy, 'safe_zone_fallback');
    });

    test('createFallbackOptions returns sorted options', () {
      final options = factory.createFallbackOptions(
        image: mockImage,
        targetSize: const ui.Size(1000, 2000),
      );

      expect(options.length, 3);
      // Options should be sorted by score descending
      expect(options[0].score >= options[1].score, isTrue);
      expect(options[1].score >= options[2].score, isTrue);
    });
  });
}
