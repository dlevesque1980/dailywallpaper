import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';

part 'pexels_categories_state.freezed.dart';

@freezed
sealed class PexelsCategoriesState with _$PexelsCategoriesState {
  const factory PexelsCategoriesState({
    required List<String> allCategories,
    required List<String> selectedCategories,
    @Default(false) bool isLoading,
    String? error,
  }) = _PexelsCategoriesState;

  factory PexelsCategoriesState.initial() => PexelsCategoriesState(
        allCategories: defaultPexelsCategories,
        selectedCategories: defaultPexelsCategories.take(3).toList(),
        isLoading: true,
      );
}