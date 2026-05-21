import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/features/smart_crop/utils/fallback_strategies/user_preference_strategy.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';

class MockImage extends Mock implements ui.Image {}

void main() {
  group('UserPreferenceStrategy', () {
    late UserPreferenceStrategy strategy;
    late MockImage mockImage;

    setUp(() {
      strategy = UserPreferenceStrategy();
      mockImage = MockImage();
      when(() => mockImage.width).thenReturn(1000);
      when(() => mockImage.height).thenReturn(1000);
    });

    test('uses aggressive bias', () {
      final targetSize = const ui.Size(2000, 1000); // Wider
      final settings =
          const CropSettings(aggressiveness: CropAggressiveness.aggressive);

      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
        settings: settings,
      );

      // Aggressive vertical bias is 0.25 (upper quarter)
      expect(crop.y, closeTo(0.125, 0.001)); // (1.0 - 0.5) * 0.25
    });

    test('uses balanced bias', () {
      final targetSize = const ui.Size(2000, 1000); // Wider
      final settings =
          const CropSettings(aggressiveness: CropAggressiveness.balanced);

      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
        settings: settings,
      );

      // Balanced vertical bias is 0.33
      expect(crop.y, closeTo(0.165, 0.001)); // (1.0 - 0.5) * 0.33
    });

    test('uses conservative bias', () {
      final targetSize = const ui.Size(2000, 1000); // Wider
      final settings =
          const CropSettings(aggressiveness: CropAggressiveness.conservative);

      final crop = strategy.createCrop(
        image: mockImage,
        targetSize: targetSize,
        settings: settings,
      );

      // Conservative vertical bias is 0.5
      expect(crop.y, closeTo(0.25, 0.001)); // (1.0 - 0.5) * 0.5
    });
  });
}
