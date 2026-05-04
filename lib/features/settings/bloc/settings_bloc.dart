import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/data/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:dailywallpaper/features/settings/bloc/bing_region_state.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_event.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_state.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop.dart';
import 'package:dailywallpaper/services/smart_crop/utils/device_capability_detector.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  final PreferencesReader _prefHelper;
  final ImageRepository _imageRepository;

  SettingsBloc({
    PreferencesReader? prefHelper,
    ImageRepository? imageRepository,
  })  : _prefHelper = prefHelper ?? PrefHelperAdapter(),
        _imageRepository = imageRepository ?? ImageRepository(),
        super(SettingsState.initial()) {
    on<SettingsEventStarted>(_onStarted);
    on<SettingsEventRegionChanged>(_onRegionChanged);
    on<SettingsEventLockWallpaperToggled>(_onLockWallpaperToggled);
    on<SettingsEventSmartCropToggled>(_onSmartCropToggled);
    on<SettingsEventSmartCropLevelChanged>(_onSmartCropLevelChanged);
    on<SettingsEventSubjectScalingToggled>(_onSubjectScalingToggled);
  }

  Future<void> _onStarted(SettingsEventStarted event, Emitter<SettingsState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final regionStr = await _prefHelper.getStringWithDefault(sp_BingRegion, BingRegionEnum.definitionOf(BingRegionEnum.US));
      final selectedRegion = BingRegionEnum.valueFromDefinition(regionStr);
      final includeLock = await _prefHelper.getBoolWithDefault(sp_IncludeLockWallpaper, true);
      
      final smartCropEnabled = await SmartCropPreferences.isSmartCropEnabled();
      final smartCropLevel = await SmartCropProfileManager.getCurrentLevel();
      final cropSettings = await SmartCropPreferences.getCropSettings();
      
      final deviceCapability = await DeviceCapabilityDetector.getDeviceCapability();
      final thumbnails = await _fetchThumbnails();

      if (!isClosed) {
        emit(state.copyWith(
          selectedRegion: selectedRegion,
          includeLockWallpaper: includeLock,
          isSmartCropEnabled: smartCropEnabled,
          smartCropLevel: smartCropLevel,
          enableSubjectScaling: cropSettings.enableSubjectScaling,
          deviceCapability: deviceCapability,
          thumbnails: thumbnails,
          isLoading: false,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: 'failedToLoadSettings: $e'));
      }
    }
  }

  Future<void> _onRegionChanged(SettingsEventRegionChanged event, Emitter<SettingsState> emit) async {
    await _prefHelper.setString(sp_BingRegion, BingRegionEnum.definitionOf(event.region));
    if (!isClosed) {
      emit(state.copyWith(selectedRegion: event.region));
    }
  }

  Future<void> _onLockWallpaperToggled(SettingsEventLockWallpaperToggled event, Emitter<SettingsState> emit) async {
    await _prefHelper.setBool(sp_IncludeLockWallpaper, event.value);
    if (!isClosed) {
      emit(state.copyWith(includeLockWallpaper: event.value));
    }
  }

  Future<void> _onSmartCropToggled(SettingsEventSmartCropToggled event, Emitter<SettingsState> emit) async {
    if (event.value) {
      await SmartCropProfileManager.setSmartCropLevel(SmartCropProfileManager.defaultLevel);
    } else {
      await SmartCropProfileManager.setSmartCropLevel(0);
    }
    
    final newLevel = await SmartCropProfileManager.getCurrentLevel();
    
    if (!isClosed) {
      emit(state.copyWith(
        isSmartCropEnabled: event.value,
        smartCropLevel: newLevel,
      ));
    }
  }

  Future<void> _onSmartCropLevelChanged(SettingsEventSmartCropLevelChanged event, Emitter<SettingsState> emit) async {
    await SmartCropProfileManager.setSmartCropLevel(event.level);
    if (!isClosed) {
      emit(state.copyWith(
        smartCropLevel: event.level,
        isSmartCropEnabled: event.level > 0,
      ));
    }
  }

  Future<void> _onSubjectScalingToggled(SettingsEventSubjectScalingToggled event, Emitter<SettingsState> emit) async {
    final settings = await SmartCropPreferences.getCropSettings();
    await SmartCropPreferences.setCropSettings(settings.copyWith(enableSubjectScaling: event.value));
    if (!isClosed) {
      emit(state.copyWith(enableSubjectScaling: event.value));
    }
  }

  Future<List<RegionItem>> _fetchThumbnails() async {
    final futures = BingRegionEnum.values.map((region) async {
      try {
        final image = await _imageRepository.fetchThumbnailFromBing(
            BingRegionEnum.definitionOf(region));
        return RegionItem(region, image.url);
      } catch (e) {
        return RegionItem(region, "");
      }
    });

    return await Future.wait(futures);
  }
}
