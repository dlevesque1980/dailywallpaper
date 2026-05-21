import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/smart_crop/config/configuration_validator.dart';
import 'package:dailywallpaper/features/smart_crop/config/configuration_manager.dart';

void main() {
  group('ConfigurationValidator', () {
    late ConfigurationValidator validator;

    setUp(() {
      validator = ConfigurationValidator();
    });

    test('validateImportedConfig returns false when profile is missing', () {
      final config = <String, dynamic>{
        'custom_settings': {'aggressiveness': 1},
      };

      expect(validator.validateImportedConfig(config), isFalse);
    });

    test('validateImportedConfig returns false when profile index is invalid',
        () {
      final config = <String, dynamic>{
        'profile': 999, // Invalid index
      };

      expect(validator.validateImportedConfig(config), isFalse);
    });

    test('validateImportedConfig returns true for valid config', () {
      final config = <String, dynamic>{
        'profile': CropQualityProfile.balanced.index,
        'custom_settings': {
          'aggressiveness': 1,
          'enableRuleOfThirds': true,
          'enableEntropyAnalysis': true,
          'enableEdgeDetection': true,
          'enableCenterWeighting': true,
          'maxProcessingTime': 2000,
          'enableBatteryOptimization': false,
          'maxCropCandidates': 5,
        },
      };

      expect(validator.validateImportedConfig(config), isTrue);
    });
  });
}
