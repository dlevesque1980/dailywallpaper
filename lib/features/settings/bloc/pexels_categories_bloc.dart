import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_event.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_state.dart';

class PexelsCategoriesBloc extends Bloc<PexelsCategoriesEvent, PexelsCategoriesState> {
  PexelsCategoriesBloc() : super(PexelsCategoriesState.initial()) {
    on<PexelsCategoriesEventStarted>(_onStarted);
    on<PexelsCategoriesEventCategoriesChanged>(_onCategoriesChanged);
  }

  Future<void> _onStarted(PexelsCategoriesEventStarted event, Emitter<PexelsCategoriesState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final selectedCategories = await PrefHelper.getStringListWithDefault(
        sp_PexelsCategories,
        defaultPexelsCategories.take(3).toList(),
      );
      
      emit(state.copyWith(
        selectedCategories: selectedCategories,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: 'Failed to load categories: $e'));
    }
  }

  Future<void> _onCategoriesChanged(PexelsCategoriesEventCategoriesChanged event, Emitter<PexelsCategoriesState> emit) async {
    if (event.categories.isNotEmpty) {
      await PrefHelper.setStringList(sp_PexelsCategories, event.categories);
      emit(state.copyWith(selectedCategories: event.categories));
    }
  }
}