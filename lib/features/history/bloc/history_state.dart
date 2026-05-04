import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

part 'history_state.freezed.dart';

@freezed
sealed class HistoryState with _$HistoryState {
  const factory HistoryState.initial({
    required DateTime selectedDate,
    @Default([]) List<DateTime> availableDates,
  }) = _Initial;

  const factory HistoryState.loading({
    required DateTime selectedDate,
    required List<DateTime> availableDates,
  }) = _Loading;

  const factory HistoryState.loaded({
    required List<ImageItem> images,
    required DateTime selectedDate,
    required List<DateTime> availableDates,
    String? wallpaperMessage,
    @Default(false) bool isSettingWallpaper,
  }) = _Loaded;

  const factory HistoryState.error({
    required String message,
    required DateTime selectedDate,
    required List<DateTime> availableDates,
  }) = _Error;
}
