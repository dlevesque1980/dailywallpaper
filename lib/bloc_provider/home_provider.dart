import 'package:dailywallpaper/bloc/home_bloc.dart';
import 'package:flutter/widgets.dart';

class HomeProvider extends InheritedWidget {
  final HomeBloc homeBloc;
  HomeProvider({Key key, HomeBloc homeBloc, Widget child})
      : this.homeBloc = homeBloc ?? HomeBloc(),
        super(child: child, key: key);

  @override
  bool updateShouldNotify(InheritedWidget oldWidget) => true;

  static HomeBloc of(BuildContext context) => (context.inheritFromWidgetOfExactType(HomeProvider) as HomeProvider).homeBloc;
}
