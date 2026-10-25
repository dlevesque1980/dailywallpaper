import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/data/datasources/supabase_downloader_settings_data_source.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_event.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SettingsBloc extends Bloc<SettingsEvent, SettingsState> {
  SettingsBloc({
    PreferencesReader? prefHelper,
    DownloaderSettingsDataSource? downloaderSettings,
  })  : _prefHelper = prefHelper ?? PrefHelperAdapter(),
        _downloaderSettings =
            downloaderSettings ?? SupabaseDownloaderSettingsDataSource(),
        super(SettingsState.initial()) {
    on<SettingsEventStarted>(_onStarted);
    on<SettingsEventLockWallpaperToggled>(_onLockWallpaperToggled);
    on<SettingsEventNasaToggled>(_onNasaToggled);
    on<SettingsEventCategoriesChanged>(_onCategoriesChanged);
  }

  final PreferencesReader _prefHelper;
  final DownloaderSettingsDataSource _downloaderSettings;

  Future<void> _onStarted(
    SettingsEventStarted event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final includeLock = await _prefHelper.getBoolWithDefault(
        includeLockWallpaperPreference,
        true,
      );
      final downloaderSettings = await _downloaderSettings.fetchSettings();
      if (!isClosed) {
        emit(state.copyWith(
          includeLockWallpaper: includeLock,
          includeNasa: downloaderSettings.includeNasa,
          selectedCategories: downloaderSettings.pexelsCategories,
          isLoading: false,
        ));
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          isLoading: false,
          error: 'failedToLoadSettings: $error',
        ));
      }
    }
  }

  Future<void> _onLockWallpaperToggled(
    SettingsEventLockWallpaperToggled event,
    Emitter<SettingsState> emit,
  ) async {
    try {
      await _prefHelper.setBool(includeLockWallpaperPreference, event.value);
      if (!isClosed) {
        emit(state.copyWith(includeLockWallpaper: event.value, error: null));
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(error: 'failedToSaveSettings: $error'));
      }
    }
  }

  Future<void> _onNasaToggled(
    SettingsEventNasaToggled event,
    Emitter<SettingsState> emit,
  ) async {
    emit(state.copyWith(isSavingNasa: true, error: null));
    try {
      await _downloaderSettings.updateSettings(includeNasa: event.value);
      if (!isClosed) {
        emit(state.copyWith(includeNasa: event.value, isSavingNasa: false));
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          isSavingNasa: false,
          error: 'failedToSaveNasaSetting: $error',
        ));
      }
    }
  }

  Future<void> _onCategoriesChanged(
    SettingsEventCategoriesChanged event,
    Emitter<SettingsState> emit,
  ) async {
    if (event.categories.isEmpty ||
        event.categories.length > maxPexelsCategories) {
      emit(state.copyWith(
        error: 'Select between one and three Pexels categories.',
      ));
      return;
    }

    emit(state.copyWith(isSavingCategories: true, error: null));
    try {
      await _downloaderSettings.updateSettings(
        pexelsCategories: event.categories,
      );
      if (!isClosed) {
        emit(state.copyWith(
          selectedCategories: event.categories,
          isSavingCategories: false,
        ));
      }
    } catch (error) {
      if (!isClosed) {
        emit(state.copyWith(
          isSavingCategories: false,
          error: 'failedToSavePexelsCategories: $error',
        ));
      }
    }
  }
}
