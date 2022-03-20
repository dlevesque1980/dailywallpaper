import 'package:dailywallpaper/bloc/categories_bloc.dart';
import 'package:flutter/material.dart';

class CheckboxCategoriesSetting extends StatelessWidget {
  const CheckboxCategoriesSetting(
      {Key key,
      @required this.categoriesBloc,
      @required this.item,
      @required this.choices})
      : super(key: key);

  final CategoriesBloc categoriesBloc;
  final String item;
  final List<String> choices;

  Function checkBoxChanged() {
    var onChanged = (bool checked) => null;
    var newData = choices;
    if (newData.length < 3 || newData.contains(item)) {
      onChanged = (bool checked) {
        if (!checked)
          newData.remove(item);
        else
          newData.add(item);

        categoriesBloc.categoriesQuery.add(newData);
      };
    }
    return onChanged;
  }

  @override
  Widget build(BuildContext context) {
    return CheckboxListTile(
      value: choices.contains(item) ?? false,
      title: Text(item),
      controlAffinity: ListTileControlAffinity.leading,
      onChanged: checkBoxChanged(),
    );
  }
}
