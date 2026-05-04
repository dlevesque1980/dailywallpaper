import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/services/image_preloader.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:flutter/foundation.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final FetchDailyImagesUseCase _fetchDailyImagesUseCase;
  final ApplyWallpaperUseCase _applyWallpaperUseCase;
  final ImagePreloader _preloaderService;

  HomeBloc({
    FetchDailyImagesUseCase? fetchDailyImagesUseCase,
    ApplyWallpaperUseCase? applyWallpaperUseCase,
    ImagePreloader? preloaderService,
  })  : _fetchDailyImagesUseCase = fetchDailyImagesUseCase ?? FetchDailyImagesUseCase(),
        _applyWallpaperUseCase = applyWallpaperUseCase ?? ApplyWallpaperUseCase(),
        _preloaderService = preloaderService ?? ImagePreloaderService(),
        super(const HomeState.initial()) {
    on<HomeEventStarted>(_onStarted);
    on<HomeEventRefreshRequested>(_onRefreshRequested);
    on<HomeEventIndexChanged>(_onIndexChanged);
    on<HomeEventWallpaperUpdateRequested>(_onWallpaperUpdateRequested);
  }

  Future<void> _onStarted(HomeEventStarted event, Emitter<HomeState> emit) async {
    emit(const HomeState.loading());
    try {
      final images = await _fetchDailyImagesUseCase(forceRefresh: false);
      
      try {
        await _preloaderService.preloadImages(images, 0).timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Warning: Preloading timed out or failed ($e). Proceeding with available data.');
      }

      if (!isClosed) {
        emit(HomeState.loaded(list: images, imageIndex: 0));
      }
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
      
      try {
        await _preloaderService.preloadImages(images, 0).timeout(const Duration(seconds: 45));
      } catch (e) {
        debugPrint('Warning: Preloading timed out or failed ($e). Proceeding with available data.');
      }

      if (!isClosed) {
        emit(HomeState.loaded(list: images, imageIndex: 0));
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
          emit(loadedState.copyWith(imageIndex: event.newIndex, wallpaperMessage: null));
          _preloaderService.preloadImages(loadedState.list, event.newIndex);
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
          final message = await _applyWallpaperUseCase(image);
          
          if (!isClosed) {
            emit(loadedState.copyWith(
              isSettingWallpaper: false, 
              wallpaperMessage: message ?? 'wallpaperSetSuccess'
            ));
          }
        } catch (e) {
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
    _preloaderService.clearCache();
    return super.close();
  }
}
