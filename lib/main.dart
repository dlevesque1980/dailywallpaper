import 'package:dailywallpaper/bloc/categories_bloc.dart';
import 'package:dailywallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc_provider/settings_provider.dart';
import 'package:dailywallpaper/screen/home_screen.dart';
import 'package:dailywallpaper/bloc_provider/home_provider.dart';
import 'package:dailywallpaper/screen/older_screen.dart';
import 'package:dailywallpaper/screen/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

  void main() async {
    await dotenv.load(fileName: ".env"); // Or load dynamically
    runApp(MyApp());
  }

class MyApp extends StatelessWidget {

  Widget homeProvider() {
    return HomeProvider(homeBloc: HomeBloc(), child: HomeScreen());
  }

  Widget settingsProvider() {
    return SettingsProvider(settingsBloc: SettingsBloc(), categoriesBloc: CategoriesBloc(), child: SettingScreen());
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
        '/older': (context) => OlderScreen()
      },
      title: 'Daily Wallpaper',
      theme: ThemeData(),
    );
  }
  
}
