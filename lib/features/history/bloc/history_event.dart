import 'package:freezed_annotation/freezed_annotation.dart';

part 'history_event.freezed.dart';

@freezed
sealed class HistoryEvent with _$HistoryEvent {
  const factory HistoryEvent.started() = HistoryEventStarted;
  const factory HistoryEvent.dateSelected(DateTime date) = HistoryEventDateSelected;
  const factory HistoryEvent.wallpaperUpdateRequested(int index) = HistoryEventWallpaperUpdateRequested;
}
