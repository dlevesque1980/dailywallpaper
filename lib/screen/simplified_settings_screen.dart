import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/bloc_provider/settings_provider.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/bloc_state/pexels_categories_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_profile_manager.dart';
import 'package:dailywallpaper/utils/transparent_error_handling.dart';
import 'package:dailywallpaper/widget/bing_region_image_setting.dart';
import 'package:dailywallpaper/widget/smart_crop_quality_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';

/// Simplified Settings Screen with only essential options
///
/// This screen provides a clean, stable interface with just 4 main sections:
/// 1. Lock Screen wallpaper toggle
/// 2. Bing region selector
/// 3. Pexels categories selector
/// 4. Smart Crop quality slider (4 levels: Off, Conservative, Balanced, Aggressive)
class SimplifiedSettingsScreen extends StatefulWidget {
  SimplifiedSettingsScreen()
      : super(key: const Key('__simplifiedSettingsScreen__'));

  @override
  _SimplifiedSettingsScreenState createState() =>
      _SimplifiedSettingsScreenState();
}

class _SimplifiedSettingsScreenState extends State<SimplifiedSettingsScreen> {
  SettingsBloc? settingsBloc;
  PexelsCategoriesBloc? pexelsCategoriesBloc;
  final formKey = GlobalKey<FormState>();

  // Current Smart Crop level (0-3)
  int _currentSmartCropLevel = SmartCropProfileManager.defaultLevel;

  @override
  void initState() {
    super.initState();
    _loadCurrentSmartCropLevel();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initialize the blocs to load data
    settingsBloc = SettingsProvider.of(context).settingsBloc;
    pexelsCategoriesBloc = SettingsProvider.of(context).pexelsCategoriesBloc;

    // Trigger initial data loading
    settingsBloc?.regionQuery.add("");
    pexelsCategoriesBloc?.categoriesQuery.add([]);
  }

  /// Load the current Smart Crop level from preferences
  Future<void> _loadCurrentSmartCropLevel() async {
    final level = await TransparentErrorHandling.handleConfigurationError(
      () => SmartCropProfileManager.getCurrentLevel(),
      SmartCropProfileManager.defaultLevel,
      errorContext: 'Smart Crop level loading',
    );

    if (mounted) {
      setState(() {
        _currentSmartCropLevel = level;
      });
    }
  }

  /// Handle Smart Crop level changes
  Future<void> _onSmartCropLevelChanged(int newLevel) async {
    if (newLevel != _currentSmartCropLevel) {
      setState(() {
        _currentSmartCropLevel = newLevel;
      });
    }
  }

  /// Show Bing region selection modal
  void showBingRegion(BuildContext context, BingRegionState state) {
    // Trigger thumbnail loading when modal opens
    settingsBloc?.thumbnailQuery.add("");

    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return StreamBuilder<List<RegionItem>>(
          stream: settingsBloc?.thumbnail,
          builder: (context, snapshot) {
            // If we have data, show the regions
            if (snapshot.hasData && snapshot.data!.isNotEmpty) {
              return Container(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
                  child: GridView.count(
                    crossAxisCount: 3,
                    children: snapshot.data!.map<Widget>((item) {
                      return BingImageRegionSetting(
                        settingsBloc: settingsBloc!,
                        item: item,
                        choice: state.choice,
                        key: Key('BingImageRegionSettings'),
                      );
                    }).toList(),
                  ),
                ),
              );
            }

            // If still loading or no data, show a simple list of regions without thumbnails
            return Container(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Select Region',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView(
                      children: BingRegionEnum.values.map((region) {
                        final isSelected = region == state.choice;
                        return ListTile(
                          title: Text(BingRegionEnum.labelOf(region)),
                          trailing: isSelected
                              ? const Icon(Icons.check, color: Colors.blue)
                              : null,
                          selected: isSelected,
                          onTap: () {
                            settingsBloc?.regionQuery
                                .add(BingRegionEnum.definitionOf(region));
                            Navigator.of(context).pop();
                          },
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  void dispose() {
    settingsBloc?.dispose();
    pexelsCategoriesBloc?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic) async {
        if (didPop) return;
        final NavigatorState navigator = Navigator.of(context);
        navigator.pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Settings", style: TextStyle(color: Colors.white)),
          backgroundColor: const Color.fromRGBO(0, 0, 0, 0.3),
          elevation: 0.0,
          iconTheme: const IconThemeData(color: Colors.white),
          systemOverlayStyle: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.light,
          ),
        ),
        body: Form(
          key: formKey,
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: <Widget>[
              // Lock Screen Setting
              TransparentErrorHandling.safeStreamBuilder<bool>(
                stream: settingsBloc?.includeLock,
                initialData: false, // Provide sensible default
                showLoadingOnWaiting: false, // Prevent persistent loading
                builder: (context, data) {
                  return SwitchListTile(
                    title: const Text(
                      "Set lock screen wallpaper",
                      style: TextStyle(fontSize: 18.0),
                    ),
                    subtitle: const Text("Apply wallpaper to lock screen"),
                    value: data,
                    onChanged: (value) =>
                        settingsBloc?.lockQuery.add(value.toString()),
                  );
                },
                errorWidget: SwitchListTile(
                  title: const Text(
                    "Set lock screen wallpaper",
                    style: TextStyle(fontSize: 18.0),
                  ),
                  subtitle: const Text("Apply wallpaper to lock screen"),
                  value: false, // Default value on error
                  onChanged: (value) =>
                      settingsBloc?.lockQuery.add(value.toString()),
                ),
              ),

              Divider(),

              // Bing Region Setting
              StreamBuilder<BingRegionState>(
                stream: settingsBloc?.regions,
                initialData: BingRegionState(BingRegionEnum.US),
                builder: (context, snapshot) {
                  final data =
                      snapshot.data ?? BingRegionState(BingRegionEnum.US);

                  return ListTile(
                    title: const Text(
                      "Bing region",
                      style: TextStyle(fontSize: 18.0),
                    ),
                    subtitle: const Text(
                        "Select your preferred region for Bing images"),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          BingRegionEnum.labelOf(data.choice),
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                    onTap: () => showBingRegion(context, data),
                  );
                },
              ),

              Divider(),

              // Pexels Categories Setting
              StreamBuilder<PexelsCategoriesState>(
                stream: pexelsCategoriesBloc?.categories,
                initialData: PexelsCategoriesState(
                  [
                    'nature',
                    'animals',
                    'architecture',
                    'art',
                    'cars',
                    'city',
                    'food',
                    'forest',
                    'landscape',
                    'mountain',
                    'ocean',
                    'people',
                    'technology'
                  ],
                  ['nature'],
                ),
                builder: (context, snapshot) {
                  final data = snapshot.data ??
                      PexelsCategoriesState(
                        [
                          'nature',
                          'animals',
                          'architecture',
                          'art',
                          'cars',
                          'city',
                          'food',
                          'forest',
                          'landscape',
                          'mountain',
                          'ocean',
                          'people',
                          'technology'
                        ],
                        ['nature'],
                      );

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: MultiSelectDialogField(
                      autovalidateMode: AutovalidateMode.disabled,
                      title: const Text('Pexels Categories'),
                      buttonText: const Text(
                        'Pexels Categories',
                        style: TextStyle(fontSize: 18.0),
                      ),
                      initialValue: data.selectedCategories,
                      items: data.availableCategories
                          .map(
                              (category) => MultiSelectItem(category, category))
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
                        if (values != null && pexelsCategoriesBloc != null) {
                          pexelsCategoriesBloc!.categoriesQuery
                              .add(values.cast<String>());
                        }
                      },
                      onConfirm: (values) {
                        if (formKey.currentState!.validate()) {
                          formKey.currentState!.save();
                        }
                      },
                    ),
                  );
                },
              ),

              Divider(),

              // Smart Crop Quality Section - Using custom slider widget
              SmartCropQualitySlider(
                currentLevel: _currentSmartCropLevel,
                onLevelChanged: _onSmartCropLevelChanged,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
