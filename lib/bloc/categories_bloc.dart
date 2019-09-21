import 'dart:async';

import 'package:dailywallpaper/bloc_state/categories_state.dart';
import 'package:dailywallpaper/prefs/prefs.dart';
import 'package:rxdart/rxdart.dart';

class CategoriesBloc {
  Stream<CategoriesState> _categories = Stream.empty();
  var _categoriesQuery = BehaviorSubject<List<String>>();

  Stream<CategoriesState> get categories => _categories;
  Sink<List<String>> get categoriesQuery => _categoriesQuery;

  CategoriesBloc() {
    _categories = _categoriesQuery.asyncMap(_categoriesHandler).asBroadcastStream();
  }

  Future<CategoriesState> _categoriesHandler(List<String> categories) async {
    final List<String> allCategories = ["landscape", "nature", "fantasy", "urban", "flower", "love", "wallpaper", "city", "ocean", "island", "food"];
    if (categories.length > 0) Prefs.unsplashCategories = categories;
    var cat = await Prefs.unsplashCategories;
    return CategoriesState(allCategories, cat);
  }

  void dispose() {
    _categoriesQuery.close();
  }
}
