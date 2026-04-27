import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lib/services/smart_crop/smart_crop.dart';

void main() {
  group('SmartCropProfileManager Integration', () {
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
    });

    test('should integrate with existing Smart Crop system', () async {
      // Test that profile manager works with the main Smart Crop exports

      // Set to Conservative level
      await SmartCropProfileManager.setSmartCropLevel(1);

      // Verify through SmartCropPreferences
      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();
      final settings = await SmartCropPreferences.getCropSettings();

      expect(isEnabled, isTrue);
      expect(settings.aggressiveness, equals(CropAggressiveness.conservative));
      expect(settings.enableBatteryOptimization, isTrue);

      // Test level detection
      final currentLevel = await SmartCropProfileManager.getCurrentLevel();
      expect(currentLevel, equals(1));

      // Test switching to Aggressive
      await SmartCropProfileManager.setSmartCropLevel(3);

      final newSettings = await SmartCropPreferences.getCropSettings();
      expect(newSettings.aggressiveness, equals(CropAggressiveness.aggressive));
      expect(newSettings.enableBatteryOptimization, isTrue);

      final newLevel = await SmartCropProfileManager.getCurrentLevel();
      expect(newLevel, equals(3));
    });

    test('should maintain battery optimization across all levels', () async {
      for (int level = 1; level <= 3; level++) {
        await SmartCropProfileManager.setSmartCropLevel(level);

        final settings = await SmartCropPreferences.getCropSettings();
        expect(settings.enableBatteryOptimization, isTrue,
            reason: 'Level $level should have battery optimization enabled');
      }
    });

    test('should have appropriate processing times for each level', () async {
      // Conservative: 1 second
      await SmartCropProfileManager.setSmartCropLevel(1);
      var settings = await SmartCropPreferences.getCropSettings();
      expect(settings.maxProcessingTime, equals(const Duration(seconds: 1)));

      // Balanced: 2 seconds
      await SmartCropProfileManager.setSmartCropLevel(2);
      settings = await SmartCropPreferences.getCropSettings();
      expect(settings.maxProcessingTime, equals(const Duration(seconds: 2)));

      // Aggressive: 3 seconds
      await SmartCropProfileManager.setSmartCropLevel(3);
      settings = await SmartCropPreferences.getCropSettings();
      expect(settings.maxProcessingTime, equals(const Duration(seconds: 3)));
    });

    test('should have appropriate crop candidates for each level', () async {
      // Conservative: 3 candidates
      await SmartCropProfileManager.setSmartCropLevel(1);
      var settings = await SmartCropPreferences.getCropSettings();
      expect(settings.maxCropCandidates, equals(3));

      // Balanced: 5 candidates
      await SmartCropProfileManager.setSmartCropLevel(2);
      settings = await SmartCropPreferences.getCropSettings();
      expect(settings.maxCropCandidates, equals(5));

      // Aggressive: 8 candidates
      await SmartCropProfileManager.setSmartCropLevel(3);
      settings = await SmartCropPreferences.getCropSettings();
      expect(settings.maxCropCandidates, equals(8));
    });

    test('should provide complete profile information', () async {
      await SmartCropProfileManager.setSmartCropLevel(2);

      final summary = await SmartCropProfileManager.getProfileSummary();

      // Verify all expected fields are present
      expect(summary.containsKey('level'), isTrue);
      expect(summary.containsKey('label'), isTrue);
      expect(summary.containsKey('description'), isTrue);
      expect(summary.containsKey('enabled'), isTrue);
      expect(summary.containsKey('batteryOptimized'), isTrue);
      expect(summary.containsKey('aggressiveness'), isTrue);
      expect(summary.containsKey('processingTimeMs'), isTrue);
      expect(summary.containsKey('maxCandidates'), isTrue);
      expect(summary.containsKey('isValid'), isTrue);

      // Verify values are correct for level 2
      expect(summary['level'], equals(2));
      expect(summary['label'], equals('Balanced'));
      expect(summary['enabled'], isTrue);
      expect(summary['batteryOptimized'], isTrue);
      expect(summary['isValid'], isTrue);
    });
  });
}
