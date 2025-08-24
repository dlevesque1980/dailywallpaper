import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lib/services/smart_crop/smart_crop_preferences.dart';
import '../../../lib/services/smart_crop/models/crop_settings.dart';

void main() {
  group('SmartCropPreferences', () {
    setUp(() {
      // Clear all preferences before each test
      SharedPreferences.setMockInitialValues({});
    });

    group('Smart Crop Enabled', () {
      test('should return true by default', () async {
        final enabled = await SmartCropPreferences.isSmartCropEnabled();
        expect(enabled, true);
      });

      test('should save and retrieve enabled state', () async {
        await SmartCropPreferences.setSmartCropEnabled(false);
        final enabled = await SmartCropPreferences.isSmartCropEnabled();
        expect(enabled, false);

        await SmartCropPreferences.setSmartCropEnabled(true);
        final enabledAgain = await SmartCropPreferences.isSmartCropEnabled();
        expect(enabledAgain, true);
      });
    });

    group('Crop Settings', () {
      test('should return default settings initially', () async {
        // Clear any existing preferences first
        await SmartCropPreferences.resetToDefaults();
        
        final settings = await SmartCropPreferences.getCropSettings();
        expect(settings.aggressiveness, CropAggressiveness.aggressive);
        expect(settings.enableRuleOfThirds, true);
        expect(settings.enableEntropyAnalysis, true);
        expect(settings.enableEdgeDetection, true);
        expect(settings.enableCenterWeighting, true);
        expect(settings.maxProcessingTime, const Duration(seconds: 3));
      });

      test('should save and retrieve custom settings', () async {
        final customSettings = CropSettings(
          aggressiveness: CropAggressiveness.aggressive,
          enableRuleOfThirds: false,
          enableEntropyAnalysis: true,
          enableEdgeDetection: true,
          enableCenterWeighting: false,
          maxProcessingTime: const Duration(seconds: 3),
        );

        final saved = await SmartCropPreferences.saveCropSettings(customSettings);
        expect(saved, true);

        final retrieved = await SmartCropPreferences.getCropSettings();
        expect(retrieved.aggressiveness, CropAggressiveness.aggressive);
        expect(retrieved.enableRuleOfThirds, false);
        expect(retrieved.enableEntropyAnalysis, true);
        expect(retrieved.enableEdgeDetection, true);
        expect(retrieved.enableCenterWeighting, false);
        expect(retrieved.maxProcessingTime, const Duration(seconds: 3));
      });

      test('should not save invalid settings', () async {
        final invalidSettings = CropSettings(
          aggressiveness: CropAggressiveness.balanced,
          enableRuleOfThirds: false,
          enableEntropyAnalysis: false,
          enableEdgeDetection: false,
          enableCenterWeighting: false, // No strategies enabled
          maxProcessingTime: const Duration(seconds: 2),
        );

        final saved = await SmartCropPreferences.saveCropSettings(invalidSettings);
        expect(saved, false);

        // Should still have default settings
        final retrieved = await SmartCropPreferences.getCropSettings();
        expect(retrieved.isValid, true);
      });

      test('should clamp invalid values when loading', () async {
        // Manually set invalid values in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('smart_crop_settings_version', 1); // Prevent migration reset
        await prefs.setInt('smartcropaggressiveness', 999); // Invalid index
        await prefs.setInt('smartcropmaxprocessingtime', 100); // Too low

        final settings = await SmartCropPreferences.getCropSettings();
        expect(settings.aggressiveness, CropAggressiveness.aggressive); // Clamped to max valid
        expect(settings.maxProcessingTime.inMilliseconds, 500); // Clamped to minimum
      });
    });

    group('Crop Aggressiveness', () {
      test('should save and retrieve aggressiveness setting', () async {
        await SmartCropPreferences.setCropAggressiveness(CropAggressiveness.conservative);
        final aggressiveness = await SmartCropPreferences.getCropAggressiveness();
        expect(aggressiveness, CropAggressiveness.conservative);
      });

      test('should return balanced by default', () async {
        final aggressiveness = await SmartCropPreferences.getCropAggressiveness();
        expect(aggressiveness, CropAggressiveness.balanced);
      });
    });

    group('Settings Validation', () {
      test('should validate and fix invalid settings', () async {
        // Set invalid settings manually
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('smartcropruleofthirds', false);
        await prefs.setBool('smartcropentropyanalysis', false);
        await prefs.setBool('smartcropedgedetection', false);
        await prefs.setBool('smartcropcenterweighting', false);

        final settings = await SmartCropPreferences.validateAndFixSettings();
        expect(settings.isValid, true);
        expect(settings, CropSettings.defaultSettings);
      });
    });

    group('Reset to Defaults', () {
      test('should reset all settings to defaults', () async {
        // Set custom settings first
        final customSettings = CropSettings(
          aggressiveness: CropAggressiveness.aggressive,
          enableRuleOfThirds: false,
          enableEntropyAnalysis: false,
          enableEdgeDetection: true,
          enableCenterWeighting: true,
          maxProcessingTime: const Duration(seconds: 5),
        );
        await SmartCropPreferences.saveCropSettings(customSettings);

        // Reset to defaults
        final reset = await SmartCropPreferences.resetToDefaults();
        expect(reset, true);

        // Verify defaults are restored
        final settings = await SmartCropPreferences.getCropSettings();
        expect(settings, CropSettings.defaultSettings);
      });
    });

    group('Settings Summary', () {
      test('should provide correct settings summary', () async {
        // Set version first to prevent migration reset
        final prefs = await SharedPreferences.getInstance();
        await prefs.setInt('smart_crop_settings_version', 1);
        
        await SmartCropPreferences.setSmartCropEnabled(true);
        await SmartCropPreferences.setCropAggressiveness(CropAggressiveness.conservative);

        final summary = await SmartCropPreferences.getSettingsSummary();
        expect(summary['enabled'], true);
        expect(summary['aggressiveness'], 'conservative');
        expect(summary['enabledStrategies'], isA<List<String>>());
        expect(summary['maxProcessingTimeMs'], isA<int>());
        expect(summary['isValid'], true);
      });
    });

    group('Migration', () {
      test('should handle first-time setup', () async {
        // This should trigger migration from version 0 to 1
        final settings = await SmartCropPreferences.getCropSettings();
        expect(settings.isValid, true);
        
        // Verify version was set
        final prefs = await SharedPreferences.getInstance();
        final version = prefs.getInt('smart_crop_settings_version');
        expect(version, 1);
      });
    });
  });

  group('CropSettings Serialization', () {
    test('should serialize and deserialize to Map correctly', () {
      const settings = CropSettings(
        aggressiveness: CropAggressiveness.aggressive,
        enableRuleOfThirds: false,
        enableEntropyAnalysis: true,
        enableEdgeDetection: true,
        enableCenterWeighting: false,
        maxProcessingTime: Duration(milliseconds: 3500),
      );

      final map = settings.toMap();
      final restored = CropSettings.fromMap(map);

      expect(restored.aggressiveness, settings.aggressiveness);
      expect(restored.enableRuleOfThirds, settings.enableRuleOfThirds);
      expect(restored.enableEntropyAnalysis, settings.enableEntropyAnalysis);
      expect(restored.enableEdgeDetection, settings.enableEdgeDetection);
      expect(restored.enableCenterWeighting, settings.enableCenterWeighting);
      expect(restored.maxProcessingTime, settings.maxProcessingTime);
    });

    test('should serialize and deserialize to JSON correctly', () {
      const settings = CropSettings(
        aggressiveness: CropAggressiveness.conservative,
        enableRuleOfThirds: true,
        enableEntropyAnalysis: false,
        enableEdgeDetection: false,
        enableCenterWeighting: true,
        maxProcessingTime: Duration(milliseconds: 1500),
      );

      final json = settings.toJson();
      final restored = CropSettings.fromJson(json);

      expect(restored.aggressiveness, settings.aggressiveness);
      expect(restored.enableRuleOfThirds, settings.enableRuleOfThirds);
      expect(restored.enableEntropyAnalysis, settings.enableEntropyAnalysis);
      expect(restored.enableEdgeDetection, settings.enableEdgeDetection);
      expect(restored.enableCenterWeighting, settings.enableCenterWeighting);
      expect(restored.maxProcessingTime, settings.maxProcessingTime);
    });

    test('should handle malformed JSON gracefully', () {
      const malformedJson = '{"invalid": "json"';
      final settings = CropSettings.fromJson(malformedJson);
      
      // Should return settings with default values for missing fields
      expect(settings.aggressiveness, CropAggressiveness.balanced);
      expect(settings.enableRuleOfThirds, true);
    });
  });
}