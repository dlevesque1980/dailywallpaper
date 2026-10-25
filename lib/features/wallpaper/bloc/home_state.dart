import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

part 'home_state.freezed.dart';

@freezed
sealed class HomeState with _$HomeState {
  const factory HomeState.initial() = _Initial;
  const factory HomeState.loading() = _Loading;
  const factory HomeState.loaded({
    required List<ImageItem> list,
    @Default(0) int imageIndex,
    String? wallpaperMessage,
    @Default(false) bool isSettingWallpaper,
  }) = _Loaded;
  const factory HomeState.error(String message) = _Error;
}
