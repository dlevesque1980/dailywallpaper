import 'package:freezed_annotation/freezed_annotation.dart';

part 'home_event.freezed.dart';

@freezed
sealed class HomeEvent with _$HomeEvent {
  const factory HomeEvent.started() = HomeEventStarted;
  const factory HomeEvent.refreshRequested() = HomeEventRefreshRequested;
  const factory HomeEvent.indexChanged(int newIndex) = HomeEventIndexChanged;
  const factory HomeEvent.wallpaperUpdateRequested() = HomeEventWallpaperUpdateRequested;
}
