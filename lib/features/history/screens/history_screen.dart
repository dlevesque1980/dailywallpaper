import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/widgets/carousel.dart';
import 'package:dailywallpaper/widgets/date_selector.dart';
import 'package:dailywallpaper/widgets/wallpaper_button.dart';
import 'package:dailywallpaper/features/history/screens/history_memory_manager.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';
import 'package:dailywallpaper/widgets/crop_info_dialog.dart';
import 'package:dailywallpaper/widgets/image_info_sheet.dart';
import 'package:dailywallpaper/features/history/screens/widgets/history_empty_state.dart';
import 'package:dailywallpaper/features/history/screens/widgets/history_error_state.dart';
import 'package:dailywallpaper/features/history/screens/widgets/history_app_bar.dart';
import 'package:dailywallpaper/features/history/screens/widgets/history_wallpaper_fab.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  ValueNotifier<int> notifierIndex = ValueNotifier(0);
  final HistoryMemoryManager _memoryManager = HistoryMemoryManager();
  DateTime? _currentDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _memoryManager.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _memoryManager.forceCleanupInactive();
    }
  }

  void _onChange(int index, bool refresh) {
    if (refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      if (notifierIndex.value != index) {
        notifierIndex.value = index;
        context.read<HistoryBloc>().add(HistoryEvent.indexChanged(index));
      }
    }
  }

  void _onDateSelected(DateTime date) {
    try {
      if (_currentDate != null) {
        final previousDateKey = _currentDate!.toIso8601String().split('T')[0];
        _memoryManager.unregisterActiveImage(previousDateKey);
      }

      notifierIndex.value = 0;
      _currentDate = date;

      final dateKey = date.toIso8601String().split('T')[0];
      _memoryManager.registerActiveImage(dateKey);

      context.read<HistoryBloc>().add(HistoryEvent.dateSelected(date));
    } catch (e) {
      debugPrint('Error in _onDateSelected: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content:
                Text(AppLocalizations.of(context)!.errorLoadingImagesForDate),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.retry,
              textColor: Colors.white,
              onPressed: () {
                context
                    .read<HistoryBloc>()
                    .add(HistoryEvent.dateSelected(date));
              },
            ),
          ),
        );
      }
    }
  }

  void _showCropInfo(BuildContext context, ImageItem image) {
    showDialog(
      context: context,
      builder: (context) => CropInfoDialog(image: image),
    );
  }

  void _showImageInfo(BuildContext context, ImageItem image) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => ImageInfoBottomSheet(image: image),
    );
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly == today;
  }

  String _formatSelectedDate(DateTime date) {
    return DateTimeHelper.formatDisplayDate(
      date,
      todayLabel: AppLocalizations.of(context)!.today,
      yesterdayLabel: AppLocalizations.of(context)!.yesterday,
    );
  }

  String _translateMessage(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    if (message == 'wallpaperSetSuccess') return l10n.wallpaperSetSuccess;
    if (message == 'invalidImageIndex') return l10n.invalidImageIndex;
    if (message.startsWith('failedToSetWallpaper')) {
      final detail =
          message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return '${l10n.failedToSetWallpaper}$detail';
    }
    if (message.startsWith('failedToInitializeHistory')) {
      final detail =
          message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return 'Failed to initialize history$detail'; // Add l10n key if needed
    }
    if (message.startsWith('failedToLoadImagesForDate')) {
      final detail =
          message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return '${l10n.errorLoadingImagesForDate}$detail';
    }
    return message;
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion(
      value: const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: HistoryAppBar(
          notifierIndex: notifierIndex,
          onDateSelected: _onDateSelected,
          onShowImageInfo: _showImageInfo,
          onShowCropInfo: _showCropInfo,
        ),
        floatingActionButton: HistoryWallpaperFab(
          notifierIndex: notifierIndex,
          translateMessage: _translateMessage,
        ),
        body: BlocBuilder<HistoryBloc, HistoryState>(
          builder: (context, state) {
            return state.map(
              initial: (_) => const SizedBox.shrink(),
              loading: (loadingState) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(),
                    const SizedBox(height: 16),
                    Text(
                      AppLocalizations.of(context)!.loadingImagesForDate(
                          _formatSelectedDate(loadingState.selectedDate)),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              loaded: (loadedState) {
                if (loadedState.images.isEmpty) {
                  return HistoryEmptyState(
                    state: state,
                    isToday: _isToday(state.selectedDate),
                    formattedDate: _formatSelectedDate(state.selectedDate),
                    onDateSelected: _onDateSelected,
                  );
                }

                if (notifierIndex.value >= loadedState.images.length) {
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      notifierIndex.value = loadedState.images.length - 1;
                    }
                  });
                }

                return Carousel(
                  list: loadedState.images,
                  onChange: _onChange,
                );
              },
              error: (errorState) => HistoryErrorState(
                state: state,
                error: errorState.message,
                translatedMessage:
                    _translateMessage(context, errorState.message),
                onRetry: _onDateSelected,
              ),
            );
          },
        ),
      ),
    );
  }
}
