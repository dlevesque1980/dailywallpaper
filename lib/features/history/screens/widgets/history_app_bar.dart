import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/widgets/date_selector.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

class HistoryAppBar extends StatelessWidget implements PreferredSizeWidget {
  final ValueNotifier<int> notifierIndex;
  final Function(DateTime) onDateSelected;
  final void Function(BuildContext, ImageItem) onShowImageInfo;
  final void Function(BuildContext, ImageItem) onShowCropInfo;

  const HistoryAppBar({
    Key? key,
    required this.notifierIndex,
    required this.onDateSelected,
    required this.onShowImageInfo,
    required this.onShowCropInfo,
  }) : super(key: key);

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<HistoryBloc, HistoryState>(
      builder: (context, state) {
        return AppBar(
          title: DateSelector(
            selectedDate: state.selectedDate,
            availableDates: state.availableDates,
            onDateSelected: onDateSelected,
            isLoading: state.mapOrNull(loading: (_) => true) ?? false,
          ),
          backgroundColor: Colors.transparent,
          elevation: 0.0,
          iconTheme: IconThemeData(
            color: Colors.white,
            shadows: [
              Shadow(
                offset: const Offset(1.0, 1.0),
                blurRadius: 3.0,
                color: Colors.black.withValues(alpha: 0.5),
              ),
            ],
          ),
          actions: [
            ValueListenableBuilder(
              valueListenable: notifierIndex,
              builder: (context, value, child) {
                return IconButton(
                  icon: Icon(
                    Icons.info_outline,
                    color: Colors.white,
                    shadows: [
                      Shadow(
                        offset: const Offset(1.0, 1.0),
                        blurRadius: 3.0,
                        color: Colors.black.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                  onPressed: () {
                    state.mapOrNull(loaded: (loadedState) {
                      if (loadedState.images.isNotEmpty) {
                        int safeIndex = notifierIndex.value;
                        if (safeIndex >= loadedState.images.length) {
                          safeIndex = loadedState.images.length - 1;
                        }
                        onShowImageInfo(context, loadedState.images[safeIndex]);
                      }
                    });
                  },
                );
              },
            ),
            PopupMenuButton<String>(
              onSelected: (choice) {
                if (choice == 'crop_info') {
                  state.mapOrNull(loaded: (loadedState) {
                    if (loadedState.images.isNotEmpty) {
                      int safeIndex = notifierIndex.value;
                      if (safeIndex >= loadedState.images.length) {
                        safeIndex = loadedState.images.length - 1;
                      }
                      onShowCropInfo(context, loadedState.images[safeIndex]);
                    }
                  });
                } else {
                  Navigator.pushNamed(context, choice);
                }
              },
              icon: Icon(
                Icons.more_vert,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: const Offset(1.0, 1.0),
                    blurRadius: 3.0,
                    color: Colors.black.withValues(alpha: 0.5),
                  ),
                ],
              ),
              itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
                PopupMenuItem<String>(
                  value: 'crop_info',
                  child: Row(
                    children: [
                      const Icon(Icons.center_focus_strong, size: 20),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.cropAnalysis),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: '/settings',
                  child: Row(
                    children: [
                      const Icon(Icons.settings, size: 20),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.settings),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: '/',
                  child: Row(
                    children: [
                      const Icon(Icons.home, size: 20),
                      const SizedBox(width: 8),
                      Text(AppLocalizations.of(context)!.home),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
