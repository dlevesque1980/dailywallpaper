import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dailywallpaper/data/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/features/settings/bloc/bing_region_state.dart';
import 'package:dailywallpaper/services/smart_crop/utils/device_capability_detector.dart';

part 'settings_state.freezed.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    required BingRegionEnum selectedRegion,
    required bool includeLockWallpaper,
    required bool isSmartCropEnabled,
    required int smartCropLevel,
    required bool enableSubjectScaling,
    DeviceCapability? deviceCapability,
    required List<RegionItem> thumbnails,
    @Default(false) bool isLoading,
    String? error,
  }) = _SettingsState;

  factory SettingsState.initial() => const SettingsState(
        selectedRegion: BingRegionEnum.US,
        includeLockWallpaper: true,
        isSmartCropEnabled: false,
        smartCropLevel: 1,
        enableSubjectScaling: true,
        thumbnails: [],
        isLoading: true,
      );
}
