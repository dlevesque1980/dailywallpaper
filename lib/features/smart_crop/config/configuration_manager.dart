import 'dart:convert';
import '../models/crop_settings.dart';
import 'package:dailywallpaper/core/preferences/pref_helper.dart';
import 'configuration_validator.dart';
import 'configuration_migrator.dart';

/// Quality profiles for crop analysis
enum CropQualityProfile {
  /// Fast processing with basic analysis
  fast,

  /// Balanced processing with moderate analysis
  balanced,

  /// High quality processing with comprehensive analysis
  highQuality,

  /// Custom profile with user-defined settings
  custom,
}

/// Configuration manager for Smart Crop v2 settings
class ConfigurationManager {
  static final ConfigurationManager _instance =
      ConfigurationManager._internal();
  factory ConfigurationManager() => _instance;
  ConfigurationManager._internal() {
    _migrator = ConfigurationMigrator(
      migrationVersionKey: _migrationVersionKey,
      currentMigrationVersion: _currentMigrationVersion,
    );
  }

  static const String _configKeyPrefix = 'smart_crop_v2_';
  static const String _profileKey = '${_configKeyPrefix}profile';
  static const String _customSettingsKey = '${_configKeyPrefix}custom_settings';
  static const String _analyzerConfigKey = '${_configKeyPrefix}analyzer_config';
  static const String _migrationVersionKey =
      '${_configKeyPrefix}migration_version';

  static const int _currentMigrationVersion = 1;

  CropQualityProfile _currentProfile = CropQualityProfile.balanced;
  CropSettings _customSettings = CropSettings.defaultSettings;
  Map<String, Map<String, dynamic>> _analyzerConfigs = {};
  bool _isInitialized = false;
  final ConfigurationValidator _validator = ConfigurationValidator();
  late final ConfigurationMigrator _migrator;

  /// Initializes the configuration manager
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check if migration is needed
      await _migrator.performMigrationIfNeeded();

      // Load current profile
      final profileIndex = await PrefHelper.getInt(_profileKey) ??
          CropQualityProfile.balanced.index;
      _currentProfile = CropQualityProfile.values[profileIndex];

      // Load custom settings
      final customSettingsJson = await PrefHelper.getString(_customSettingsKey);
      if (customSettingsJson != null && customSettingsJson.isNotEmpty) {
        try {
          _customSettings = CropSettings.fromJson(customSettingsJson);
        } catch (e) {
          // If parsing fails, use default settings
          _customSettings = CropSettings.defaultSettings;
        }
      }

      // Load analyzer-specific configurations
      final analyzerConfigJson = await PrefHelper.getString(_analyzerConfigKey);
      if (analyzerConfigJson != null && analyzerConfigJson.isNotEmpty) {
        try {
          final decoded =
              jsonDecode(analyzerConfigJson) as Map<String, dynamic>;
          _analyzerConfigs =
              decoded.map((k, v) => MapEntry(k, v as Map<String, dynamic>));
        } catch (e) {
          // If parsing fails, use empty config
          _analyzerConfigs = {};
        }
      }

      _isInitialized = true;
    } catch (e) {
      // If initialization fails, use defaults
      _currentProfile = CropQualityProfile.balanced;
      _customSettings = CropSettings.defaultSettings;
      _analyzerConfigs = {};
      _isInitialized = true;
    }
  }

  /// Gets the current quality profile
  CropQualityProfile get currentProfile => _currentProfile;

  /// Sets the current quality profile
  Future<void> setProfile(CropQualityProfile profile) async {
    _ensureInitialized();
    _currentProfile = profile;
    await PrefHelper.setInt(_profileKey, profile.index);
  }

  /// Gets crop settings for the current profile
  CropSettings getCurrentSettings() {
    _ensureInitialized();

    switch (_currentProfile) {
      case CropQualityProfile.fast:
        return _getFastSettings();
      case CropQualityProfile.balanced:
        return _getBalancedSettings();
      case CropQualityProfile.highQuality:
        return _getHighQualitySettings();
      case CropQualityProfile.custom:
        return _customSettings;
    }
  }

  /// Gets crop settings for a specific profile
  CropSettings getSettingsForProfile(CropQualityProfile profile) {
    switch (profile) {
      case CropQualityProfile.fast:
        return _getFastSettings();
      case CropQualityProfile.balanced:
        return _getBalancedSettings();
      case CropQualityProfile.highQuality:
        return _getHighQualitySettings();
      case CropQualityProfile.custom:
        return _customSettings;
    }
  }

  /// Updates custom settings
  Future<void> setCustomSettings(CropSettings settings) async {
    _ensureInitialized();
    _customSettings = settings;
    await PrefHelper.setString(_customSettingsKey, settings.toJson());
  }

  /// Gets custom settings
  CropSettings get customSettings => _customSettings;

  /// Sets analyzer-specific configuration
  Future<void> setAnalyzerConfig(
      String analyzerName, Map<String, dynamic> config) async {
    _ensureInitialized();
    _analyzerConfigs[analyzerName] = Map.from(config);
    await _saveAnalyzerConfigs();
  }

  /// Gets analyzer-specific configuration
  Map<String, dynamic> getAnalyzerConfig(String analyzerName) {
    _ensureInitialized();
    return Map.from(_analyzerConfigs[analyzerName] ?? {});
  }

  /// Gets all analyzer configurations
  Map<String, Map<String, dynamic>> getAllAnalyzerConfigs() {
    _ensureInitialized();
    return Map.from(_analyzerConfigs);
  }

  /// Removes analyzer configuration
  Future<void> removeAnalyzerConfig(String analyzerName) async {
    _ensureInitialized();
    _analyzerConfigs.remove(analyzerName);
    await _saveAnalyzerConfigs();
  }

  /// Resets all settings to defaults
  Future<void> resetToDefaults() async {
    _ensureInitialized();

    _currentProfile = CropQualityProfile.balanced;
    _customSettings = CropSettings.defaultSettings;
    _analyzerConfigs.clear();

    await Future.wait([
      PrefHelper.setInt(_profileKey, _currentProfile.index),
      PrefHelper.setString(_customSettingsKey, _customSettings.toJson()),
      PrefHelper.setString(_analyzerConfigKey, '{}'),
    ]);
  }

  /// Exports current configuration to a map
  Map<String, dynamic> exportConfiguration() {
    _ensureInitialized();

    return {
      'profile': _currentProfile.index,
      'custom_settings': _customSettings.toMap(),
      'analyzer_configs': _analyzerConfigs,
      'export_timestamp': DateTime.now().toIso8601String(),
      'version': _currentMigrationVersion,
    };
  }

  /// Imports configuration from a map
  Future<bool> importConfiguration(Map<String, dynamic> config) async {
    _ensureInitialized();

    try {
      // Validate the configuration
      if (!_validator.validateImportedConfig(config)) {
        return false;
      }

      // Import profile
      final profileIndex =
          config['profile'] as int? ?? CropQualityProfile.balanced.index;
      _currentProfile = CropQualityProfile.values[profileIndex];

      // Import custom settings
      final customSettingsMap =
          config['custom_settings'] as Map<String, dynamic>?;
      if (customSettingsMap != null) {
        _customSettings = CropSettings.fromMap(customSettingsMap);
      }

      // Import analyzer configs
      final analyzerConfigs =
          config['analyzer_configs'] as Map<String, dynamic>?;
      if (analyzerConfigs != null) {
        _analyzerConfigs = analyzerConfigs
            .map((k, v) => MapEntry(k, v as Map<String, dynamic>));
      }

      // Save to preferences
      await Future.wait([
        PrefHelper.setInt(_profileKey, _currentProfile.index),
        PrefHelper.setString(_customSettingsKey, _customSettings.toJson()),
        _saveAnalyzerConfigs(),
      ]);

      return true;
    } catch (e) {
      return false;
    }
  }

  /// Gets configuration statistics
  Map<String, dynamic> getStats() {
    _ensureInitialized();

    return {
      'current_profile': _currentProfile.toString(),
      'analyzer_configs_count': _analyzerConfigs.length,
      'custom_settings': _customSettings.toMap(),
      'is_initialized': _isInitialized,
    };
  }

  /// Fast quality settings
  CropSettings _getFastSettings() {
    return const CropSettings(
      aggressiveness: CropAggressiveness.conservative,
      enableRuleOfThirds: true,
      enableEntropyAnalysis: false,
      enableEdgeDetection: false,
      enableCenterWeighting: true,
      maxProcessingTime: Duration(milliseconds: 500),
      enableBatteryOptimization: true,
      maxCropCandidates: 3,
    );
  }

  /// Balanced quality settings
  CropSettings _getBalancedSettings() {
    return const CropSettings(
      aggressiveness: CropAggressiveness.balanced,
      enableRuleOfThirds: true,
      enableEntropyAnalysis: true,
      enableEdgeDetection: false,
      enableCenterWeighting: true,
      maxProcessingTime: Duration(seconds: 2),
      enableBatteryOptimization: false,
      maxCropCandidates: 8,
    );
  }

  /// High quality settings
  CropSettings _getHighQualitySettings() {
    return const CropSettings(
      aggressiveness: CropAggressiveness.aggressive,
      enableRuleOfThirds: true,
      enableEntropyAnalysis: true,
      enableEdgeDetection: true,
      enableCenterWeighting: true,
      maxProcessingTime: Duration(seconds: 5),
      enableBatteryOptimization: false,
      maxCropCandidates: 15,
    );
  }

  Future<void> _saveAnalyzerConfigs() async {
    final json = jsonEncode(_analyzerConfigs);
    await PrefHelper.setString(_analyzerConfigKey, json);
  }

  /// Ensures the configuration manager is initialized
  void _ensureInitialized() {
    if (!_isInitialized) {
      throw StateError(
          'ConfigurationManager not initialized. Call initialize() first.');
    }
  }

  /// Disposes the configuration manager
  void dispose() {
    _isInitialized = false;
    _analyzerConfigs.clear();
  }
}
