import 'package:dailywallpaper/features/settings/bloc/settings_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_provider.dart';
import 'package:dailywallpaper/features/settings/bloc/bing_region_state.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_state.dart';
import 'package:dailywallpaper/data/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_profile_manager.dart';
import 'package:dailywallpaper/core/utils/transparent_error_handling.dart';
import 'package:dailywallpaper/widgets/bing_region_image_setting.dart';
import 'package:dailywallpaper/widgets/smart_crop_quality_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';
import 'package:dailywallpaper/services/smart_crop/utils/device_capability_detector.dart';

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

              const SizedBox(height: 20),

              // ML Status Info
              FutureBuilder<DeviceCapability>(
                future: DeviceCapabilityDetector.getDeviceCapability(),
                builder: (context, capabilitySnapshot) {
                  if (capabilitySnapshot.hasData) {
                    final cap = capabilitySnapshot.data!;
                    final mlStatus =
                        cap.isEmulator ? "Simulated (Emulator)" : "Active";
                    final mlColor =
                        cap.isEmulator ? Colors.orange[700] : Colors.green[700];

                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16.0, vertical: 12.0),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8.0),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.psychology,
                                  size: 20.0, color: mlColor),
                              const SizedBox(width: 10.0),
                              const Text(
                                "ML Engine Status",
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                ),
                              ),
                              const Spacer(),
                              Text(
                                mlStatus,
                                style: TextStyle(
                                  color: mlColor,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6.0),
                          Text(
                            "Model: Subject Segmentation v8 (Mobile f16)",
                            style: TextStyle(
                              fontSize: 12.0,
                              color: Colors.grey[600],
                            ),
                          ),
                          if (cap.isEmulator)
                            Padding(
                              padding: const EdgeInsets.only(top: 4.0),
                              child: Text(
                                "⚠️ Real ML is disabled on emulator to avoid crashes.",
                                style: TextStyle(
                                  fontSize: 11.0,
                                  color: Colors.orange[900],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }
}
