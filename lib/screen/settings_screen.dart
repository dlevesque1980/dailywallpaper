import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/bloc_provider/settings_provider.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/bloc_state/pexels_categories_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/widget/bing_region_image_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';

class LegacySettingsScreen extends StatefulWidget {
  LegacySettingsScreen() : super(key: const Key('__legacySettingsScreen__'));
  @override
  _LegacySettingsScreenState createState() => new _LegacySettingsScreenState();
}

class _LegacySettingsScreenState extends State<LegacySettingsScreen> {
  late SettingsBloc settingsBloc;
  late PexelsCategoriesBloc pexelsCategoriesBloc;
  final formKey = new GlobalKey<FormState>();

  BingRegionState? initialBingData(Sink<String> regionQuery) {
    regionQuery.add("");
    return null;
  }

  List<RegionItem>? initialThumbnail(Sink<String> thumbnailQuery) {
    thumbnailQuery.add("");
    return null;
  }

  bool? initialLockData(Sink<String> lockQuery) {
    lockQuery.add("");
    return null;
  }

  bool? initialSmartCropEnabled(Sink<String> smartCropEnabledQuery) {
    smartCropEnabledQuery.add("");
    return null;
  }

  PexelsCategoriesState? initialPexelsCategories(
      Sink<List<String>> categoriesQuery) {
    categoriesQuery.add(<String>[]);
    return null;
  }

  @override
  void dispose() {
    settingsBloc.dispose();
    pexelsCategoriesBloc.dispose();
    super.dispose();
  }

  Widget? handleSnapshotState<T>(AsyncSnapshot<T> snapshot) {
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
                        children: snapshot.data!.map<Widget>((item) {
                          return BingImageRegionSetting(
                            settingsBloc: settingsBloc,
                            item: item,
                            choice: state.choice,
                            key: Key('BingImageRegionSettings'),
                          );
                        }).toList()),
                  ));
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle flatButtonStyle = TextButton.styleFrom(
      foregroundColor: Colors.black87,
      minimumSize: Size(88, 36),
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ),
    );
    settingsBloc = SettingsProvider.of(context).settingsBloc;
    pexelsCategoriesBloc = SettingsProvider.of(context).pexelsCategoriesBloc;
    return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic) async {
          if (didPop) return;
          final NavigatorState navigator = Navigator.of(context);
          navigator.pop();
        },
        child: Scaffold(
            appBar: AppBar(
              title: Text("Settings", style: TextStyle(color: Colors.white)),
              backgroundColor: Color.fromRGBO(0, 0, 0, 0.3),
              elevation: 0.0,
              iconTheme: IconThemeData(color: Colors.white),
              systemOverlayStyle: SystemUiOverlayStyle(
                statusBarColor: Colors.transparent,
                statusBarIconBrightness: Brightness.light,
              ),
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
                                value: snapshot.data!,
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
                                            snapshot.data!.choice),
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
                                  showBingRegion(context, snapshot.data!),
                            ),
                          ],
                        );
                  },
                ),
                Container(padding: EdgeInsets.all(5.0)),
                StreamBuilder<PexelsCategoriesState>(
                  initialData: initialPexelsCategories(
                      pexelsCategoriesBloc.categoriesQuery),
                  stream: pexelsCategoriesBloc.categories,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        MultiSelectDialogField(
                          autovalidateMode: AutovalidateMode.disabled,
                          title: Text('Pexels Categories'),
                          buttonText: Text('Pexels Categories',
                              style: TextStyle(
                                  fontSize: 19.0,
                                  fontWeight: FontWeight.normal)),
                          initialValue: snapshot.data!.selectedCategories,
                          items: snapshot.data!.availableCategories
                              .map((category) =>
                                  MultiSelectItem(category, category))
                              .toList(),
                          listType: MultiSelectListType.CHIP,
                          validator: (values) {
                            if (values == null || values.isEmpty) {
                              return "Please select at least one category";
                            }
                            if (values.length > 5) {
                              return "No more than 5 categories";
                            }
                            return null;
                          },
                          onSaved: (values) {
                            if (values != null) {
                              pexelsCategoriesBloc.categoriesQuery
                                  .add(values.cast<String>());
                            }
                          },
                          onConfirm: (values) {
                            if (formKey.currentState!.validate()) {
                              formKey.currentState!.save();
                            }
                          },
                        );
                  },
                ),
                Container(padding: EdgeInsets.all(10.0)),
                // Smart Crop Settings Section
                Container(
                  padding: EdgeInsets.only(left: 10.0, bottom: 10.0),
                  child: Text("Smart Crop Settings",
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      )),
                ),
                StreamBuilder<bool>(
                  initialData: initialSmartCropEnabled(
                      settingsBloc.smartCropEnabledQuery),
                  stream: settingsBloc.smartCropEnabled,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              mainAxisSize: MainAxisSize.max,
                              children: <Widget>[
                                Container(
                                  padding: EdgeInsets.only(left: 10.0),
                                  child: Text("Smart Crop",
                                      style: TextStyle(
                                        fontSize: 19.0,
                                        fontWeight: FontWeight.normal,
                                      )),
                                ),
                                Switch(
                                    value: snapshot.data!,
                                    onChanged: (value) => settingsBloc
                                        .smartCropEnabledQuery
                                        .add(value.toString()))
                              ],
                            ),
                            Container(
                              padding: EdgeInsets.only(
                                  left: 10.0, right: 10.0, top: 5.0),
                              child: Text(
                                "Automatically optimizes image cropping for better composition. Uses balanced settings with battery optimization enabled.",
                                style: TextStyle(
                                  fontSize: 14.0,
                                  color: Colors.grey[600],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        );
                  },
                ),
              ]),
            )));
  }
}
