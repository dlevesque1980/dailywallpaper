import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_provider.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/widgets/carousel.dart';
import 'package:dailywallpaper/widgets/wallpaper_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

class HomeScreen extends StatefulWidget {
  HomeScreen() : super(key: const Key('__homeScreen__'));
  @override
  _HomeScreenState createState() => new _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  ValueNotifier<int> notifierIndex = new ValueNotifier(0);
  HomeBloc? homeBloc;
  Stream<String>? wallpaperMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    if (homeBloc == null) {
      homeBloc = HomeProvider.of(context);
    }
    super.didChangeDependencies();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    homeBloc?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Handle app lifecycle changes if needed
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
        // Notifier le HomeBloc du changement d'index pour le préchargement
        homeBloc?.onIndexChanged(index);
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

  void _showCropInfo(BuildContext context, ImageItem image) {
    final result = image.smartCropResult;
    if (result == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Analysis in progress...')),
      );
      return;
    }

    final crop = result.bestCrop;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_awesome, color: Colors.blue),
            SizedBox(width: 8),
            Text('Crop Analysis'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Strategy', crop.strategy),
            _infoRow('Confidence', '${(crop.confidence * 100).toStringAsFixed(1)}%'),
            _infoRow('Target Aspect', (crop.width / crop.height).toStringAsFixed(2)),
            Divider(),
            Text('Coordinates (Normalized)', style: TextStyle(fontWeight: FontWeight.bold)),
            _infoRow('X / Y', '${crop.x.toStringAsFixed(3)} / ${crop.y.toStringAsFixed(3)}'),
            _infoRow('W / H', '${crop.width.toStringAsFixed(3)} / ${crop.height.toStringAsFixed(3)}'),
            if (crop.subjectBounds != null) ...[
               Divider(),
               Text('Subject Detection', style: TextStyle(fontWeight: FontWeight.bold)),
               _infoRow('Bounds', '${crop.subjectBounds!.width.toStringAsFixed(2)}x${crop.subjectBounds!.height.toStringAsFixed(2)}'),
            ]
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('CLOSE'),
          ),
        ],
      ),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: Colors.grey[600])),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
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
              preferredSize: Size.fromHeight(kToolbarHeight),
              child: ValueListenableBuilder(
                valueListenable: notifierIndex,
                builder: (context, value, child) {
                  return StreamBuilder(
                    stream: homeBloc!.results,
                    builder: (context, snapshot) {
                      String title = "Daily Wallpaper";
                      if (snapshot.hasData && snapshot.data!.list.isNotEmpty) {
                        // Ensure index is within bounds
                        int safeIndex = notifierIndex.value;
                        if (safeIndex >= snapshot.data!.list.length) {
                          safeIndex = snapshot.data!.list.length - 1;
                        }
                        title = snapshot.data!.list[safeIndex].source;
                      }

                      return AppBar(
                        title: Text(
                          title,
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w500,
                            shadows: [
                              Shadow(
                                offset: Offset(1.0, 1.0),
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
                                  offset: Offset(1.0, 1.0),
                                  blurRadius: 3.0,
                                  color: Colors.black.withValues(alpha: 0.5),
                                ),
                              ],
                            ),
                            onPressed: () {
                              if (snapshot.hasData &&
                                  snapshot.data!.list.isNotEmpty) {
                                // Ensure index is within bounds
                                int safeIndex = notifierIndex.value;
                                if (safeIndex >= snapshot.data!.list.length) {
                                  safeIndex = snapshot.data!.list.length - 1;
                                }
                                _showImageInfo(
                                    context, snapshot.data!.list[safeIndex]);
                              }
                            },
                          ),
                          PopupMenuButton<String>(
                            onSelected: (choice) {
                              if (choice == '/settings') {
                                // Navigate to settings with callback when returning
                                Navigator.pushNamed(context, choice).then((_) {
                                  // This will be called when returning from settings (including swipe back)
                                  print(
                                      'Returned from settings, refreshing...');
                                  homeBloc?.refresh();
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
                                value: '/older',
                                child: Row(
                                  children: [
                                    Icon(Icons.history, size: 20),
                                    SizedBox(width: 8),
                                    Text('History'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            floatingActionButton: ValueListenableBuilder(
                valueListenable: notifierIndex,
                builder: (context, value, child) {
                  return WallpaperButton(
                    onPressed: () =>
                        homeBloc!.setWallpaper.add(notifierIndex.value),
                    wallpaperStream: homeBloc!.wallpaper,
                  );
                }),
            body: StreamBuilder(
                stream: homeBloc!.results,
                initialData: homeBloc!.initialData(notifierIndex.value),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!.list.isNotEmpty) {
                    // Check if current index is out of bounds and adjust if needed
                    if (notifierIndex.value >= snapshot.data!.list.length) {
                      // Schedule index correction after build
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        if (mounted) {
                          notifierIndex.value = snapshot.data!.list.length - 1;
                        }
                      });
                    }

                    return Stack(
                      children: [
                        Carousel(
                          list: snapshot.data!.list,
                          onChange: this._onChange,
                        ),
                        // Analysis Info Button (Crop Info)
                        Positioned(
                          bottom: 24,
                          left: 24,
                          child: FloatingActionButton.small(
                            heroTag: 'crop_info',
                            backgroundColor: Colors.black.withValues(alpha: 0.4),
                            elevation: 0,
                            child: Icon(Icons.center_focus_strong, color: Colors.white70),
                            onPressed: () {
                              int safeIndex = notifierIndex.value;
                              if (safeIndex < snapshot.data!.list.length) {
                                _showCropInfo(context, snapshot.data!.list[safeIndex]);
                              }
                            },
                          ),
                        ),
                      ],
                    );
                  } else {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Optimizing wallpapers...',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                              letterSpacing: 1.2,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Analyzing for the best crop',
                            style: TextStyle(
                              color: Colors.white38,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    );
                  }
                })));
  }
}
