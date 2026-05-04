import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dailywallpaper/data/models/bing/bing_region_enum.dart';

part 'settings_event.freezed.dart';

@freezed
sealed class SettingsEvent with _$SettingsEvent {
  const factory SettingsEvent.started() = SettingsEventStarted;
  const factory SettingsEvent.regionChanged(BingRegionEnum region) = SettingsEventRegionChanged;
  const factory SettingsEvent.lockWallpaperToggled(bool value) = SettingsEventLockWallpaperToggled;
  const factory SettingsEvent.smartCropToggled(bool value) = SettingsEventSmartCropToggled;
  const factory SettingsEvent.smartCropLevelChanged(int level) = SettingsEventSmartCropLevelChanged;
  const factory SettingsEvent.subjectScalingToggled(bool value) = SettingsEventSubjectScalingToggled;
}
