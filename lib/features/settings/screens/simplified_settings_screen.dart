import 'package:dailywallpaper/features/settings/bloc/settings_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_event.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_state.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_event.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_state.dart';
import 'package:dailywallpaper/data/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/widgets/smart_crop_quality_slider.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:multi_select_flutter/dialog/multi_select_dialog_field.dart';
import 'package:multi_select_flutter/util/multi_select_item.dart';
import 'package:multi_select_flutter/util/multi_select_list_type.dart';
import 'package:dailywallpaper/features/settings/bloc/bing_region_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

class SimplifiedSettingsScreen extends StatefulWidget {
  const SimplifiedSettingsScreen({Key? key}) : super(key: key);

  @override
  _SimplifiedSettingsScreenState createState() => _SimplifiedSettingsScreenState();
}

class _SimplifiedSettingsScreenState extends State<SimplifiedSettingsScreen> {
  final formKey = GlobalKey<FormState>();

  void showBingRegion(BuildContext context, BingRegionEnum currentChoice, List<RegionItem> thumbnails) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext bottomSheetContext) {
        if (thumbnails.isNotEmpty) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8.0, top: 8.0),
            child: GridView.count(
              crossAxisCount: 3,
              children: thumbnails.map<Widget>((item) {
                return InkWell(
                  onTap: () {
                    context.read<SettingsBloc>().add(SettingsEvent.regionChanged(item.value));
                    Navigator.of(bottomSheetContext).pop();
                  },
                  child: GridTile(
                    footer: GridTileBar(
                      backgroundColor: Colors.black45,
                      title: Text(BingRegionEnum.labelOf(item.value)),
                      trailing: item.value == currentChoice
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                    ),
                    child: item.url.isNotEmpty
                        ? Image.network(item.url, fit: BoxFit.cover)
                        : const Center(child: Icon(Icons.image_not_supported)),
                  ),
                );
              }).toList(),
            ),
          );
        }

        return Container(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppLocalizations.of(context)!.selectRegion,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: BingRegionEnum.values.map((region) {
                    final isSelected = region == currentChoice;
                    return ListTile(
                      title: Text(BingRegionEnum.labelOf(region)),
                      trailing: isSelected
                          ? const Icon(Icons.check, color: Colors.blue)
                          : null,
                      selected: isSelected,
                      onTap: () {
                        context.read<SettingsBloc>().add(SettingsEvent.regionChanged(region));
                        Navigator.of(bottomSheetContext).pop();
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
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (didPop) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.settings, style: const TextStyle(color: Colors.white)),
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
          child: BlocBuilder<SettingsBloc, SettingsState>(
            builder: (context, state) {
              if (state.isLoading) {
                return const Center(child: CircularProgressIndicator());
              }

              return ListView(
                padding: const EdgeInsets.all(16.0),
                children: <Widget>[
                  // Lock Screen Setting
                  SwitchListTile(
                    title: Text(
                      l10n.setLockScreenWallpaper,
                      style: const TextStyle(fontSize: 18.0),
                    ),
                    subtitle: Text(l10n.applyWallpaperToLockScreen),
                    value: state.includeLockWallpaper,
                    onChanged: (value) =>
                        context.read<SettingsBloc>().add(SettingsEvent.lockWallpaperToggled(value)),
                  ),

                  const Divider(),

                  // Bing Region Setting
                  ListTile(
                    title: Text(
                      l10n.bingRegion,
                      style: const TextStyle(fontSize: 18.0),
                    ),
                    subtitle: Text(l10n.selectPreferredRegion),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          BingRegionEnum.labelOf(state.selectedRegion),
                          style: const TextStyle(
                            fontSize: 16.0,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const Icon(Icons.arrow_drop_down),
                      ],
                    ),
                    onTap: () => showBingRegion(context, state.selectedRegion, state.thumbnails),
                  ),

                  const Divider(),

                  // Pexels Categories Setting
                  BlocBuilder<PexelsCategoriesBloc, PexelsCategoriesState>(
                    builder: (context, pexelsState) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: MultiSelectDialogField(
                          autovalidateMode: AutovalidateMode.disabled,
                          title: Text(l10n.pexelsCategories),
                          buttonText: Text(
                            l10n.pexelsCategories,
                            style: const TextStyle(fontSize: 18.0),
                          ),
                          initialValue: pexelsState.selectedCategories,
                          items: pexelsState.allCategories
                              .map((category) => MultiSelectItem(category, category))
                              .toList(),
                          listType: MultiSelectListType.CHIP,
                          validator: (values) {
                            if (values == null || values.isEmpty) {
                              return l10n.selectAtLeastOneCategory;
                            }
                            if (values.length > 5) {
                              return l10n.noMoreThanFiveCategories;
                            }
                            return null;
                          },
                          onSaved: (values) {
                            if (values != null) {
                              context.read<PexelsCategoriesBloc>().add(
                                  PexelsCategoriesEvent.categoriesChanged(values.cast<String>()));
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

                  const Divider(),

                  SmartCropQualitySlider(
                    currentLevel: state.smartCropLevel,
                    onLevelChanged: (level) =>
                        context.read<SettingsBloc>().add(SettingsEvent.smartCropLevelChanged(level)),
                    subjectScalingEnabled: state.enableSubjectScaling,
                    onScalingToggled: (value) =>
                        context.read<SettingsBloc>().add(SettingsEvent.subjectScalingToggled(value)),
                  ),

                  const SizedBox(height: 20),

                  if (state.deviceCapability != null)
                    _buildMlStatus(context, state.deviceCapability!),
                  
                  const SizedBox(height: 30),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildMlStatus(BuildContext context, dynamic cap) {
    final l10n = AppLocalizations.of(context)!;
    final mlStatus = cap.isEmulator ? l10n.simulatedEmulator : l10n.active;
    final mlColor = cap.isEmulator ? Colors.orange[700] : Colors.green[700];

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
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
              Icon(Icons.psychology, size: 20.0, color: mlColor),
              const SizedBox(width: 10.0),
              Text(
                l10n.mlEngineStatus,
                style: const TextStyle(
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
            l10n.modelSubjectSegmentation,
            style: TextStyle(
              fontSize: 12.0,
              color: Colors.grey[600],
            ),
          ),
          if (cap.isEmulator)
            Padding(
              padding: const EdgeInsets.only(top: 4.0),
              child: Text(
                l10n.realMlDisabledEmulator,
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
}
