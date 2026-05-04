import 'package:freezed_annotation/freezed_annotation.dart';

part 'pexels_categories_event.freezed.dart';

@freezed
sealed class PexelsCategoriesEvent with _$PexelsCategoriesEvent {
  const factory PexelsCategoriesEvent.started() = PexelsCategoriesEventStarted;
  const factory PexelsCategoriesEvent.categoriesChanged(List<String> categories) = PexelsCategoriesEventCategoriesChanged;
}
