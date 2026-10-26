import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_event.freezed.dart';

@freezed
sealed class SettingsEvent with _$SettingsEvent {
  const factory SettingsEvent.started() = SettingsEventStarted;
  const factory SettingsEvent.lockWallpaperToggled(bool value) =
      SettingsEventLockWallpaperToggled;
  const factory SettingsEvent.nasaToggled(bool value) =
      SettingsEventNasaToggled;
  const factory SettingsEvent.categoriesChanged(List<String> categories) =
      SettingsEventCategoriesChanged;
}
