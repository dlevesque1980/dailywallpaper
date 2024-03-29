import 'package:dailywallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/bloc_provider/home_provider.dart';
import 'package:dailywallpaper/widget/carousel.dart';
import 'package:flutter/material.dart';

import '../widget/buttonstate.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen() : super(key: const Key('__homeScreen__'));
  @override
  _HomeScreenState createState() => new _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  AppLifecycleState _lastLifecycleState;
  ValueNotifier<int> notifierIndex = new ValueNotifier(0);
  HomeBloc homeBloc;
  Stream<String> wallpaperMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    if (homeBloc == null) {
      homeBloc = HomeProvider.of(context);
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeBloc.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {
        _lastLifecycleState = state;
      });
    }
  }

  void _onChange(int index, bool refresh) {
    if (notifierIndex.value != index) {
      notifierIndex.value = index;
    }
    if (refresh) {
      setState(() {
        _lastLifecycleState = AppLifecycleState.resumed;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        floatingActionButton: ValueListenableBuilder(
            valueListenable: notifierIndex,
            builder: (context, value, child) {
              return ButtonStates(
                onPressed: () => homeBloc.setWallpaper.add(notifierIndex.value),
                homeBloc: homeBloc,
              );
              // return FloatingActionButton(
              //   elevation: 0.0,
              //   child: new Icon(Icons.wallpaper),
              //   backgroundColor: Colors.lightBlue,
              //   onPressed: () => homeBloc.setWallpaper.add(notifierIndex.value),
              // );
            }),
        body: StreamBuilder(
            stream: homeBloc.results,
            initialData: homeBloc.initialData(notifierIndex.value),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Carousel(
                  list: snapshot.data.list,
                  onChange: this._onChange,
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            }));
  }
}
