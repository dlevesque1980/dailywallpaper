class PexelsCategoriesState {
  final List<String> _availableCategories;
  final List<String> _selectedCategories;

  List<String> get availableCategories => _availableCategories;
  List<String> get selectedCategories => _selectedCategories;

  PexelsCategoriesState(this._availableCategories, this._selectedCategories);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PexelsCategoriesState &&
          runtimeType == other.runtimeType &&
          _availableCategories == other._availableCategories &&
          _selectedCategories == other._selectedCategories;

  @override
  int get hashCode => _availableCategories.hashCode ^ _selectedCategories.hashCode;

  @override
  String toString() {
    return 'PexelsCategoriesState{availableCategories: $_availableCategories, selectedCategories: $_selectedCategories}';
  }
}