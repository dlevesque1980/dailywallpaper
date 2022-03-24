import 'package:dailywallpaper/bloc/categories_bloc.dart';
import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc_provider/settings_provider.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/bloc_state/categories_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/widget/bing_region_image_setting.dart';
import 'package:dailywallpaper/widget/checkbox_categories_setting.dart';
import 'package:flutter/material.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';

class SettingScreen extends StatefulWidget {
  SettingScreen() : super(key: const Key('__settingScreen__'));
  @override
  _SettingScreenState createState() => new _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
  SettingsBloc settingsBloc;
  CategoriesBloc categoriesBloc;
  final formKey = new GlobalKey<FormState>();

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
    return WillPopScope(
        onWillPop: () {
          Navigator.pop(context, true);
          return new Future(() => true);
        },
        child: Scaffold(
            appBar: AppBar(
              title: Text("Settings", style: TextStyle(color: Colors.black)),
              backgroundColor: Colors.white,
              elevation: 0.0,
              iconTheme: IconThemeData(color: Colors.black),
            ),
            body: Form(
              key: formKey,
              child: ListView(padding: EdgeInsets.all(10.0), children: <Widget>[
                StreamBuilder<bool>(
                  initialData: initialLockData(settingsBloc.lockQuery),
                  stream: settingsBloc.includeLock,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text("Set lock screen wallpaper",
                                  style: TextStyle(
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.normal,
                                  )),
                            ),
                            Switch(
                                value: snapshot.data,
                                onChanged: (value) => settingsBloc.lockQuery
                                    .add(value.toString()))
                          ],
                        );
                  },
                ),
                Container(padding: EdgeInsets.all(5.0)),
                StreamBuilder<BingRegionState>(
                  stream: settingsBloc.regions,
                  initialData: initialBingData(settingsBloc.regionQuery),
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text("Bing region",
                                  style: TextStyle(
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.normal,
                                  )),
                            ),
                            TextButton(
                              style: flatButtonStyle,
                              child: new Wrap(
                                children: <Widget>[
                                  Container(
                                    child: Text(
                                        BingRegionEnum.labelOf(
                                            snapshot.data.choice),
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.right,
                                        style: TextStyle(
                                          fontSize: 19.0,
                                          fontWeight: FontWeight.normal,
                                        )),
                                  ),
                                  Icon(Icons.arrow_downward),
                                ],
                              ),
                              onPressed: () =>
                                  showBingRegion(context, snapshot.data),
                            ),
                          ],
                        );
                  },
                ),
                Container(
                    decoration: BoxDecoration(
                        border: Border.all(color: Colors.blueAccent))),
                Container(padding: EdgeInsets.all(5.0)),
                StreamBuilder<CategoriesState>(
                  initialData:
                      initialCategories(categoriesBloc.categoriesQuery),
                  stream: categoriesBloc.categories,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        MultiSelectDialogField(
                          autovalidateMode: AutovalidateMode.disabled,
                          title: Text('Categories'),
                          buttonText: Text('Categories',
                              style: TextStyle(
                                  fontSize: 19.0,
                                  fontWeight: FontWeight.normal)),
                          initialValue: snapshot.data.choices,
                          items: snapshot.data.listOfCategories
                              .map((e) => MultiSelectItem(e, e))
                              .toList(),
                          listType: MultiSelectListType.CHIP,
                          validator: (values) {
                            if (values.length <= 3)
                              return null;
                            else
                              return "No more than 3 categories";
                          },
                          onSaved: (values) {
                            categoriesBloc.categoriesQuery.add(values);
                          },
                          onConfirm: (values) {
                            if (!formKey.currentState.validate()) {
                              values.removeLast();
                              setState(() {
                                var test = values;
                              });
                              return false;
                            }
                            formKey.currentState.save();
                          },
                        );
                  },
                )
              ]),
            )));
  }
}
