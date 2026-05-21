import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dailywallpaper/features/smart_crop/config/configuration_migrator.dart';
import 'package:dailywallpaper/core/preferences/pref_helper.dart';

void main() {
  group('ConfigurationMigrator', () {
    late ConfigurationMigrator migrator;
    const migrationKey = 'test_migration_version';

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      migrator = ConfigurationMigrator(
        migrationVersionKey: migrationKey,
        currentMigrationVersion: 1,
      );
    });

    test('performMigrationIfNeeded runs migration and sets new version',
        () async {
      await PrefHelper.setString('smart_crop_aggressiveness', 'test');

      await migrator.performMigrationIfNeeded();

      final newVersion = await PrefHelper.getInt(migrationKey);
      expect(newVersion, 1);

      final legacyValue =
          await PrefHelper.getString('smart_crop_aggressiveness');
      expect(legacyValue, isNull);
    });

    test('performMigrationIfNeeded does not run if already migrated', () async {
      await PrefHelper.setInt(migrationKey, 1);
      await PrefHelper.setString('smart_crop_aggressiveness', 'test');

      await migrator.performMigrationIfNeeded();

      final legacyValue =
          await PrefHelper.getString('smart_crop_aggressiveness');
      expect(legacyValue, 'test'); // Should not be cleared
    });
  });
}
