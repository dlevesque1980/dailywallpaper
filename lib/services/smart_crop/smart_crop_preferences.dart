import 'package:shared_preferences/shared_preferences.dart';
import '../../prefs/pref_helper.dart';
import '../../prefs/pref_consts.dart';
import 'models/crop_settings.dart';
import 'cache/crop_cache_manager.dart';

/// Manager for smart crop preferences and settings persistence
class SmartCropPreferences {
  static const int _currentVersion = 1;
  static const String _versionKey = 'smart_crop_settings_version';

  /// Gets whether smart crop is enabled
  static Future<bool> isSmartCropEnabled() async {
    return await PrefHelper.getBoolWithDefault(sp_SmartCropEnabled, true);
  }

  /// Sets whether smart crop is enabled
  static Future<bool> setSmartCropEnabled(bool enabled) async {
    return await PrefHelper.setBool(sp_SmartCropEnabled, enabled);
  }

  /// Gets the current crop settings
  static Future<CropSettings> getCropSettings() async {
    try {
      // Check if we need to migrate settings
      await _migrateSettingsIfNeeded();

      final aggressivenessIndex = await _getIntWithDefault(sp_SmartCropAggressiveness, CropAggressiveness.balanced.index);
      final enableRuleOfThirds = await PrefHelper.getBoolWithDefault(sp_SmartCropRuleOfThirds, true);
      final enableEntropyAnalysis = await PrefHelper.getBoolWithDefault(sp_SmartCropEntropyAnalysis, true);
      final enableEdgeDetection = await PrefHelper.getBoolWithDefault(sp_SmartCropEdgeDetection, false);
      final enableCenterWeighting = await PrefHelper.getBoolWithDefault(sp_SmartCropCenterWeighting, true);
      final maxProcessingTimeMs = await _getIntWithDefault(sp_SmartCropMaxProcessingTime, 2000);

      // Clamp aggressiveness index to valid range
      final clampedAggressivenessIndex = aggressivenessIndex.clamp(0, CropAggressiveness.values.length - 1);
      // Clamp processing time to reasonable range
      final clampedProcessingTimeMs = maxProcessingTimeMs.clamp(500, 10000);

      final settings = CropSettings(
        aggressiveness: CropAggressiveness.values[clampedAggressivenessIndex],
        enableRuleOfThirds: enableRuleOfThirds,
        enableEntropyAnalysis: enableEntropyAnalysis,
        enableEdgeDetection: enableEdgeDetection,
        enableCenterWeighting: enableCenterWeighting,
        maxProcessingTime: Duration(milliseconds: clampedProcessingTimeMs),
      );

      // Validate settings and return default if invalid
      return settings.isValid ? settings : CropSettings.defaultSettings;
    } catch (e) {
      // Return default settings if any error occurs
      return CropSettings.defaultSettings;
    }
  }

  /// Saves crop settings to preferences
  static Future<bool> saveCropSettings(CropSettings settings) async {
    try {
      // Validate settings before saving
      if (!settings.isValid) {
        return false;
      }

      final results = await Future.wait([
        _setInt(sp_SmartCropAggressiveness, settings.aggressiveness.index),
        PrefHelper.setBool(sp_SmartCropRuleOfThirds, settings.enableRuleOfThirds),
        PrefHelper.setBool(sp_SmartCropEntropyAnalysis, settings.enableEntropyAnalysis),
        PrefHelper.setBool(sp_SmartCropEdgeDetection, settings.enableEdgeDetection),
        PrefHelper.setBool(sp_SmartCropCenterWeighting, settings.enableCenterWeighting),
        _setInt(sp_SmartCropMaxProcessingTime, settings.maxProcessingTime.inMilliseconds),
      ]);

      // Update version after successful save
      await _setInt(_versionKey, _currentVersion);

      return results.every((result) => result);
    } catch (e) {
      return false;
    }
  }

  /// Resets all smart crop settings to defaults
  static Future<bool> resetToDefaults() async {
    return await saveCropSettings(CropSettings.defaultSettings);
  }

  /// Gets crop aggressiveness setting
  static Future<CropAggressiveness> getCropAggressiveness() async {
    final index = await _getIntWithDefault(sp_SmartCropAggressiveness, CropAggressiveness.balanced.index);
    return CropAggressiveness.values[index.clamp(0, CropAggressiveness.values.length - 1)];
  }

  /// Sets crop aggressiveness setting
  static Future<bool> setCropAggressiveness(CropAggressiveness aggressiveness) async {
    return await _setInt(sp_SmartCropAggressiveness, aggressiveness.index);
  }

  /// Validates current settings and fixes any issues
  static Future<CropSettings> validateAndFixSettings() async {
    final settings = await getCropSettings();
    
    if (!settings.isValid) {
      // If settings are invalid, reset to defaults
      await resetToDefaults();
      return CropSettings.defaultSettings;
    }
    
    return settings;
  }

  /// Migrates settings from older versions if needed
  static Future<void> _migrateSettingsIfNeeded() async {
    final currentVersion = await _getIntWithDefault(_versionKey, 0);
    
    if (currentVersion < _currentVersion) {
      // Perform migration based on version
      switch (currentVersion) {
        case 0:
          // First time setup - ensure defaults are set
          await resetToDefaults();
          break;
        // Add more migration cases as needed for future versions
      }
      
      await _setInt(_versionKey, _currentVersion);
    }
  }

  /// Helper method to get int from preferences with default
  static Future<int> _getIntWithDefault(String key, int defaultValue) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(key) ?? defaultValue;
  }

  /// Helper method to set int in preferences
  static Future<bool> _setInt(String key, int value) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.setInt(key, value);
  }

  /// Gets a summary of current settings for debugging
  static Future<Map<String, dynamic>> getSettingsSummary() async {
    final enabled = await isSmartCropEnabled();
    final settings = await getCropSettings();
    
    return {
      'enabled': enabled,
      'aggressiveness': settings.aggressiveness.name,
      'enabledStrategies': settings.enabledStrategies,
      'maxProcessingTimeMs': settings.maxProcessingTime.inMilliseconds,
      'isValid': settings.isValid,
    };
  }

  /// Gets cache statistics
  static Future<Map<String, dynamic>> getCacheStatistics() async {
    try {
      final cacheManager = CropCacheManager();
      final stats = await cacheManager.getStats();
      final hitRate = await cacheManager.getHitRateStats();
      
      return {
        'totalEntries': stats.totalEntries,
        'totalSizeMB': stats.totalSizeMB,
        'averageAccessCount': stats.averageAccessCount,
        'hitRatePercentage': hitRate.hitRatePercentage,
        'cacheAgeDays': stats.cacheAge?.inDays ?? 0,
        'oldestEntry': stats.oldestEntry?.toIso8601String(),
        'newestEntry': stats.newestEntry?.toIso8601String(),
      };
    } catch (e) {
      return {
        'totalEntries': 0,
        'totalSizeMB': 0.0,
        'averageAccessCount': 0.0,
        'hitRatePercentage': 0.0,
        'cacheAgeDays': 0,
        'error': e.toString(),
      };
    }
  }

  /// Clears the crop cache
  static Future<int> clearCropCache() async {
    try {
      final cacheManager = CropCacheManager();
      return await cacheManager.clearCache();
    } catch (e) {
      return 0;
    }
  }

  /// Optimizes the crop cache
  static Future<int> optimizeCropCache() async {
    try {
      final cacheManager = CropCacheManager();
      return await cacheManager.optimizeCache();
    } catch (e) {
      return 0;
    }
  }

  /// Performs cache maintenance
  static Future<Map<String, dynamic>> performCacheMaintenance() async {
    try {
      final cacheManager = CropCacheManager();
      final result = await cacheManager.performMaintenance();
      
      return {
        'expiredDeleted': result.expiredEntriesDeleted,
        'lruDeleted': result.lruEntriesEvicted,
        'totalDeleted': result.totalEntriesDeleted,
        'success': result.success,
      };
    } catch (e) {
      return {
        'expiredDeleted': 0,
        'lruDeleted': 0,
        'totalDeleted': 0,
        'success': false,
      };
    }
  }
}