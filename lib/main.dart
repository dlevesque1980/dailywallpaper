import 'package:dailywallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/bloc_provider/settings_provider.dart';
import 'package:dailywallpaper/screen/home_screen.dart';
import 'package:dailywallpaper/bloc_provider/home_provider.dart';
import 'package:dailywallpaper/screen/older_screen.dart';
import 'package:dailywallpaper/screen/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI overlay style globally - transparent pour voir le wallpaper
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color.fromRGBO(0, 0, 0, 0.8),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color.fromRGBO(0, 0, 0, 0.8),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Optionnel: Mode plein écran pour une expérience immersive maximale
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await dotenv.load(fileName: ".env");
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  Widget homeProvider() {
    return HomeProvider(homeBloc: HomeBloc(), child: HomeScreen());
  }

  Widget settingsProvider() {
    return SettingsProvider(
      settingsBloc: SettingsBloc(),
      pexelsCategoriesBloc: PexelsCategoriesBloc(),
      child: SettingScreen(),
    );
  }

  @override
  Widget build(BuildContext context) {
    WidgetsFlutterBinding.ensureInitialized();

    return MaterialApp(
      initialRoute: '/',
      routes: {
        // When we navigate to the "/" route, build the FirstScreen Widget
        '/': (context) => homeProvider(),
        // When we navigate to the "/second" route, build the SecondScreen Widget
        '/settings': (context) => settingsProvider(),
        //'/older': (context) => OlderScreen()
      },
      title: 'Daily Wallpaper',
      theme: ThemeData(),
    );
  }
}
