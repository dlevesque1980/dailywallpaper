import 'package:dailywallpaper/bloc/categories_bloc.dart';
import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc_provider/settings_provider.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/bloc_state/categories_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/widget/bing_region_image_setting.dart';
import 'package:dailywallpaper/widget/checkbox_categories_setting.dart';
import 'package:flutter/material.dart';

class SettingScreen extends StatefulWidget {
  SettingScreen() : super(key: const Key('__settingScreen__'));
  @override
  _SettingScreenState createState() => new _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  SettingsBloc settingsBloc;
  CategoriesBloc categoriesBloc;

  BingRegionState initialBingData(Sink<String> regionQuery) {
    regionQuery.add("");
    return null;
  }

  List<RegionItem> initialThumbnail(Sink<String> thumbnailQuery) {
    thumbnailQuery.add("");
    return null;
  }

  bool initialLockData(Sink<String> lockQuery) {
    lockQuery.add("");
    return null;
  }

  CategoriesState initialCategories(Sink<List<String>> categoriesQuery) {
    categoriesQuery.add(<String>[]);
    return null;
  }

  @override
  void dispose() {
    categoriesBloc.dispose();
    settingsBloc.dispose();
    super.dispose();
  }

  Widget handleSnapshotState<T>(AsyncSnapshot<T> snapshot) {
    if (snapshot.hasError) return Text('Error: ${snapshot.error}');
    if (snapshot.connectionState == ConnectionState.none ||
        snapshot.connectionState == ConnectionState.waiting) {
      return Center(child: CircularProgressIndicator());
    }
    return null;
  }

  void showUnsplashCategories(BuildContext context) {
    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return StreamBuilder<CategoriesState>(
            initialData: initialCategories(categoriesBloc.categoriesQuery),
            stream: categoriesBloc.categories,
            builder: (context, snapshot) {
              return handleSnapshotState(snapshot) ??
                  Container(
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                    child: ListView(
                        children:
                            snapshot.data.listOfCategories.map<Widget>((item) {
                      return CheckboxCategoriesSetting(
                          categoriesBloc: categoriesBloc,
                          item: item,
                          choices: snapshot.data.choices);
                    }).toList()),
                  ));
            },
          );
        });
  }

  void showBingRegion(BuildContext context, BingRegionState state) {
    showModalBottomSheet<void>(
        context: context,
        builder: (BuildContext context) {
          return StreamBuilder<List<RegionItem>>(
            initialData: initialThumbnail(settingsBloc.thumbnailQuery),
            stream: settingsBloc.thumbnail,
            builder: (context, snapshot) {
              return handleSnapshotState(snapshot) ??
                  Container(
                      child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                    child: GridView.count(
                        crossAxisCount: 3,
                        children: snapshot.data.map<Widget>((item) {
                          return BingImageRegionSetting(
                              settingsBloc: settingsBloc,
                              item: item,
                              choice: state.choice);
                        }).toList()),
                  ));
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle flatButtonStyle = TextButton.styleFrom(
      primary: Colors.black87,
      minimumSize: Size(88, 36),
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ),
    );
    settingsBloc = SettingsProvider.of(context).settingsBloc;
    categoriesBloc = SettingsProvider.of(context).categoriesBloc;
    return Scaffold(
        appBar: AppBar(
          title: Text("Settings", style: TextStyle(color: Colors.black)),
          backgroundColor: Colors.white,
          elevation: 0.0,
          iconTheme: IconThemeData(color: Colors.black),
        ),
        body: ListView(padding: EdgeInsets.all(10.0), children: <Widget>[
          StreamBuilder<bool>(
            initialData: initialLockData(settingsBloc.lockQuery),
            stream: settingsBloc.includeLock,
            builder: (context, snapshot) {
              return handleSnapshotState(snapshot) ??
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text("Set lock screen wallpaper",
                          style: TextStyle(
                            fontSize: 19.0,
                            fontWeight: FontWeight.normal,
                          )),
                      Switch(
                          value: snapshot.data,
                          onChanged: (value) =>
                              settingsBloc.lockQuery.add(value.toString()))
                    ],
                  );
            },
          ),
          StreamBuilder<BingRegionState>(
            stream: settingsBloc.regions,
            initialData: initialBingData(settingsBloc.regionQuery),
            builder: (context, snapshot) {
              return handleSnapshotState(snapshot) ??
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text("Bing region",
                          style: TextStyle(
                            fontSize: 19.0,
                            fontWeight: FontWeight.normal,
                          )),
                      TextButton(
                        style: flatButtonStyle,
                        child: new Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Container(
                              width: 150.0,
                              padding: EdgeInsets.only(right: 13.0),
                              child: Text(
                                  BingRegionEnum.labelOf(snapshot.data.choice),
                                  overflow: TextOverflow.ellipsis,
                                  textAlign: TextAlign.right,
                                  style: TextStyle(
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.normal,
                                  )),
                            ),
                            Icon(Icons.arrow_drop_down),
                          ],
                        ),
                        onPressed: () => showBingRegion(context, snapshot.data),
                      )
                    ],
                  );
            },
          ),
          Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Text("Unsplash themes",
                    style: TextStyle(
                      fontSize: 19.0,
                      fontWeight: FontWeight.normal,
                    )),
                TextButton(
                  style: flatButtonStyle,
                  child: new Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Container(
                        width: 150.0,
                        padding: EdgeInsets.only(right: 13.0),
                        child: Text("Select categories...",
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.right,
                            style: TextStyle(
                              fontSize: 19.0,
                              fontWeight: FontWeight.normal,
                            )),
                      ),
                      Icon(Icons.arrow_drop_down),
                    ],
                  ),
                  onPressed: () => showUnsplashCategories(context),
                )
              ])
        ]));
  }
}
