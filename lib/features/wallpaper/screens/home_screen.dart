import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/widgets/carousel.dart';
import 'package:dailywallpaper/widgets/wallpaper_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';
import 'package:dailywallpaper/widgets/crop_info_dialog.dart';
import 'package:dailywallpaper/widgets/image_info_sheet.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  final ValueNotifier<int> _currentIndex = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    _currentIndex.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onChange(int index, bool refresh) {
    if (_currentIndex.value != index) {
      _currentIndex.value = index;
    }
    if (refresh) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      context.read<HomeBloc>().add(HomeEvent.indexChanged(index));
    }
  }

  void _showImageInfo(BuildContext context, ImageItem image) {
    showModalBottomSheet<void>(
      context: context,
      builder: (BuildContext context) => ImageInfoBottomSheet(image: image),
    );
  }

  void _showCropInfo(BuildContext context, ImageItem image) {
    showDialog(
      context: context,
      builder: (context) => CropInfoDialog(image: image),
    );
  }

  String _translateMessage(BuildContext context, String message) {
    final l10n = AppLocalizations.of(context)!;
    if (message == 'wallpaperSetSuccess') return l10n.wallpaperSetSuccess;
    if (message.startsWith('failedToSetWallpaper')) {
      final detail = message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return '${l10n.failedToSetWallpaper}$detail';
    }
    if (message.startsWith('failedToFetchWallpapers')) {
      final detail = message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return '${l10n.failedToFetchWallpapers}$detail';
    }
    if (message.startsWith('failedToRefreshWallpapers')) {
      final detail = message.contains(':') ? message.substring(message.indexOf(':')) : '';
      return '${l10n.failedToRefreshWallpapers}$detail';
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
            backgroundColor: Colors.black,
            extendBodyBehindAppBar: true,
            appBar: PreferredSize(
              preferredSize: const Size.fromHeight(kToolbarHeight),
              child: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  String title = AppLocalizations.of(context)!.appTitle;
                  state.mapOrNull(loaded: (loadedState) {
                    if (loadedState.list.isNotEmpty) {
                      title = loadedState.list[loadedState.imageIndex].source;
                    }
                  });

                  return AppBar(
                    title: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                        shadows: [
                          Shadow(
                            offset: const Offset(1.0, 1.0),
                            blurRadius: 3.0,
                            color: Colors.black.withValues(alpha: 0.5),
                          ),
                        ],
                      ),
                    ),
                    backgroundColor: Colors.transparent,
                    elevation: 0.0,
                    actions: [
                      IconButton(
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
                            if (loadedState.list.isNotEmpty) {
                              _showImageInfo(context, loadedState.list[_currentIndex.value]);
                            }
                          });
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (choice) {
                          if (choice == '/settings') {
                            Navigator.pushNamed(context, choice).then((_) {
                              context.read<HomeBloc>().add(const HomeEvent.refreshRequested());
                            });
                          } else if (choice == 'crop_info') {
                            state.mapOrNull(loaded: (loadedState) {
                              if (loadedState.list.isNotEmpty) {
                                _showCropInfo(context, loadedState.list[_currentIndex.value]);
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
                        itemBuilder: (BuildContext context) =>
                            <PopupMenuItem<String>>[
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
                            value: '/older',
                            child: Row(
                              children: [
                                const Icon(Icons.history, size: 20),
                                const SizedBox(width: 8),
                                Text(AppLocalizations.of(context)!.history),
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
            floatingActionButton: BlocConsumer<HomeBloc, HomeState>(
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
                bool isSetting = false;
                bool isSuccess = false;

                state.mapOrNull(loaded: (loadedState) {
                  isSetting = loadedState.isSettingWallpaper;
                  isSuccess = loadedState.wallpaperMessage != null && 
                             (loadedState.wallpaperMessage == 'wallpaperSetSuccess');
                });

                return WallpaperButton(
                  onPressed: () {
                    context.read<HomeBloc>().add(const HomeEvent.wallpaperUpdateRequested());
                  },
                  isSettingWallpaper: isSetting,
                  isSuccess: isSuccess,
                );
              },
            ),
            body: BlocBuilder<HomeBloc, HomeState>(
                builder: (context, state) {
                  return state.map(
                    initial: (_) => _buildLoadingState(),
                    loading: (_) => _buildLoadingState(),
                    loaded: (loadedState) {
                      if (loadedState.list.isNotEmpty) {
                        return Carousel(
                          list: loadedState.list,
                          onChange: _onChange,
                        );
                      } else {
                        return Center(child: Text(AppLocalizations.of(context)!.noWallpapersFound, style: const TextStyle(color: Colors.white)));
                      }
                    },
                    error: (errorState) => Center(
                      child: Text(_translateMessage(context, errorState.message), style: const TextStyle(color: Colors.red)),
                    ),
                  );
                })));
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            AppLocalizations.of(context)!.optimizingWallpapers,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 16,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            AppLocalizations.of(context)!.analyzingForCrop,
            style: const TextStyle(
              color: Colors.white38,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
