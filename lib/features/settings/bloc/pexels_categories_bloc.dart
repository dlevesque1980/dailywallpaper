import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_event.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_state.dart';

class PexelsCategoriesBloc extends Bloc<PexelsCategoriesEvent, PexelsCategoriesState> {
  final PreferencesReader _prefHelper;

  PexelsCategoriesBloc({PreferencesReader? prefHelper})
      : _prefHelper = prefHelper ?? PrefHelperAdapter(),
        super(PexelsCategoriesState.initial()) {
    on<PexelsCategoriesEventStarted>(_onStarted);
    on<PexelsCategoriesEventCategoriesChanged>(_onCategoriesChanged);
  }

  Future<void> _onStarted(PexelsCategoriesEventStarted event, Emitter<PexelsCategoriesState> emit) async {
    emit(state.copyWith(isLoading: true));
    try {
      final selectedCategories = await _prefHelper.getStringListWithDefault(
        sp_PexelsCategories,
        defaultPexelsCategories.take(3).toList(),
      );
      
      if (!isClosed) {
        emit(state.copyWith(
          selectedCategories: selectedCategories,
          isLoading: false,
        ));
      }
    } catch (e) {
      if (!isClosed) {
        emit(state.copyWith(isLoading: false, error: 'Failed to load categories: $e'));
      }
    }
  }

  Future<void> _onCategoriesChanged(PexelsCategoriesEventCategoriesChanged event, Emitter<PexelsCategoriesState> emit) async {
    if (event.categories.isNotEmpty) {
      await _prefHelper.setStringList(sp_PexelsCategories, event.categories);
      if (!isClosed) {
        emit(state.copyWith(selectedCategories: event.categories));
      }
    }
  }
}