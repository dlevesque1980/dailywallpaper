import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/bloc_provider/settings_provider.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/bloc_state/pexels_categories_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop.dart';
import 'package:dailywallpaper/widget/bing_region_image_setting.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';

class SettingScreen extends StatefulWidget {
  SettingScreen() : super(key: const Key('__settingScreen__'));
  @override
  _SettingScreenState createState() => new _SettingScreenState();
}

class _SettingScreenState extends State<SettingScreen> {
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

  bool? initialNASAData(Sink<String> nasaQuery) {
    nasaQuery.add("");
    return null;
  }

  PexelsCategoriesState? initialPexelsCategories(Sink<List<String>> categoriesQuery) {
    categoriesQuery.add(<String>[]);
    return null;
  }

  bool? initialSmartCropEnabled(Sink<String> smartCropEnabledQuery) {
    smartCropEnabledQuery.add("");
    return null;
  }

  CropAggressiveness? initialSmartCropAggressiveness(Sink<String> smartCropAggressivenessQuery) {
    smartCropAggressivenessQuery.add("");
    return null;
  }

  CropSettings? initialSmartCropSettings(Sink<String> smartCropSettingsQuery) {
    smartCropSettingsQuery.add("");
    return null;
  }

  Map<String, dynamic>? initialCacheStatistics(Sink<String> cacheStatisticsQuery) {
    cacheStatisticsQuery.add("");
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

  String _getAggressivenessLabel(CropAggressiveness aggressiveness) {
    switch (aggressiveness) {
      case CropAggressiveness.conservative:
        return "Conservative";
      case CropAggressiveness.balanced:
        return "Balanced";
      case CropAggressiveness.aggressive:
        return "Aggressive";
    }
  }

  Widget _buildStrategyToggle(String title, bool value, Function(bool) onChanged) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      mainAxisSize: MainAxisSize.max,
      children: <Widget>[
        Container(
          padding: EdgeInsets.only(left: 20.0),
          child: Text(title,
              style: TextStyle(
                fontSize: 17.0,
                fontWeight: FontWeight.normal,
                color: Colors.grey[600],
              )),
        ),
        Switch(
          value: value,
          onChanged: onChanged,
        )
      ],
    );
  }

  void _updateCropSettings(CropSettings currentSettings, {
    bool? enableRuleOfThirds,
    bool? enableEntropyAnalysis,
    bool? enableEdgeDetection,
    bool? enableCenterWeighting,
  }) {
    final updatedSettings = currentSettings.copyWith(
      enableRuleOfThirds: enableRuleOfThirds,
      enableEntropyAnalysis: enableEntropyAnalysis,
      enableEdgeDetection: enableEdgeDetection,
      enableCenterWeighting: enableCenterWeighting,
    );
    settingsBloc.smartCropSettingsQuery.add(updatedSettings.toJson());
  }

  Widget _buildCacheStatistic(String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20.0, vertical: 2.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.normal,
              color: Colors.grey[600],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16.0,
              fontWeight: FontWeight.bold,
              color: Colors.grey[800],
            ),
          ),
        ],
      ),
    );
  }

  void _refreshCacheStatistics() {
    settingsBloc.cacheStatisticsQuery.add(DateTime.now().millisecondsSinceEpoch.toString());
  }

  void _showClearCacheDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text("Clear Crop Cache"),
          content: Text(
            "This will delete all cached crop coordinates. "
            "Images will need to be re-analyzed when displayed. "
            "Are you sure you want to continue?",
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text("Cancel"),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _clearCache();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.red,
              ),
              child: Text("Clear Cache"),
            ),
          ],
        );
      },
    );
  }

  Future<void> _clearCache() async {
    try {
      final deletedCount = await SmartCropPreferences.clearCropCache();
      
      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Cache cleared successfully. Deleted $deletedCount entries."),
          backgroundColor: Colors.green,
        ),
      );
      
      // Refresh statistics
      _refreshCacheStatistics();
      
    } catch (e) {
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to clear cache: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
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
                              choice: state.choice, key: Key('BingImageRegionSettings'),);
                        }).toList()),
                  ));
            },
          );
        });
  }

  @override
  Widget build(BuildContext context) {
    final ButtonStyle flatButtonStyle = TextButton.styleFrom(
      foregroundColor: Colors.black87, minimumSize: Size(88, 36),
      padding: EdgeInsets.symmetric(horizontal: 16.0),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2.0)),
      ),
    );
    settingsBloc = SettingsProvider.of(context).settingsBloc;
    pexelsCategoriesBloc = SettingsProvider.of(context).pexelsCategoriesBloc;
    return   PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop,dynamic) async {
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
                StreamBuilder<bool>(
                  initialData: initialNASAData(settingsBloc.nasaQuery),
                  stream: settingsBloc.nasaEnabled,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text("Include NASA images",
                                  style: TextStyle(
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.normal,
                                  )),
                            ),
                            Switch(
                                value: snapshot.data!,
                                onChanged: (value) => settingsBloc.nasaQuery
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
                  initialData: initialPexelsCategories(pexelsCategoriesBloc.categoriesQuery),
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
                              .map((category) => MultiSelectItem(category, category))
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
                              pexelsCategoriesBloc.categoriesQuery.add(values.cast<String>());
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
                  initialData: initialSmartCropEnabled(settingsBloc.smartCropEnabledQuery),
                  stream: settingsBloc.smartCropEnabled,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          mainAxisSize: MainAxisSize.max,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text("Enable Smart Crop",
                                  style: TextStyle(
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.normal,
                                  )),
                            ),
                            Switch(
                                value: snapshot.data!,
                                onChanged: (value) => settingsBloc.smartCropEnabledQuery
                                    .add(value.toString()))
                          ],
                        );
                  },
                ),
                Container(padding: EdgeInsets.all(5.0)),
                StreamBuilder<CropAggressiveness>(
                  initialData: initialSmartCropAggressiveness(settingsBloc.smartCropAggressivenessQuery),
                  stream: settingsBloc.smartCropAggressiveness,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: <Widget>[
                            Container(
                              padding: EdgeInsets.only(left: 10.0),
                              child: Text("Crop Aggressiveness",
                                  style: TextStyle(
                                    fontSize: 19.0,
                                    fontWeight: FontWeight.normal,
                                  )),
                            ),
                            DropdownButton<CropAggressiveness>(
                              value: snapshot.data!,
                              items: CropAggressiveness.values.map((aggressiveness) {
                                return DropdownMenuItem<CropAggressiveness>(
                                  value: aggressiveness,
                                  child: Text(_getAggressivenessLabel(aggressiveness)),
                                );
                              }).toList(),
                              onChanged: (value) {
                                if (value != null) {
                                  settingsBloc.smartCropAggressivenessQuery.add(value.name);
                                }
                              },
                            ),
                          ],
                        );
                  },
                ),
                Container(padding: EdgeInsets.all(5.0)),
                StreamBuilder<CropSettings>(
                  initialData: initialSmartCropSettings(settingsBloc.smartCropSettingsQuery),
                  stream: settingsBloc.smartCropSettings,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Column(
                          children: [
                            _buildStrategyToggle(
                              "Rule of Thirds Analysis",
                              snapshot.data!.enableRuleOfThirds,
                              (value) => _updateCropSettings(snapshot.data!, enableRuleOfThirds: value),
                            ),
                            _buildStrategyToggle(
                              "Entropy Analysis",
                              snapshot.data!.enableEntropyAnalysis,
                              (value) => _updateCropSettings(snapshot.data!, enableEntropyAnalysis: value),
                            ),
                            _buildStrategyToggle(
                              "Edge Detection",
                              snapshot.data!.enableEdgeDetection,
                              (value) => _updateCropSettings(snapshot.data!, enableEdgeDetection: value),
                            ),
                            _buildStrategyToggle(
                              "Center Weighting",
                              snapshot.data!.enableCenterWeighting,
                              (value) => _updateCropSettings(snapshot.data!, enableCenterWeighting: value),
                            ),
                          ],
                        );
                  },
                ),
                Container(padding: EdgeInsets.all(10.0)),
                // Cache Management Section
                Container(
                  padding: EdgeInsets.only(left: 10.0, bottom: 10.0),
                  child: Text("Cache Management",
                      style: TextStyle(
                        fontSize: 20.0,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[700],
                      )),
                ),
                StreamBuilder<Map<String, dynamic>>(
                  initialData: initialCacheStatistics(settingsBloc.cacheStatisticsQuery),
                  stream: settingsBloc.cacheStatistics,
                  builder: (context, snapshot) {
                    return handleSnapshotState(snapshot) ??
                        Column(
                          children: [
                            _buildCacheStatistic("Cache Entries", "${snapshot.data!['totalEntries'] ?? 0}"),
                            _buildCacheStatistic("Cache Size", "${(snapshot.data!['totalSizeMB'] ?? 0.0).toStringAsFixed(2)} MB"),
                            _buildCacheStatistic("Hit Rate", "${(snapshot.data!['hitRatePercentage'] ?? 0.0).toStringAsFixed(1)}%"),
                            _buildCacheStatistic("Cache Age", "${snapshot.data!['cacheAgeDays'] ?? 0} days"),
                            Container(padding: EdgeInsets.all(5.0)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                ElevatedButton(
                                  onPressed: () => _refreshCacheStatistics(),
                                  child: Text("Refresh Stats"),
                                ),
                                ElevatedButton(
                                  onPressed: () => _showClearCacheDialog(context),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                  ),
                                  child: Text("Clear Cache"),
                                ),
                              ],
                            ),
                          ],
                        );
                  },
                )
              ]),
            )));
  }
}
