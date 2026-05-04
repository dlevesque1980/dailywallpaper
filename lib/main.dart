import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_event.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_event.dart';
import 'package:dailywallpaper/features/wallpaper/screens/home_screen.dart';
import 'package:dailywallpaper/features/history/screens/history_screen.dart';
import 'package:dailywallpaper/features/settings/screens/simplified_settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'package:dailywallpaper/l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure system UI overlay style globally
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Color.fromRGBO(0, 0, 0, 0.8),
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Color.fromRGBO(0, 0, 0, 0.8),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Full screen mode for maximum immersive experience
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  await dotenv.load(fileName: ".env");
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<HomeBloc>(
          create: (context) => HomeBloc()..add(const HomeEvent.started()),
        ),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        initialRoute: '/',
        routes: {
          '/': (context) => const HomeScreen(),
          '/settings': (context) => MultiBlocProvider(
            providers: [
              BlocProvider<SettingsBloc>(
                create: (context) => SettingsBloc()..add(const SettingsEvent.started()),
              ),
              BlocProvider<PexelsCategoriesBloc>(
                create: (context) => PexelsCategoriesBloc()..add(const PexelsCategoriesEvent.started()),
              ),
            ],
            child: SimplifiedSettingsScreen(),
          ),
          '/older': (context) => BlocProvider<HistoryBloc>(
            create: (context) => HistoryBloc()..add(const HistoryEvent.started()),
            child: HistoryScreen(),
          ),
        },
        title: 'Daily Wallpaper',
        theme: ThemeData(),
      ),
    );
  }
}
