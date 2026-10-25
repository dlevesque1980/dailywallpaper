import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_state.freezed.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    required bool includeLockWallpaper,
    @Default(true) bool includeNasa,
    @Default(['portrait', 'people', 'animals']) List<String> selectedCategories,
    @Default(false) bool isLoading,
    @Default(false) bool isSavingNasa,
    @Default(false) bool isSavingCategories,
    String? error,
  }) = _SettingsState;

  factory SettingsState.initial() => const SettingsState(
        includeLockWallpaper: true,
        isLoading: true,
      );
}
