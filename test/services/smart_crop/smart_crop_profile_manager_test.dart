import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lib/services/smart_crop/smart_crop_profile_manager.dart';
import '../../../lib/services/smart_crop/smart_crop_preferences.dart';
import '../../../lib/services/smart_crop/models/crop_settings.dart';

void main() {
  group('SmartCropProfileManager', () {
    setUp(() async {
      // Initialize SharedPreferences for testing
      SharedPreferences.setMockInitialValues({});
    });

    test('should have correct level labels', () {
      expect(SmartCropProfileManager.getLevelLabel(0), equals('Off'));
      expect(SmartCropProfileManager.getLevelLabel(1), equals('Conservative'));
      expect(SmartCropProfileManager.getLevelLabel(2), equals('Balanced'));
      expect(SmartCropProfileManager.getLevelLabel(3), equals('Aggressive'));
    });

    test('should have correct default level', () {
      expect(SmartCropProfileManager.defaultLevel, equals(2));
    });

    test('should set level 0 (Off) correctly', () async {
      await SmartCropProfileManager.setSmartCropLevel(0);

      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();
      final currentLevel = await SmartCropProfileManager.getCurrentLevel();

      expect(isEnabled, isFalse);
      expect(currentLevel, equals(0));
    });

    test('should set level 1 (Conservative) correctly', () async {
      await SmartCropProfileManager.setSmartCropLevel(1);

      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();
      final settings = await SmartCropPreferences.getCropSettings();
      final currentLevel = await SmartCropProfileManager.getCurrentLevel();

      expect(isEnabled, isTrue);
      expect(currentLevel, equals(1));
      expect(settings.aggressiveness, equals(CropAggressiveness.conservative));
      expect(settings.enableBatteryOptimization, isTrue);
      expect(settings.maxProcessingTime, equals(const Duration(seconds: 1)));
      expect(settings.maxCropCandidates, equals(3));
    });

    test('should set level 2 (Balanced) correctly', () async {
      await SmartCropProfileManager.setSmartCropLevel(2);

      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();
      final settings = await SmartCropPreferences.getCropSettings();
      final currentLevel = await SmartCropProfileManager.getCurrentLevel();

      expect(isEnabled, isTrue);
      expect(currentLevel, equals(2));
      expect(settings.aggressiveness, equals(CropAggressiveness.balanced));
      expect(settings.enableBatteryOptimization, isTrue);
      expect(settings.maxProcessingTime, equals(const Duration(seconds: 2)));
      expect(settings.maxCropCandidates, equals(5));
    });

    test('should set level 3 (Aggressive) correctly', () async {
      await SmartCropProfileManager.setSmartCropLevel(3);

      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();
      final settings = await SmartCropPreferences.getCropSettings();
      final currentLevel = await SmartCropProfileManager.getCurrentLevel();

      expect(isEnabled, isTrue);
      expect(currentLevel, equals(3));
      expect(settings.aggressiveness, equals(CropAggressiveness.aggressive));
      expect(settings.enableBatteryOptimization, isTrue);
      expect(settings.maxProcessingTime, equals(const Duration(seconds: 3)));
      expect(settings.maxCropCandidates, equals(8));
    });

    test('should throw error for invalid level', () async {
      expect(() => SmartCropProfileManager.setSmartCropLevel(-1),
          throwsA(isA<ArgumentError>()));
      expect(() => SmartCropProfileManager.setSmartCropLevel(4),
          throwsA(isA<ArgumentError>()));
    });

    test('should initialize with defaults correctly', () async {
      await SmartCropProfileManager.initializeWithDefaults();

      final currentLevel = await SmartCropProfileManager.getCurrentLevel();
      expect(currentLevel, equals(SmartCropProfileManager.defaultLevel));
    });

    test('should validate configuration correctly', () async {
      // Set to level 2 (Balanced)
      await SmartCropProfileManager.setSmartCropLevel(2);

      final isValid =
          await SmartCropProfileManager.validateCurrentConfiguration();
      expect(isValid, isTrue);
    });

    test('should get profile summary correctly', () async {
      await SmartCropProfileManager.setSmartCropLevel(2);

      final summary = await SmartCropProfileManager.getProfileSummary();

      expect(summary['level'], equals(2));
      expect(summary['label'], equals('Balanced'));
      expect(summary['enabled'], isTrue);
      expect(summary['batteryOptimized'], isTrue);
      expect(summary['aggressiveness'], equals('balanced'));
    });

    test('should get all levels information', () {
      final allLevels = SmartCropProfileManager.getAllLevels();

      expect(allLevels.length, equals(4));
      expect(allLevels[0]!['label'], equals('Off'));
      expect(allLevels[1]!['label'], equals('Conservative'));
      expect(allLevels[2]!['label'], equals('Balanced'));
      expect(allLevels[3]!['label'], equals('Aggressive'));

      // Check that all levels have descriptions
      for (int i = 0; i <= 3; i++) {
        expect(allLevels[i]!['description'], isNotNull);
        expect(allLevels[i]!['description']!.isNotEmpty, isTrue);
      }
    });

    test('should repair invalid configuration', () async {
      // Manually set an invalid state (enabled but no battery optimization)
      await SmartCropPreferences.setSmartCropEnabled(true);
      await SmartCropPreferences.setCropSettings(
          CropSettings.balanced.copyWith(enableBatteryOptimization: false));

      // Verify it's invalid
      final isValidBefore =
          await SmartCropProfileManager.validateCurrentConfiguration();
      expect(isValidBefore, isFalse);

      // Repair it
      await SmartCropProfileManager.repairConfiguration();

      // Verify it's now valid
      final isValidAfter =
          await SmartCropProfileManager.validateCurrentConfiguration();
      expect(isValidAfter, isTrue);

      // Should be set to default level
      final currentLevel = await SmartCropProfileManager.getCurrentLevel();
      expect(currentLevel, equals(SmartCropProfileManager.defaultLevel));
    });
  });
}
