import 'package:dailywallpaper/core/preferences/pref_helper.dart';

class ConfigurationMigrator {
  final String migrationVersionKey;
  final int currentMigrationVersion;

  ConfigurationMigrator({
    required this.migrationVersionKey,
    required this.currentMigrationVersion,
  });

  /// Performs migration if needed
  Future<void> performMigrationIfNeeded() async {
    final currentVersion = await PrefHelper.getInt(migrationVersionKey) ?? 0;

    if (currentVersion < currentMigrationVersion) {
      await performMigration(currentVersion, currentMigrationVersion);
      await PrefHelper.setInt(migrationVersionKey, currentMigrationVersion);
    }
  }

  /// Performs migration from old version to new version
  Future<void> performMigration(int fromVersion, int toVersion) async {
    // Migration logic would go here
    // For now, we'll just clear old settings if migrating from version 0
    if (fromVersion == 0) {
      // This is a fresh install or upgrade from v1
      // Clear any old v1 settings that might conflict
      await clearLegacySettings();
    }
  }

  /// Clears legacy v1 settings
  Future<void> clearLegacySettings() async {
    // Clear old smart crop settings that might conflict
    const legacyKeys = [
      'smart_crop_aggressiveness',
      'smart_crop_enable_rule_of_thirds',
      'smart_crop_enable_entropy',
      'smart_crop_enable_edge_detection',
    ];

    for (final key in legacyKeys) {
      await PrefHelper.remove(key);
    }
  }
}
