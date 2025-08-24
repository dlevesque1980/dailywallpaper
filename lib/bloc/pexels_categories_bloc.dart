import 'dart:async';

import 'package:dailywallpaper/bloc_state/pexels_categories_state.dart';
import 'package:dailywallpaper/prefs/pref_consts.dart';
import 'package:dailywallpaper/prefs/pref_helper.dart';
import 'package:rxdart/rxdart.dart';

class PexelsCategoriesBloc {
  Stream<PexelsCategoriesState> _categories = Stream.empty();
  var _categoriesQuery = BehaviorSubject<List<String>>();

  Stream<PexelsCategoriesState> get categories => _categories;
  Sink<List<String>> get categoriesQuery => _categoriesQuery;

  PexelsCategoriesBloc() {
    _categories =
        _categoriesQuery.asyncMap(_categoriesHandler).asBroadcastStream();
  }

  Future<PexelsCategoriesState> _categoriesHandler(List<String> categories) async {
    // Save selected categories if provided
    if (categories.isNotEmpty) {
      await PrefHelper.setStringList(sp_PexelsCategories, categories);
    }
    
    // Get current selected categories or use defaults
    var selectedCategories = await PrefHelper.getStringListWithDefault(
      sp_PexelsCategories, 
      defaultPexelsCategories.take(3).toList(), // Default to first 3 categories
    );
    
    return PexelsCategoriesState(defaultPexelsCategories, selectedCategories);
  }

  void dispose() {
    _categoriesQuery.close();
  }
}