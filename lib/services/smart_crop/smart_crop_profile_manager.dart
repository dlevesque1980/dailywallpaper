import 'models/crop_settings.dart';
import 'smart_crop_preferences.dart';

/// Manager for Smart Crop quality profiles with 4 predefined levels
///
/// This service provides a simplified interface for managing Smart Crop settings
/// through predefined quality levels, each optimized for battery usage.
class SmartCropProfileManager {
  /// Labels for each quality level
  static const Map<int, String> levelLabels = {
    0: "Off",
    1: "Conservative",
    2: "Balanced",
    3: "Aggressive"
  };

  /// Descriptions for each quality level
  static const Map<int, String> levelDescriptions = {
    0: "Smart Crop disabled - uses standard cropping",
    1: "Conservative quality - minimal processing, maximum battery life",
    2: "Balanced quality - optimal performance and battery balance (recommended)",
    3: "Aggressive quality - maximum quality, higher battery usage"
  };

  /// Default quality level (Balanced)
  static const int defaultLevel = 2;

  /// Sets the Smart Crop quality level
  ///
  /// [level] must be between 0-3:
  /// - 0: Smart Crop disabled
  /// - 1: Conservative (battery optimized)
  /// - 2: Balanced (default, recommended)
  /// - 3: Aggressive (quality optimized)
  static Future<bool> setSmartCropLevel(int level) async {
    if (level < 0 || level > 3) {
      throw ArgumentError(
          'Smart Crop level must be between 0 and 3, got: $level');
    }

    try {
      final currentSettings = await SmartCropPreferences.getCropSettings();
      final currentScaling = currentSettings.enableSubjectScaling;
      
      switch (level) {
        case 0:
          // Disable Smart Crop completely
          return await SmartCropPreferences.setSmartCropEnabled(false);

        case 1:
          // Conservative: Enable with conservative settings + battery optimization
          await SmartCropPreferences.setSmartCropEnabled(true);
          return await SmartCropPreferences.setCropSettings(
              CropSettings.conservative.copyWith(
            enableBatteryOptimization: true,
            maxProcessingTime: const Duration(seconds: 1),
            maxCropCandidates: 3,
            enableSubjectScaling: currentScaling,
          ));

        case 2:
          // Balanced: Enable with balanced settings + battery optimization (DEFAULT)
          await SmartCropPreferences.setSmartCropEnabled(true);
          return await SmartCropPreferences.setCropSettings(
              CropSettings.balanced.copyWith(
            enableBatteryOptimization: true,
            maxProcessingTime: const Duration(seconds: 2),
            maxCropCandidates: 5,
            enableSubjectScaling: currentScaling,
          ));

        case 3:
          // Aggressive: Enable with aggressive settings + battery optimization
          await SmartCropPreferences.setSmartCropEnabled(true);
          return await SmartCropPreferences.setCropSettings(
              CropSettings.aggressive.copyWith(
            enableBatteryOptimization: true,
            maxProcessingTime: const Duration(seconds: 3),
            maxCropCandidates: 8,
            enableSubjectScaling: currentScaling,
          ));

        default:
          return false;
      }
    } catch (e) {
      // If any error occurs, fallback to default level
      return await setSmartCropLevel(defaultLevel);
    }
  }

  /// Gets the current Smart Crop quality level
  ///
  /// Returns:
  /// - 0: Smart Crop disabled
  /// - 1: Conservative level
  /// - 2: Balanced level (default)
  /// - 3: Aggressive level
  static Future<int> getCurrentLevel() async {
    try {
      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();
      if (!isEnabled) {
        return 0;
      }

      final settings = await SmartCropPreferences.getCropSettings();

      // Determine level based on aggressiveness and processing time
      switch (settings.aggressiveness) {
        case CropAggressiveness.conservative:
          return 1;
        case CropAggressiveness.balanced:
          return 2;
        case CropAggressiveness.aggressive:
          return 3;
      }
    } catch (e) {
      // Return default level if any error occurs
      return defaultLevel;
    }
  }

  /// Gets the label for a specific level
  static String getLevelLabel(int level) {
    return levelLabels[level] ?? "Unknown";
  }

  /// Gets the description for a specific level
  static String getLevelDescription(int level) {
    return levelDescriptions[level] ?? "Unknown level";
  }

  /// Gets all available levels with their labels and descriptions
  static Map<int, Map<String, String>> getAllLevels() {
    return {
      for (int level in levelLabels.keys)
        level: {
          'label': levelLabels[level]!,
          'description': levelDescriptions[level]!,
        }
    };
  }

  /// Initializes Smart Crop with default settings if not already configured
  static Future<bool> initializeWithDefaults() async {
    try {
      final currentLevel = await getCurrentLevel();

      // If Smart Crop is disabled (level 0) and no explicit configuration exists,
      // set it to the default balanced level
      if (currentLevel == 0) {
        final settings = await SmartCropPreferences.getCropSettings();

        // Check if this is a fresh install (default settings)
        if (settings == CropSettings.defaultSettings) {
          return await setSmartCropLevel(defaultLevel);
        }
      }

      return true;
    } catch (e) {
      // If initialization fails, set to default level
      return await setSmartCropLevel(defaultLevel);
    }
  }

  /// Validates that the current configuration matches one of the predefined levels
  static Future<bool> validateCurrentConfiguration() async {
    try {
      final currentLevel = await getCurrentLevel();
      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();

      // Level 0 should have Smart Crop disabled
      if (currentLevel == 0 && isEnabled) {
        return false;
      }

      // Levels 1-3 should have Smart Crop enabled with battery optimization
      if (currentLevel > 0) {
        if (!isEnabled) {
          return false;
        }

        final settings = await SmartCropPreferences.getCropSettings();
        if (!settings.enableBatteryOptimization) {
          return false;
        }
      }

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Repairs the configuration if it's invalid by setting it to the default level
  static Future<bool> repairConfiguration() async {
    try {
      final isValid = await validateCurrentConfiguration();
      if (!isValid) {
        return await setSmartCropLevel(defaultLevel);
      }
      return true;
    } catch (e) {
      return await setSmartCropLevel(defaultLevel);
    }
  }

  /// Gets a summary of the current profile configuration
  static Future<Map<String, dynamic>> getProfileSummary() async {
    try {
      final level = await getCurrentLevel();
      final isEnabled = await SmartCropPreferences.isSmartCropEnabled();
      final settings = await SmartCropPreferences.getCropSettings();

      return {
        'level': level,
        'label': getLevelLabel(level),
        'description': getLevelDescription(level),
        'enabled': isEnabled,
        'batteryOptimized': settings.enableBatteryOptimization,
        'aggressiveness': settings.aggressiveness.name,
        'processingTimeMs': settings.maxProcessingTime.inMilliseconds,
        'maxCandidates': settings.maxCropCandidates,
        'isValid': await validateCurrentConfiguration(),
      };
    } catch (e) {
      return {
        'level': 0,
        'label': 'Error',
        'description': 'Failed to get profile summary',
        'enabled': false,
        'batteryOptimized': false,
        'error': e.toString(),
      };
    }
  }
}
