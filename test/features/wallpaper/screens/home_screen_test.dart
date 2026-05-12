import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/screens/home_screen.dart';
import 'package:dailywallpaper/widgets/carousel.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

class MockHomeBloc extends MockBloc<HomeEvent, HomeState> implements HomeBloc {}

void main() {
  setUpAll(() {
    registerFallbackValue(const HomeEvent.started());
    registerFallbackValue(const HomeState.initial());
  });

  late MockHomeBloc mockHomeBloc;

  setUp(() {
    mockHomeBloc = MockHomeBloc();
  });

  final mockImage = ImageItem(
    "Source",
    "https://example.com/image.jpg",
    "Description",
    DateTime.now(),
    DateTime.now().add(const Duration(days: 1)),
    "image_ident",
    null,
    "Copyright",
  );

  Widget createWidgetUnderTest() {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<HomeBloc>.value(
        value: mockHomeBloc,
        child: const HomeScreen(),
      ),
    );
  }

  testWidgets('HomeScreen ignores PageView changes when isSettingWallpaper is true', (WidgetTester tester) async {
    // État où le fond d'écran est en train de s'appliquer
    when(() => mockHomeBloc.state).thenReturn(HomeState.loaded(
      list: [mockImage, mockImage], // 2 images pour permettre le changement de page
      imageIndex: 0,
      isSettingWallpaper: true, // IMPORTANT: c'est ce qu'on teste
    ));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(); // Use pump instead of pumpAndSettle because Carousel might have infinite animations (loading indicators)

    // Trouver le Carousel
    final carouselFinder = find.byType(Carousel);
    expect(carouselFinder, findsOneWidget);

    // Extraire le widget Carousel pour accéder à son callback onChange
    final Carousel carousel = tester.widget(carouselFinder);
    
    // Simuler le fait que le PageView change de page (e.g., causé par Material You)
    carousel.onChange?.call(1, false);

    // Vérifier que le BLoC n'a reçu AUCUN événement indexChanged
    verifyNever(() => mockHomeBloc.add(const HomeEvent.indexChanged(1)));
  });

  testWidgets('HomeScreen accepts PageView changes when isSettingWallpaper is false', (WidgetTester tester) async {
    // État normal
    when(() => mockHomeBloc.state).thenReturn(HomeState.loaded(
      list: [mockImage, mockImage],
      imageIndex: 0,
      isSettingWallpaper: false, // Normal state
    ));

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(); // Use pump instead of pumpAndSettle

    final carouselFinder = find.byType(Carousel);
    expect(carouselFinder, findsOneWidget);

    final Carousel carousel = tester.widget(carouselFinder);
    
    // Simuler un changement de page
    carousel.onChange?.call(1, false);

    // Vérifier que le BLoC A BIEN reçu l'événement
    verify(() => mockHomeBloc.add(const HomeEvent.indexChanged(1))).called(1);
  });
}
