import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/services/image_preloader.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/request_initial_permissions.dart';
import 'package:flutter/foundation.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final FetchDailyImagesUseCase _fetchDailyImagesUseCase;
  final ApplyWallpaperUseCase _applyWallpaperUseCase;
  final ImagePreloader _preloaderService;
  final PreferencesReader _prefs;
  final RequestInitialPermissionsUseCase _requestInitialPermissionsUseCase;

  HomeBloc({
    FetchDailyImagesUseCase? fetchDailyImagesUseCase,
    ApplyWallpaperUseCase? applyWallpaperUseCase,
    ImagePreloader? preloaderService,
    PreferencesReader? prefs,
    RequestInitialPermissionsUseCase? requestInitialPermissionsUseCase,
  })  : _fetchDailyImagesUseCase =
            fetchDailyImagesUseCase ?? FetchDailyImagesUseCase(),
        _applyWallpaperUseCase =
            applyWallpaperUseCase ?? ApplyWallpaperUseCase(),
        _preloaderService = preloaderService ?? ImagePreloaderService(),
        _prefs = prefs ?? PrefHelperAdapter(),
        _requestInitialPermissionsUseCase = requestInitialPermissionsUseCase ??
            RequestInitialPermissionsUseCase(),
        super(const HomeState.initial()) {
    on<HomeEventStarted>(_onStarted);
    on<HomeEventRefreshRequested>(_onRefreshRequested);
    on<HomeEventIndexChanged>(_onIndexChanged);
    on<HomeEventWallpaperUpdateRequested>(_onWallpaperUpdateRequested);
    on<HomeEventCropStatusChanged>(_onCropStatusChanged);
  }

  bool _isCropReady(ImageItem image) {
    return _preloaderService.getProcessedImage(image) != null ||
        image.localProcessedPath != null;
  }

  bool _isSourceReady(ImageItem image) {
    return _preloaderService.getPreloadedImage(image) != null ||
        image.localSourcePath != null;
  }

  void _monitorCropProcessing(ImageItem image) {
    unawaited(() async {
      int idleChecks = 0;

      while (!isClosed && !_isCropReady(image)) {
        final loadingTask = _preloaderService.getLoadingTask(image);
        if (loadingTask != null) {
          idleChecks = 0;
          await loadingTask.catchError((_) => null);
          continue;
        }

        final processingTask = _preloaderService.getProcessingTask(image);
        if (processingTask != null) {
          idleChecks = 0;
          await processingTask.catchError((_) => null);
          continue;
        }

        // Neither task is present, but image is still not ready.
        // This bridges the microtask gap between loading finish and processing start.
        await Future.delayed(const Duration(milliseconds: 100));
        idleChecks++;

        // If we've been idle for 500ms with no tasks, give up to avoid infinite loop.
        if (idleChecks >= 5) {
          break;
        }
      }
      
      if (!isClosed) {
        add(HomeEvent.cropStatusChanged(
            imageIdent: image.imageIdent, isProcessing: false));
      }
    }());
  }

  Future<void> _onStarted(
      HomeEventStarted event, Emitter<HomeState> emit) async {
    try {
      // 1. Request permissions at startup
      await _requestInitialPermissionsUseCase();

      // 2. Cache-First: Fetch cached images instantly from DB (0ms wait time for user)
      final cachedImages = await _fetchDailyImagesUseCase.getCachedImages();
      int initialIndex = await _prefs.getIntWithDefault(sp_LastViewedIndex, 0);

      String? lastSetId = await _prefs.getString(sp_LastSetWallpaperId);
      int lastSetTime =
          await _prefs.getIntWithDefault(sp_LastSetWallpaperTime, 0);
      String? wallpaperMessage;
      final now = DateTime.now().millisecondsSinceEpoch;

      if (cachedImages.isNotEmpty) {
        if (initialIndex >= cachedImages.length) initialIndex = 0;

        if (lastSetId != null && (now - lastSetTime) < 30000) {
          final setIndex =
              cachedImages.indexWhere((img) => img.imageIdent == lastSetId);
          if (setIndex >= 0) {
            wallpaperMessage = 'wallpaperSetSuccess';
            initialIndex = setIndex;
          }
        }

        final initialImage = cachedImages[initialIndex];
        final isReady = _isCropReady(initialImage);
        final isSrcReady = _isSourceReady(initialImage);

        if (!isClosed) {
          emit(HomeState.loaded(
            list: cachedImages,
            imageIndex: initialIndex,
            wallpaperMessage: wallpaperMessage,
            isCropProcessing: !isReady,
            isSourceLoading: !isSrcReady,
          ));
        }

        // Start preloading the cached images immediately
        unawaited(
          _preloaderService
              .preloadImages(cachedImages, initialIndex)
              .catchError(
                  (e) => debugPrint('Error preloading cached images: $e')),
        );

        if (!isReady) {
          _monitorCropProcessing(initialImage);
        }
      }

      // 3. Network fetch in background/sequence to load fresh wallpapers
      final freshImages = await _fetchDailyImagesUseCase(forceRefresh: false);

      if (freshImages.isNotEmpty) {
        // Read index from state to avoid overwriting user interaction during network fetch
        int indexToUse = initialIndex;
        state.mapOrNull(loaded: (loadedState) {
          indexToUse = loadedState.imageIndex;
        });

        if (indexToUse >= freshImages.length) indexToUse = 0;

        if (lastSetId != null && (now - lastSetTime) < 30000) {
          final setIndex =
              freshImages.indexWhere((img) => img.imageIdent == lastSetId);
          if (setIndex >= 0) {
            wallpaperMessage = 'wallpaperSetSuccess';
            indexToUse = setIndex;
          }
        }

        final targetImage = freshImages[indexToUse];
        final isReady = _isCropReady(targetImage);
        final isSrcReady = _isSourceReady(targetImage);

        try {
          unawaited(
            _preloaderService
                .preloadCurrentImageWithCrop(targetImage)
                .catchError(
                    (e) => debugPrint('Error preloading fresh image: $e')),
          );
        } catch (e) {
          debugPrint(
              'Warning: preloadCurrentImageWithCrop invocation failed ($e)');
        }

        if (!isClosed) {
          emit(HomeState.loaded(
            list: freshImages,
            imageIndex: indexToUse,
            wallpaperMessage: wallpaperMessage,
            isCropProcessing: !isReady,
            isSourceLoading: !isSrcReady,
          ));
        }

        if (!isReady) {
          _monitorCropProcessing(targetImage);
        }

        // Preload fresh images
        unawaited(
          _preloaderService
              .preloadImages(freshImages, indexToUse)
              .timeout(const Duration(seconds: 45))
              .catchError((e) {
            debugPrint(
                'Warning: Preloading fresh timed out or failed ($e). Proceeding with available data.');
          }),
        );
      } else if (cachedImages.isEmpty) {
        if (!isClosed) {
          emit(const HomeState.error(
              'failedToFetchWallpapers: No wallpapers found.'));
        }
      }
    } catch (e) {
      debugPrint('Error fetching fresh daily wallpapers: $e');
      if (state.maybeMap(loaded: (_) => false, orElse: () => true)) {
        if (!isClosed) {
          emit(HomeState.error('failedToFetchWallpapers: $e'));
        }
      }
    }
  }

  Future<void> _onRefreshRequested(
      HomeEventRefreshRequested event, Emitter<HomeState> emit) async {
    emit(const HomeState.loading());
    try {
      final images = await _fetchDailyImagesUseCase(forceRefresh: true);

      // Reset saved index on manual refresh
      await _prefs.setInt(sp_LastViewedIndex, 0);

      final initialImage = images.first;
      final isReady = _isCropReady(initialImage);
      final isSrcReady = _isSourceReady(initialImage);

      // Emit loaded immediately; preload runs in the background.
      if (!isClosed) {
        emit(HomeState.loaded(
          list: images,
          imageIndex: 0,
          isCropProcessing: !isReady,
          isSourceLoading: !isSrcReady,
        ));
      }

      unawaited(
        _preloaderService
            .preloadImages(images, 0)
            .timeout(const Duration(seconds: 45))
            .catchError((e) {
          debugPrint(
              'Warning: Preloading timed out or failed ($e). Proceeding with available data.');
        }),
      );

      if (!isReady) {
        _monitorCropProcessing(initialImage);
      }
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
          final targetImage = loadedState.list[event.newIndex];
          final isReady = _isCropReady(targetImage);
          final isSrcReady = _isSourceReady(targetImage);

          emit(loadedState.copyWith(
            imageIndex: event.newIndex,
            wallpaperMessage: messageToKeep,
            isCropProcessing: !isReady,
            isSourceLoading: !isSrcReady,
          ));
          _preloaderService.preloadImages(loadedState.list, event.newIndex);

          // Save index to prefs
          _prefs.setInt(sp_LastViewedIndex, event.newIndex);

          if (!isReady) {
            _monitorCropProcessing(targetImage);
          }
        }
      },
    );
  }

  void _onCropStatusChanged(
      HomeEventCropStatusChanged event, Emitter<HomeState> emit) {
    state.mapOrNull(
      loaded: (loadedState) {
        final currentImage = loadedState.list[loadedState.imageIndex];
        if (currentImage.imageIdent == event.imageIdent) {
          final isSrcReady = _isSourceReady(currentImage);
          final isCropDone = _isCropReady(currentImage);
          emit(loadedState.copyWith(
            isSourceLoading: !isSrcReady,
            isCropProcessing: !isCropDone && isSrcReady && event.isProcessing,
          ));
        }
      },
    );
  }

  Future<void> _onWallpaperUpdateRequested(
      HomeEventWallpaperUpdateRequested event, Emitter<HomeState> emit) async {
    await state.mapOrNull(
      loaded: (loadedState) async {
        emit(loadedState.copyWith(
            isSettingWallpaper: true, wallpaperMessage: null));
        try {
          final image = loadedState.list[loadedState.imageIndex];

          // CRITICAL: Save success prefs BEFORE applying the wallpaper.
          // Android restarts the Activity (Material You theme change) immediately after
          // WallpaperManager.setWallpaper() completes, which closes this BLoC.
          // BLoC B reads these prefs during _onStarted — if we write them AFTER the
          // wallpaper call, BLoC B may have already read them (race condition → no checkmark).
          await _prefs.setString(sp_LastSetWallpaperId, image.imageIdent);
          await _prefs.setInt(
              sp_LastSetWallpaperTime, DateTime.now().millisecondsSinceEpoch);

          final message = await _applyWallpaperUseCase(image);

          if (message != 'wallpaperSetSuccess') {
            // Application failed — clear the prefs we pre-saved so the checkmark doesn't show.
            await _prefs.setString(sp_LastSetWallpaperId, '');
            await _prefs.setInt(sp_LastSetWallpaperTime, 0);
          }

          if (!isClosed) {
            emit(loadedState.copyWith(
                isSettingWallpaper: false,
                wallpaperMessage: message ?? 'wallpaperSetSuccess'));
          }
        } catch (e) {
          // Clear pre-saved prefs on exception.
          await _prefs.setString(sp_LastSetWallpaperId, '');
          await _prefs.setInt(sp_LastSetWallpaperTime, 0);
          if (!isClosed) {
            emit(loadedState.copyWith(
                isSettingWallpaper: false,
                wallpaperMessage: 'failedToSetWallpaper: $e'));
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
