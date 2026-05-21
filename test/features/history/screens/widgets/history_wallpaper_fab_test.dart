import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/history/screens/widgets/history_wallpaper_fab.dart';
import 'package:dailywallpaper/widgets/wallpaper_button.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

class MockHistoryBloc extends Mock implements HistoryBloc {}

void main() {
  late MockHistoryBloc mockHistoryBloc;
  late ValueNotifier<int> notifierIndex;

  setUp(() {
    mockHistoryBloc = MockHistoryBloc();
    notifierIndex = ValueNotifier<int>(0);
    when(() => mockHistoryBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  Widget createWidgetUnderTest(HistoryState state) {
    when(() => mockHistoryBloc.state).thenReturn(state);
    return MaterialApp(
      home: Scaffold(
        body: BlocProvider<HistoryBloc>.value(
          value: mockHistoryBloc,
          child: HistoryWallpaperFab(
            notifierIndex: notifierIndex,
            translateMessage: (_, msg) => msg,
          ),
        ),
      ),
    );
  }

  testWidgets('HistoryWallpaperFab is empty when no images',
      (WidgetTester tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(createWidgetUnderTest(HistoryState.loaded(
      images: [],
      selectedDate: now,
      availableDates: [now],
    )));
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperButton), findsNothing);
  });

  testWidgets('HistoryWallpaperFab shows WallpaperButton when images exist',
      (WidgetTester tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(createWidgetUnderTest(HistoryState.loaded(
      images: [
        ImageItem(
          'test', // source
          'test', // url
          'test', // description
          now, // startTime
          now, // endTime
          '1', // imageIdent
          'test', // triggerUrl
          'test', // copyright
        )
      ],
      selectedDate: now,
      availableDates: [now],
    )));
    await tester.pumpAndSettle();

    expect(find.byType(WallpaperButton), findsOneWidget);
  });

  testWidgets(
      'HistoryWallpaperFab triggers wallpaper update event when pressed',
      (WidgetTester tester) async {
    final now = DateTime.now();
    when(() => mockHistoryBloc.state).thenReturn(HistoryState.loaded(
      images: [
        ImageItem(
          'test', // source
          'test', // url
          'test', // description
          now, // startTime
          now, // endTime
          '1', // imageIdent
          'test', // triggerUrl
          'test', // copyright
        )
      ],
      selectedDate: now,
      availableDates: [now],
    ));

    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: BlocProvider<HistoryBloc>.value(
          value: mockHistoryBloc,
          child: HistoryWallpaperFab(
            notifierIndex: notifierIndex,
            translateMessage: (_, msg) => msg,
          ),
        ),
      ),
    ));

    await tester.pumpAndSettle();

    await tester.tap(find.byType(WallpaperButton));
    await tester.pumpAndSettle();

    verify(() =>
            mockHistoryBloc.add(const HistoryEvent.wallpaperUpdateRequested(0)))
        .called(1);
  });
}
