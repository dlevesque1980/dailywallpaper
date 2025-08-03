import 'package:dailywallpaper/bloc/home_bloc.dart';
import 'package:flutter/widgets.dart';

class HomeProvider extends InheritedWidget {
  final HomeBloc homeBloc;
  HomeProvider({Key? key, required HomeBloc homeBloc, required Widget child})
      : this.homeBloc = homeBloc,
        super(child: child, key: key);

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => true;

  static HomeBloc of(BuildContext context) =>
      (context.dependOnInheritedWidgetOfExactType<HomeProvider>())!.homeBloc;
}
