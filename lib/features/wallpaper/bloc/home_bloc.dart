import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc({
    FetchDailyImagesUseCase? fetchDailyImagesUseCase,
    ApplyWallpaperUseCase? applyWallpaperUseCase,
    PreferencesReader? prefs,
  })  : _fetchDailyImagesUseCase =
            fetchDailyImagesUseCase ?? FetchDailyImagesUseCase(),
        _applyWallpaperUseCase =
            applyWallpaperUseCase ?? ApplyWallpaperUseCase(),
        _prefs = prefs ?? PrefHelperAdapter(),
        super(const HomeState.initial()) {
    on<HomeEventStarted>(_onRefreshRequested);
    on<HomeEventRefreshRequested>(_onRefreshRequested);
    on<HomeEventAppResumed>(_onRefreshRequested);
    on<HomeEventIndexChanged>(_onIndexChanged);
    on<HomeEventWallpaperUpdateRequested>(_onWallpaperUpdateRequested);
  }

  final FetchDailyImagesUseCase _fetchDailyImagesUseCase;
  final ApplyWallpaperUseCase _applyWallpaperUseCase;
  final PreferencesReader _prefs;

  Future<void> _onRefreshRequested(
    HomeEvent event,
    Emitter<HomeState> emit,
  ) async {
    emit(const HomeState.loading());
    try {
      final images = await _fetchDailyImagesUseCase();
      if (images.isEmpty) {
        emit(const HomeState.error(
          'failedToFetchWallpapers: Supabase returned no wallpapers.',
        ));
        return;
      }

      final preferredId = await _prefs.getString(lastSetWallpaperId);
      final preferredIndex =
          await _prefs.getIntWithDefault(lastViewedWallpaperIndex, 0);
      final lastSetTime =
          await _prefs.getIntWithDefault(lastSetWallpaperTime, 0);
      var initialIndex = images.indexWhere((image) => image.id == preferredId);
      if (initialIndex < 0 || preferredId == null || preferredId.isEmpty) {
        initialIndex = preferredIndex.clamp(0, images.length - 1).toInt();
      }
      final recentSuccess = preferredId != null &&
              preferredId.isNotEmpty &&
              images[initialIndex].id == preferredId &&
              DateTime.now().millisecondsSinceEpoch - lastSetTime < 30000
          ? 'wallpaperSetSuccess'
          : null;

      emit(HomeState.loaded(
        list: images,
        imageIndex: initialIndex,
        wallpaperMessage: recentSuccess,
      ));
    } catch (error) {
      emit(HomeState.error('failedToFetchWallpapers: $error'));
    }
  }

  Future<void> _onIndexChanged(
    HomeEventIndexChanged event,
    Emitter<HomeState> emit,
  ) async {
    state.mapOrNull(
      loaded: (loadedState) {
        if (event.newIndex < 0 || event.newIndex >= loadedState.list.length) {
          return;
        }
        final messageToKeep = event.newIndex == loadedState.imageIndex
            ? loadedState.wallpaperMessage
            : null;
        emit(loadedState.copyWith(
          imageIndex: event.newIndex,
          wallpaperMessage: messageToKeep,
        ));
      },
    );
    await state.mapOrNull(
      loaded: (loadedState) => _prefs.setInt(
        lastViewedWallpaperIndex,
        loadedState.imageIndex,
      ),
    );
  }

  Future<void> _onWallpaperUpdateRequested(
    HomeEventWallpaperUpdateRequested event,
    Emitter<HomeState> emit,
  ) async {
    await state.mapOrNull(
      loaded: (loadedState) async {
        emit(loadedState.copyWith(
          isSettingWallpaper: true,
          wallpaperMessage: null,
        ));
        final image = loadedState.list[loadedState.imageIndex];
        try {
          await _prefs.setString(lastSetWallpaperId, image.id);
          await _prefs.setInt(
            lastSetWallpaperTime,
            DateTime.now().millisecondsSinceEpoch,
          );
          final message = await _applyWallpaperUseCase(image);
          if (message != 'wallpaperSetSuccess') {
            await _prefs.setString(lastSetWallpaperId, '');
            await _prefs.setInt(lastSetWallpaperTime, 0);
          }
          if (!isClosed) {
            emit(loadedState.copyWith(
              isSettingWallpaper: false,
              wallpaperMessage: message,
            ));
          }
        } catch (error) {
          await _prefs.setString(lastSetWallpaperId, '');
          await _prefs.setInt(lastSetWallpaperTime, 0);
          if (!isClosed) {
            emit(loadedState.copyWith(
              isSettingWallpaper: false,
              wallpaperMessage: 'failedToSetWallpaper: $error',
            ));
          }
        }
      },
    );
  }
}
