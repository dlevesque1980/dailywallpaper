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

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> with WidgetsBindingObserver {
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
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
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
            content: Text(AppLocalizations.of(context)!.errorLoadingImagesForDate),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: AppLocalizations.of(context)!.retry,
              textColor: Colors.white,
              onPressed: () {
                context.read<HistoryBloc>().add(HistoryEvent.dateSelected(date));
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
      final detail = message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return '${l10n.failedToSetWallpaper}$detail';
    }
    if (message.startsWith('failedToInitializeHistory')) {
      final detail = message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return 'Failed to initialize history$detail'; // Add l10n key if needed
    }
    if (message.startsWith('failedToLoadImagesForDate')) {
      final detail = message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return '${l10n.errorLoadingImagesForDate}$detail';
    }
    return message;
  }

  Widget _buildEmptyState(HistoryState state) {
    final isToday = _isToday(state.selectedDate);
    final formattedDate = _formatSelectedDate(state.selectedDate);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.image_not_supported_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noImagesAvailable,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              isToday
                  ? AppLocalizations.of(context)!.noWallpapersDownloadedToday
                  : AppLocalizations.of(context)!.noWallpapersSavedForDate(formattedDate),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            if (state.availableDates.isNotEmpty) ...[
              const SizedBox(height: 24),
              if (isToday) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context)!.goToHome),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  final mostRecentDate = state.availableDates.reduce(
                    (a, b) => a.isAfter(b) ? a : b,
                  );
                  _onDateSelected(mostRecentDate);
                },
                icon: const Icon(Icons.calendar_today),
                label: Text(AppLocalizations.of(context)!.viewRecentImages),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ] else ...[
              const SizedBox(height: 24),
              Text(
                AppLocalizations.of(context)!.noHistoricalImagesFound,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (isToday) ...[
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context)!.goToHome),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(HistoryState state, String error) {
    final isDatabaseError = error.toLowerCase().contains('database') || error.toLowerCase().contains('sql');
    final isNetworkError = error.toLowerCase().contains('network') || error.toLowerCase().contains('connection');

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isDatabaseError
                  ? Icons.storage_outlined
                  : isNetworkError
                      ? Icons.wifi_off_outlined
                      : Icons.error_outline,
              size: 80,
              color: Colors.red[400],
            ),
            const SizedBox(height: 16),
            Text(
              isDatabaseError
                  ? AppLocalizations.of(context)!.databaseError
                  : isNetworkError
                      ? AppLocalizations.of(context)!.connectionError
                      : AppLocalizations.of(context)!.error,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _translateMessage(context, error),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    _onDateSelected(state.selectedDate);
                  },
                  icon: const Icon(Icons.refresh),
                  label: Text(AppLocalizations.of(context)!.retry),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: const Icon(Icons.home),
                  label: Text(AppLocalizations.of(context)!.home),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
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
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: BlocBuilder<HistoryBloc, HistoryState>(
            builder: (context, state) {
              return AppBar(
                title: DateSelector(
                  selectedDate: state.selectedDate,
                  availableDates: state.availableDates,
                  onDateSelected: _onDateSelected,
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
                              _showImageInfo(context, loadedState.images[safeIndex]);
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
                            _showCropInfo(context, loadedState.images[safeIndex]);
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
          ),
        ),
        floatingActionButton: ValueListenableBuilder(
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
                      msg: _translateMessage(context, loadedState.wallpaperMessage!),
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
                      AppLocalizations.of(context)!.loadingImagesForDate(_formatSelectedDate(loadingState.selectedDate)),
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
                  return _buildEmptyState(state);
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
              error: (errorState) => _buildErrorState(state, errorState.message),
            );
          },
        ),
      ),
    );
  }
}
