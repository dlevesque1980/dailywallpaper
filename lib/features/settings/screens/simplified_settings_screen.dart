import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_event.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_state.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SimplifiedSettingsScreen extends StatelessWidget {
  const SimplifiedSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: BlocBuilder<SettingsBloc, SettingsState>(
        builder: (context, state) {
          if (state.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final bloc = context.read<SettingsBloc>();
          return ListView(
            children: [
              SwitchListTile(
                title: Text(l10n.setLockScreenWallpaper),
                subtitle: Text(l10n.applyWallpaperToLockScreen),
                value: state.includeLockWallpaper,
                onChanged: (value) =>
                    bloc.add(SettingsEvent.lockWallpaperToggled(value)),
              ),
              const Divider(),
              SwitchListTile(
                title: Text(l10n.includeNasaImages),
                subtitle: Text(l10n.includeNasaImagesDescription),
                value: state.includeNasa,
                onChanged: state.isSavingNasa
                    ? null
                    : (value) => bloc.add(SettingsEvent.nasaToggled(value)),
              ),
              if (state.isSavingNasa)
                const LinearProgressIndicator(minHeight: 2),
              const Divider(),
              ListTile(
                title: Text(l10n.pexelsCategories),
                subtitle: Text(
                  state.selectedCategories.join(', '),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: state.isSavingCategories
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.chevron_right),
                enabled: !state.isSavingCategories,
                onTap: state.isSavingCategories
                    ? null
                    : () => _showCategoriesDialog(context, state),
              ),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(
                    state.error!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCategoriesDialog(
    BuildContext context,
    SettingsState state,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final selected = state.selectedCategories.toSet();
    final categories = await showDialog<List<String>>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(l10n.pexelsCategories),
          content: SizedBox(
            width: double.maxFinite,
            height: 360,
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    children: [
                      for (final category in pexelsCategoryOptions)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(category),
                          value: selected.contains(category),
                          onChanged: (checked) {
                            if (checked == true &&
                                selected.length >= maxPexelsCategories) {
                              return;
                            }
                            setDialogState(() {
                              if (checked == true) {
                                selected.add(category);
                              } else {
                                selected.remove(category);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    selected.isEmpty
                        ? l10n.selectAtLeastOneCategory
                        : selected.length == maxPexelsCategories
                            ? l10n.noMoreThanThreeCategories
                            : '${selected.length}/$maxPexelsCategories',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: selected.isEmpty
                  ? null
                  : () => Navigator.of(dialogContext).pop(selected.toList()),
              child: Text(l10n.save),
            ),
          ],
        ),
      ),
    );
    if (categories != null && context.mounted) {
      final selectorOrderedCategories = pexelsCategoryOptions
          .where(categories.contains)
          .toList(growable: false);
      context
          .read<SettingsBloc>()
          .add(SettingsEvent.categoriesChanged(selectorOrderedCategories));
    }
  }
}
