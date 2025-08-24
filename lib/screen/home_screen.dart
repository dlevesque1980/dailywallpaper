import 'package:dailywallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/bloc_provider/home_provider.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/widget/carousel.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

import '../widget/buttonstate.dart';

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
        notifierIndex.value = index; // Correction: mettre à jour notifierIndex avec le nouvel index
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
                        icon: Icon(Icons.info_outline, 
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
                          if (snapshot.hasData && snapshot.data!.list.isNotEmpty) {
                            // Ensure index is within bounds
                            int safeIndex = notifierIndex.value;
                            if (safeIndex >= snapshot.data!.list.length) {
                              safeIndex = snapshot.data!.list.length - 1;
                            }
                            _showImageInfo(context, snapshot.data!.list[safeIndex]);
                          }
                        },
                      ),
                      PopupMenuButton<String>(
                        onSelected: (choice) {
                          if (choice == '/settings') {
                            // Navigate to settings with callback when returning
                            Navigator.pushNamed(context, choice).then((_) {
                              // This will be called when returning from settings (including swipe back)
                              print('Returned from settings, refreshing...');
                              homeBloc?.refresh();
                            });
                          } else {
                            Navigator.pushNamed(context, choice);
                          }
                        },
                        icon: Icon(Icons.more_vert, 
                          color: Colors.white,
                          shadows: [
                            Shadow(
                              offset: Offset(1.0, 1.0),
                              blurRadius: 3.0,
                              color: Colors.black.withValues(alpha: 0.5),
                            ),
                          ],
                        ),
                        itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
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
              return ButtonStates(
                onPressed: () => homeBloc!.setWallpaper.add(notifierIndex.value),
                homeBloc: homeBloc!,
              );
              // return FloatingActionButton(
              //   elevation: 0.0,
              //   child: new Icon(Icons.wallpaper),
              //   backgroundColor: Colors.lightBlue,
              //   onPressed: () => homeBloc.setWallpaper.add(notifierIndex.value),
              // );
            }),
        body: StreamBuilder(
            stream: homeBloc!.results,
            initialData: homeBloc!.initialData(notifierIndex.value),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                // Check if current index is out of bounds and adjust if needed
                if (notifierIndex.value >= snapshot.data!.list.length) {
                  // Schedule index correction after build
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                      notifierIndex.value = snapshot.data!.list.length - 1;
                    }
                  });
                }
                
                return Carousel(
                  list: snapshot.data!.list,
                  onChange: this._onChange,
                );
              } else {
                return Center(child: CircularProgressIndicator());
              }
            })));
  }
}