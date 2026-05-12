import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/services/image_preloader.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:flutter/foundation.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final FetchDailyImagesUseCase _fetchDailyImagesUseCase;
  final ApplyWallpaperUseCase _applyWallpaperUseCase;
  final ImagePreloader _preloaderService;
  final PreferencesReader _prefs;

  HomeBloc({
    FetchDailyImagesUseCase? fetchDailyImagesUseCase,
    ApplyWallpaperUseCase? applyWallpaperUseCase,
    ImagePreloader? preloaderService,
    PreferencesReader? prefs,
  })  : _fetchDailyImagesUseCase = fetchDailyImagesUseCase ?? FetchDailyImagesUseCase(),
        _applyWallpaperUseCase = applyWallpaperUseCase ?? ApplyWallpaperUseCase(),
        _preloaderService = preloaderService ?? ImagePreloaderService(),
        _prefs = prefs ?? PrefHelperAdapter(),
        super(const HomeState.initial()) {
    on<HomeEventStarted>(_onStarted);
    on<HomeEventRefreshRequested>(_onRefreshRequested);
    on<HomeEventIndexChanged>(_onIndexChanged);
    on<HomeEventWallpaperUpdateRequested>(_onWallpaperUpdateRequested);
  }

  Future<void> _onStarted(HomeEventStarted event, Emitter<HomeState> emit) async {
    try {
      final images = await _fetchDailyImagesUseCase(forceRefresh: false);
      
      // Load saved index
      int initialIndex = await _prefs.getIntWithDefault(sp_LastViewedIndex, 0);
      if (initialIndex >= images.length) initialIndex = 0;

      // Check if we just successfully set a wallpaper (for green check persistence).
      // The window is 30s to survive the Activity restart triggered by Material You.
      String? lastSetId = await _prefs.getString(sp_LastSetWallpaperId);
      int lastSetTime = await _prefs.getIntWithDefault(sp_LastSetWallpaperTime, 0);
      String? wallpaperMessage;

      final now = DateTime.now().millisecondsSinceEpoch;
      if (lastSetId != null && (now - lastSetTime) < 30000) {
        // Search ALL images for the wallpaper that was set — do NOT rely on sp_LastViewedIndex.
        // The fake onPageChanged(0) fired by Material You during the theme change can overwrite
        // sp_LastViewedIndex to 0 before the Activity dies, causing an imageIdent mismatch.
        // Searching by imageIdent is robust against any index corruption.
        final setIndex = images.indexWhere((img) => img.imageIdent == lastSetId);
        if (setIndex >= 0) {
          wallpaperMessage = 'wallpaperSetSuccess';
          initialIndex = setIndex; // Restore carousel to the image that was actually applied.
        }
      }

      // CRITICAL: Emit loaded BEFORE preloading.
      // Previously, emit(loading) + preload ran first, causing:
      //   1. A brief black screen flash (loading state visible during restart)
      //   2. The wallpaperMessage checkmark being emitted too late (after the 5s window expired)
      // Now the UI is restored instantly on Activity restart, and the checkmark appears immediately.
      if (!isClosed) {
        emit(HomeState.loaded(
          list: images, 
          imageIndex: initialIndex,
          wallpaperMessage: wallpaperMessage,
        ));
      }

      // Preload runs in the background — does not block the UI.
      unawaited(
        _preloaderService.preloadImages(images, initialIndex)
            .timeout(const Duration(seconds: 45))
            .catchError((e) {
          debugPrint('Warning: Preloading timed out or failed ($e). Proceeding with available data.');
        }),
      );
    } catch (e) {
      if (!isClosed) {
        emit(HomeState.error('failedToFetchWallpapers: $e'));
      }
    }
  }

  Future<void> _onRefreshRequested(HomeEventRefreshRequested event, Emitter<HomeState> emit) async {
    emit(const HomeState.loading());
    try {
      final images = await _fetchDailyImagesUseCase(forceRefresh: true);
      
      // Reset saved index on manual refresh
      await _prefs.setInt(sp_LastViewedIndex, 0);

      // Emit loaded immediately; preload runs in the background.
      if (!isClosed) {
        emit(HomeState.loaded(list: images, imageIndex: 0));
      }

      unawaited(
        _preloaderService.preloadImages(images, 0)
            .timeout(const Duration(seconds: 45))
            .catchError((e) {
          debugPrint('Warning: Preloading timed out or failed ($e). Proceeding with available data.');
        }),
      );
    } catch (e) {
      if (!isClosed) {
        emit(HomeState.error('failedToRefreshWallpapers: $e'));
      }
    }
  }

  void _onIndexChanged(HomeEventIndexChanged event, Emitter<HomeState> emit) {
    state.mapOrNull(
      loaded: (loadedState) {
        if (event.newIndex >= 0 && event.newIndex < loadedState.list.length) {
          // Preserve wallpaperMessage if the index didn't actually change.
          // The Carousel fires _onChange during initialization after an Activity restart,
          // which would otherwise immediately clear the checkmark we just restored.
          final messageToKeep = (event.newIndex == loadedState.imageIndex)
              ? loadedState.wallpaperMessage
              : null;
          emit(loadedState.copyWith(imageIndex: event.newIndex, wallpaperMessage: messageToKeep));
          _preloaderService.preloadImages(loadedState.list, event.newIndex);

          // Save index to prefs
          _prefs.setInt(sp_LastViewedIndex, event.newIndex);
        }
      },
    );
  }

  Future<void> _onWallpaperUpdateRequested(HomeEventWallpaperUpdateRequested event, Emitter<HomeState> emit) async {
    await state.mapOrNull(
      loaded: (loadedState) async {
        emit(loadedState.copyWith(isSettingWallpaper: true, wallpaperMessage: null));
        try {
          final image = loadedState.list[loadedState.imageIndex];

          // CRITICAL: Save success prefs BEFORE applying the wallpaper.
          // Android restarts the Activity (Material You theme change) immediately after
          // WallpaperManager.setWallpaper() completes, which closes this BLoC.
          // BLoC B reads these prefs during _onStarted — if we write them AFTER the
          // wallpaper call, BLoC B may have already read them (race condition → no checkmark).
          await _prefs.setString(sp_LastSetWallpaperId, image.imageIdent);
          await _prefs.setInt(sp_LastSetWallpaperTime, DateTime.now().millisecondsSinceEpoch);

          final message = await _applyWallpaperUseCase(image);

          if (message != 'wallpaperSetSuccess') {
            // Application failed — clear the prefs we pre-saved so the checkmark doesn't show.
            await _prefs.setString(sp_LastSetWallpaperId, '');
            await _prefs.setInt(sp_LastSetWallpaperTime, 0);
          }

          if (!isClosed) {
            emit(loadedState.copyWith(
              isSettingWallpaper: false, 
              wallpaperMessage: message ?? 'wallpaperSetSuccess'
            ));
          }
        } catch (e) {
          // Clear pre-saved prefs on exception.
          await _prefs.setString(sp_LastSetWallpaperId, '');
          await _prefs.setInt(sp_LastSetWallpaperTime, 0);
          if (!isClosed) {
            emit(loadedState.copyWith(
              isSettingWallpaper: false, 
              wallpaperMessage: 'failedToSetWallpaper: $e'
            ));
          }
        }
      },
    );
  }

  @override
  Future<void> close() {
    // Do NOT clear the ImagePreloaderService cache here.
    // The Dart VM survives the Android Activity restart (same PID), so the cached
    // ui.Image objects in SmartCropper and ImagePreloaderService are still valid.
    // Calling clearCache() would dispose those images, causing BLoC B to render
    // corrupted or missing frames immediately after restart.
    return super.close();
  }
}
