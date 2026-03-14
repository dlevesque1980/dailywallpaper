import 'package:dailywallpaper/bloc/history_bloc.dart';
import 'package:dailywallpaper/bloc_provider/history_provider.dart';
import 'package:dailywallpaper/bloc_state/history_state.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/widget/carousel.dart';
import 'package:dailywallpaper/widget/date_selector.dart';
import 'package:dailywallpaper/widget/wallpaper_button.dart';
import 'package:dailywallpaper/screen/history_memory_manager.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

class HistoryScreen extends StatefulWidget {
  HistoryScreen() : super(key: const Key('__historyScreen__'));

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with WidgetsBindingObserver {
  ValueNotifier<int> notifierIndex = ValueNotifier(0);
  HistoryBloc? historyBloc;
  final HistoryMemoryManager _memoryManager = HistoryMemoryManager();
  DateTime? _currentDate;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    if (historyBloc == null) {
      historyBloc = HistoryProvider.of(context);
      // Initialize the bloc with today's date
      historyBloc!.initialize();
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _memoryManager.dispose();
    historyBloc?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // Clean up memory when app goes to background
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      _memoryManager.forceCleanupInactive();
      historyBloc?.clearCache();
    }
  }

  void _onChange(int index, bool refresh) {
    // Only update if not during build
    if (refresh) {
      // Defer setState to avoid calling during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            // Refresh the UI when needed
          });
        }
      });
    } else {
      // Safe to update index immediately for normal tab changes
      if (notifierIndex.value != index) {
        notifierIndex.value = index;
      }
    }
  }

  void _onDateSelected(DateTime date) {
    try {
      // Clean up memory for previous date
      if (_currentDate != null) {
        final previousDateKey = _currentDate!.toIso8601String().split('T')[0];
        _memoryManager.unregisterActiveImage(previousDateKey);
      }

      // Reset index when date changes
      notifierIndex.value = 0;
      _currentDate = date;

      // Register new date as active
      final dateKey = date.toIso8601String().split('T')[0];
      _memoryManager.registerActiveImage(dateKey);

      // Safely add the date to the bloc
      if (historyBloc != null) {
        historyBloc!.selectDate.add(date);
      }
    } catch (e) {
      debugPrint('Error in _onDateSelected: $e');
      // Show error to user if something goes wrong
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading images for selected date'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () {
                // Retry the operation
                if (historyBloc != null) {
                  historyBloc!.selectDate.add(date);
                }
              },
            ),
          ),
        );
      }
    }
  }

  void _showImageInfo(BuildContext context, ImageItem image) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  image.description,
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16.0),
                Html(
                  data: image.copyright,
                  style: {
                    "body": Style(
                      fontSize: FontSize(15.0),
                      margin: Margins.zero,
                      padding: HtmlPaddings.zero,
                    ),
                    "a": Style(
                      color: Colors.blue,
                      textDecoration: TextDecoration.underline,
                    ),
                  },
                  onLinkTap: (url, attributes, element) async {
                    if (url != null) {
                      await _launchUrl(url);
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(
        uri,
        mode: LaunchMode.inAppBrowserView,
        browserConfiguration: const BrowserConfiguration(
          showTitle: true,
        ),
      );
    } else {
      // Fallback to external browser if in-app browser fails
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateOnly = DateTime(date.year, date.month, date.day);
    return dateOnly == today;
  }

  String _formatSelectedDate(DateTime date) {
    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final dateOnly = DateTime(date.year, date.month, date.day);

      if (dateOnly == today) {
        return 'today';
      } else if (dateOnly == yesterday) {
        return 'yesterday';
      } else {
        // Use a more readable format
        final months = [
          'January',
          'February',
          'March',
          'April',
          'May',
          'June',
          'July',
          'August',
          'September',
          'October',
          'November',
          'December'
        ];

        // Ensure month index is valid
        final monthIndex = date.month - 1;
        if (monthIndex >= 0 && monthIndex < months.length) {
          return '${months[monthIndex]} ${date.day}, ${date.year}';
        } else {
          // Fallback to ISO format if month is invalid
          return date.toIso8601String().split('T')[0];
        }
      }
    } catch (e) {
      debugPrint('Error formatting date $date: $e');
      // Fallback to a safe format
      return date.toIso8601String().split('T')[0];
    }
  }

  String _getErrorMessage(
      String originalError, bool isDatabaseError, bool isNetworkError) {
    if (isDatabaseError) {
      return 'There was a problem accessing the image database. This might be a temporary issue.';
    } else if (isNetworkError) {
      return 'Unable to connect to the server. Please check your internet connection and try again.';
    } else {
      // For other errors, show a user-friendly version but keep some detail
      if (originalError.length > 100) {
        return 'An unexpected error occurred while loading images. Please try again.';
      }
      return originalError;
    }
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
            SizedBox(height: 16),
            Text(
              'No images available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              isToday
                  ? 'No wallpapers have been downloaded yet today.\nCheck back later or visit the Home page to download today\'s images.'
                  : 'No wallpapers were saved for $formattedDate.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[500],
              ),
            ),
            if (state.availableDates.isNotEmpty) ...[
              SizedBox(height: 24),
              if (isToday) ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: Icon(Icons.home),
                  label: Text('Go to Home'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
                SizedBox(height: 12),
              ],
              ElevatedButton.icon(
                onPressed: () {
                  // Navigate to the most recent available date
                  final mostRecentDate = state.availableDates.reduce(
                    (a, b) => a.isAfter(b) ? a : b,
                  );
                  _onDateSelected(mostRecentDate);
                },
                icon: Icon(Icons.calendar_today),
                label: Text('View Recent Images'),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ] else ...[
              SizedBox(height: 24),
              Text(
                'No historical images found in the database.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[400],
                  fontStyle: FontStyle.italic,
                ),
              ),
              if (isToday) ...[
                SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: Icon(Icons.home),
                  label: Text('Go to Home'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String error) {
    final isDatabaseError = error.toLowerCase().contains('database') ||
        error.toLowerCase().contains('sql');
    final isNetworkError = error.toLowerCase().contains('network') ||
        error.toLowerCase().contains('connection');

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
            SizedBox(height: 16),
            Text(
              isDatabaseError
                  ? 'Database Error'
                  : isNetworkError
                      ? 'Connection Error'
                      : 'Error',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: Colors.red[600],
              ),
            ),
            SizedBox(height: 8),
            Text(
              _getErrorMessage(error, isDatabaseError, isNetworkError),
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
              ),
            ),
            SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // Retry by reloading current date
                    final currentState = historyBloc!.currentState;
                    if (currentState != null) {
                      _onDateSelected(currentState.selectedDate);
                    }
                  },
                  icon: Icon(Icons.refresh),
                  label: Text('Retry'),
                  style: ElevatedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pushNamed(context, '/');
                  },
                  icon: Icon(Icons.home),
                  label: Text('Home'),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: StreamBuilder<HistoryState>(
            stream: historyBloc!.results,
            builder: (context, snapshot) {
              final state = snapshot.data ?? HistoryState.initial();

              return AppBar(
                title: DateSelector(
                  selectedDate: state.selectedDate,
                  availableDates: state.availableDates,
                  onDateSelected: _onDateSelected,
                  isLoading: state.isLoading,
                ),
                backgroundColor: Colors.transparent,
                elevation: 0.0,
                iconTheme: IconThemeData(
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      offset: Offset(1.0, 1.0),
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
                              offset: Offset(1.0, 1.0),
                              blurRadius: 3.0,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                        onPressed: () {
                          if (state.images.isNotEmpty) {
                            // Ensure index is within bounds
                            int safeIndex = notifierIndex.value;
                            if (safeIndex >= state.images.length) {
                              safeIndex = state.images.length - 1;
                            }
                            _showImageInfo(context, state.images[safeIndex]);
                          }
                        },
                      );
                    },
                  ),
                  PopupMenuButton<String>(
                    onSelected: (choice) {
                      Navigator.pushNamed(context, choice);
                    },
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white,
                      shadows: [
                        Shadow(
                          offset: Offset(1.0, 1.0),
                          blurRadius: 3.0,
                          color: Colors.black.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                    itemBuilder: (BuildContext context) =>
                        <PopupMenuItem<String>>[
                      PopupMenuItem<String>(
                        value: '/settings',
                        child: Row(
                          children: [
                            Icon(Icons.settings, size: 20),
                            SizedBox(width: 8),
                            Text('Settings'),
                          ],
                        ),
                      ),
                      PopupMenuItem<String>(
                        value: '/',
                        child: Row(
                          children: [
                            Icon(Icons.home, size: 20),
                            SizedBox(width: 8),
                            Text('Home'),
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
            return StreamBuilder<HistoryState>(
              stream: historyBloc!.results,
              builder: (context, snapshot) {
                final state = snapshot.data ?? HistoryState.initial();

                // Only show FAB if there are images
                if (state.images.isEmpty) {
                  return SizedBox.shrink();
                }

                return WallpaperButton(
                  onPressed: () =>
                      historyBloc!.setWallpaper.add(notifierIndex.value),
                  wallpaperStream: historyBloc!.wallpaper,
                );
              },
            );
          },
        ),
        body: StreamBuilder<HistoryState>(
          stream: historyBloc!.results,
          builder: (context, snapshot) {
            final state = snapshot.data ?? HistoryState.initial();

            if (state.isLoading) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 16),
                    Text(
                      'Loading images for ${_formatSelectedDate(state.selectedDate)}...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              );
            }

            if (state.error != null) {
              return _buildErrorState(state.error!);
            }

            if (state.images.isEmpty) {
              return _buildEmptyState(state);
            }

            // Check if current index is out of bounds and adjust if needed
            if (notifierIndex.value >= state.images.length) {
              // Schedule index correction after build
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  notifierIndex.value = state.images.length - 1;
                }
              });
            }

            return Carousel(
              list: state.images,
              onChange: _onChange,
            );
          },
        ),
      ),
    );
  }
}
