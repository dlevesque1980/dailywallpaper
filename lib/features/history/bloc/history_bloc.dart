import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/features/history/domain/usecases/fetch_history_usecase.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/services/image_preloader.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  final FetchHistoryUseCase _fetchHistoryUseCase;
  final ApplyWallpaperUseCase _applyWallpaperUseCase;
  final ImagePreloader _preloaderService;

  HistoryBloc({
    FetchHistoryUseCase? fetchHistoryUseCase,
    ApplyWallpaperUseCase? applyWallpaperUseCase,
    ImagePreloader? preloaderService,
  })  : _fetchHistoryUseCase = fetchHistoryUseCase ?? FetchHistoryUseCase(),
        _applyWallpaperUseCase = applyWallpaperUseCase ?? ApplyWallpaperUseCase(),
        _preloaderService = preloaderService ?? ImagePreloaderService(),
        super(HistoryState.initial(selectedDate: DateTime.now())) {
    on<HistoryEventStarted>(_onStarted);
    on<HistoryEventDateSelected>(_onDateSelected);
    on<HistoryEventWallpaperUpdateRequested>(_onWallpaperUpdateRequested);
  }

  Future<void> _onStarted(HistoryEventStarted event, Emitter<HistoryState> emit) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    
    emit(HistoryState.loading(selectedDate: todayDate, availableDates: []));
    
    try {
      final availableDates = await _fetchHistoryUseCase.getAvailableDates();
      final images = await _fetchHistoryUseCase.getImagesForDate(todayDate);
      
      _preloaderService.preloadImages(images, 0);

      if (!isClosed) {
        emit(HistoryState.loaded(
          images: images,
          selectedDate: todayDate,
          availableDates: availableDates,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(HistoryState.error(
          message: 'failedToInitializeHistory: $e',
          selectedDate: todayDate,
          availableDates: [],
        ));
      }
    }
  }

  Future<void> _onDateSelected(HistoryEventDateSelected event, Emitter<HistoryState> emit) async {
    final currentState = state;
    final availableDates = currentState.map(
      initial: (s) => s.availableDates,
      loading: (s) => s.availableDates,
      loaded: (s) => s.availableDates,
      error: (s) => s.availableDates,
    );

    emit(HistoryState.loading(selectedDate: event.date, availableDates: availableDates));

    try {
      final images = await _fetchHistoryUseCase.getImagesForDate(event.date);
      final newAvailableDates = await _fetchHistoryUseCase.getAvailableDates();
      
      _preloaderService.preloadImages(images, 0);

      if (!isClosed) {
        emit(HistoryState.loaded(
          images: images,
          selectedDate: event.date,
          availableDates: newAvailableDates,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(HistoryState.error(
          message: 'failedToLoadImagesForDate: $e',
          selectedDate: event.date,
          availableDates: availableDates,
        ));
      }
    }
  }

  Future<void> _onWallpaperUpdateRequested(HistoryEventWallpaperUpdateRequested event, Emitter<HistoryState> emit) async {
    await state.mapOrNull(
      loaded: (loadedState) async {
        emit(loadedState.copyWith(isSettingWallpaper: true, wallpaperMessage: null));
        try {
          if (event.index >= 0 && event.index < loadedState.images.length) {
            final image = loadedState.images[event.index];
            final message = await _applyWallpaperUseCase(image);
            
            if (!isClosed) {
              emit(loadedState.copyWith(
                isSettingWallpaper: false, 
                wallpaperMessage: message ?? 'wallpaperSetSuccess'
              ));
            }
          } else {
            if (!isClosed) {
              emit(loadedState.copyWith(
                isSettingWallpaper: false, 
                wallpaperMessage: 'invalidImageIndex'
              ));
            }
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
