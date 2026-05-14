import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/features/smart_crop/config/configuration_manager.dart';

class ConfigurationValidator {
  /// Validates imported configuration
  bool validateImportedConfig(Map<String, dynamic> config) {
    // Check required fields
    if (!config.containsKey('profile')) return false;

    // Validate profile index
    final profileIndex = config['profile'] as int?;
    if (profileIndex == null ||
        profileIndex < 0 ||
        profileIndex >= CropQualityProfile.values.length) {
      return false;
    }

    // Validate custom settings if present
    final customSettings = config['custom_settings'] as Map<String, dynamic>?;
    if (customSettings != null) {
      try {
        CropSettings.fromMap(customSettings);
      } catch (e) {
        return false;
      }
    }

    return true;
  }
}
