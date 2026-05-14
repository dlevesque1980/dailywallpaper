import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/widgets/wallpaper_button.dart';

class HistoryWallpaperFab extends StatelessWidget {
  final ValueNotifier<int> notifierIndex;
  final String Function(BuildContext, String) translateMessage;

  const HistoryWallpaperFab({
    Key? key,
    required this.notifierIndex,
    required this.translateMessage,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: notifierIndex,
      builder: (context, value, child) {
        return BlocConsumer<HistoryBloc, HistoryState>(
          listenWhen: (previous, current) {
            return current.mapOrNull(
              loaded: (curr) {
                final prev = previous.mapOrNull(loaded: (p) => p);
                return prev != null && 
                       curr.wallpaperMessage != null && 
                       curr.wallpaperMessage != prev.wallpaperMessage;
              }
            ) ?? false;
          },
          listener: (context, state) {
            state.mapOrNull(loaded: (loadedState) {
              if (loadedState.wallpaperMessage != null) {
                Fluttertoast.showToast(
                  msg: translateMessage(context, loadedState.wallpaperMessage!),
                  toastLength: Toast.LENGTH_SHORT,
                  gravity: ToastGravity.BOTTOM,
                );
              }
            });
          },
          builder: (context, state) {
            bool hasImages = false;
            bool isSetting = false;
            bool isSuccess = false;

            state.mapOrNull(loaded: (loadedState) {
              hasImages = loadedState.images.isNotEmpty;
              isSetting = loadedState.isSettingWallpaper;
              isSuccess = loadedState.wallpaperMessage != null && 
                         (loadedState.wallpaperMessage == 'wallpaperSetSuccess');
            });

            if (!hasImages) {
              return const SizedBox.shrink();
            }

            return WallpaperButton(
              onPressed: () {
                context.read<HistoryBloc>().add(HistoryEvent.wallpaperUpdateRequested(notifierIndex.value));
              },
              isSettingWallpaper: isSetting,
              isSuccess: isSuccess,
            );
          },
        );
      },
    );
  }
}
