import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/features/history/domain/usecases/fetch_history_usecase.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class HistoryBloc extends Bloc<HistoryEvent, HistoryState> {
  HistoryBloc({
    FetchHistoryUseCase? fetchHistoryUseCase,
    ApplyWallpaperUseCase? applyWallpaperUseCase,
  })  : _fetchHistoryUseCase = fetchHistoryUseCase ?? FetchHistoryUseCase(),
        _applyWallpaperUseCase =
            applyWallpaperUseCase ?? ApplyWallpaperUseCase(),
        super(HistoryState.initial(selectedDate: DateTime.now())) {
    on<HistoryEventStarted>(_onStarted);
    on<HistoryEventDateSelected>(_onDateSelected);
    on<HistoryEventWallpaperUpdateRequested>(_onWallpaperUpdateRequested);
  }

  final FetchHistoryUseCase _fetchHistoryUseCase;
  final ApplyWallpaperUseCase _applyWallpaperUseCase;

  Future<void> _onStarted(
    HistoryEventStarted event,
    Emitter<HistoryState> emit,
  ) async {
    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    emit(HistoryState.loading(
        selectedDate: todayDate, availableDates: const []));

    try {
      final datesFuture = _fetchHistoryUseCase.getAvailableDates();
      final imagesFuture = _fetchHistoryUseCase.getImagesForDate(todayDate);
      final dates = await datesFuture;
      final images = await imagesFuture;
      if (isClosed) return;
      emit(HistoryState.loaded(
        images: images,
        selectedDate: todayDate,
        availableDates: dates,
      ));
    } catch (error) {
      if (!isClosed) {
        emit(HistoryState.error(
          message: 'failedToInitializeHistory: $error',
          selectedDate: todayDate,
          availableDates: const [],
        ));
      }
    }
  }

  Future<void> _onDateSelected(
    HistoryEventDateSelected event,
    Emitter<HistoryState> emit,
  ) async {
    final availableDates = state.map(
      initial: (s) => s.availableDates,
      loading: (s) => s.availableDates,
      loaded: (s) => s.availableDates,
      error: (s) => s.availableDates,
    );
    emit(HistoryState.loading(
      selectedDate: event.date,
      availableDates: availableDates,
    ));

    try {
      final images = await _fetchHistoryUseCase.getImagesForDate(event.date);
      if (!isClosed) {
        emit(HistoryState.loaded(
          images: images,
          selectedDate: event.date,
          availableDates: availableDates,
        ));
      }
    } catch (error) {
      if (!isClosed) {
        emit(HistoryState.error(
          message: 'failedToLoadImagesForDate: $error',
          selectedDate: event.date,
          availableDates: availableDates,
        ));
      }
    }
  }

  Future<void> _onWallpaperUpdateRequested(
    HistoryEventWallpaperUpdateRequested event,
    Emitter<HistoryState> emit,
  ) async {
    await state.mapOrNull(
      loaded: (loadedState) async {
        if (event.index < 0 || event.index >= loadedState.images.length) {
          emit(loadedState.copyWith(
            wallpaperMessage: 'invalidImageIndex',
            isSettingWallpaper: false,
          ));
          return;
        }
        emit(loadedState.copyWith(
          isSettingWallpaper: true,
          wallpaperMessage: null,
        ));
        try {
          final message =
              await _applyWallpaperUseCase(loadedState.images[event.index]);
          if (!isClosed) {
            emit(loadedState.copyWith(
              isSettingWallpaper: false,
              wallpaperMessage: message,
            ));
          }
        } catch (error) {
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
