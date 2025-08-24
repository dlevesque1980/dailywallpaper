import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc/pexels_categories_bloc.dart';
import 'package:flutter/widgets.dart';

class SettingsProvider extends InheritedWidget {
  final SettingsBloc settingsBloc;
  final PexelsCategoriesBloc pexelsCategoriesBloc;
  
  SettingsProvider({
    Key? key,
    required SettingsBloc settingsBloc,
    required PexelsCategoriesBloc pexelsCategoriesBloc,
    required Widget child,
  })  : this.settingsBloc = settingsBloc,
        this.pexelsCategoriesBloc = pexelsCategoriesBloc,
        super(child: child, key: key);

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => true;

  static SettingsProvider of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<SettingsProvider>()!);
}
