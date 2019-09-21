import 'package:dailywallpaper/bloc/categories_bloc.dart';
import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:flutter/widgets.dart';

class SettingsProvider extends InheritedWidget {
  final SettingsBloc settingsBloc;
  final CategoriesBloc categoriesBloc;
  SettingsProvider({Key key, SettingsBloc settingsBloc, CategoriesBloc categoriesBloc, Widget child})
      : this.settingsBloc = settingsBloc ?? SettingsBloc(),
        this.categoriesBloc = categoriesBloc ?? CategoriesBloc(),
        super(child: child, key: key);

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => true;

  static SettingsProvider of(BuildContext context) => (context.inheritFromWidgetOfExactType(SettingsProvider) as SettingsProvider);
}
