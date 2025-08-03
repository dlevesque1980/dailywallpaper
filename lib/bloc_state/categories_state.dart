class CategoriesState {
  List<String> _listOfCategories;
  List<String>? _choices;

  List<String> get listOfCategories => _listOfCategories;
  List<String>? get choices => _choices;

  CategoriesState(this._listOfCategories, this._choices);
}
