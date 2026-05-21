import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/smart_crop/utils/degradation_fallback_strategy.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';

void main() {
  group('FallbackStrategy', () {
    test('properties are set correctly', () {
      const settings = CropSettings(
        aggressiveness: CropAggressiveness.balanced,
      );

      const strategy = FallbackStrategy(
        name: 'test_strategy',
        settings: settings,
        timeout: Duration(milliseconds: 500),
      );

      expect(strategy.name, 'test_strategy');
      expect(strategy.settings, settings);
      expect(strategy.timeout.inMilliseconds, 500);
    });

    test('toString formats correctly', () {
      const settings = CropSettings(
        aggressiveness: CropAggressiveness.balanced,
      );

      const strategy = FallbackStrategy(
        name: 'test_strategy',
        settings: settings,
        timeout: Duration(milliseconds: 500),
      );

      expect(strategy.toString(),
          'FallbackStrategy(test_strategy, timeout: 500ms)');
    });
  });
}
