import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/features/history/screens/widgets/history_app_bar.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';
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
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        appBar: PreferredSize(
          preferredSize: const Size.fromHeight(kToolbarHeight),
          child: BlocProvider<HistoryBloc>.value(
            value: mockHistoryBloc,
            child: HistoryAppBar(
              notifierIndex: notifierIndex,
              onDateSelected: (_) {},
              onShowImageInfo: (_, __) {},
              onShowCropInfo: (_, __) {},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('HistoryAppBar shows DateSelector with loading state', (WidgetTester tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(createWidgetUnderTest(HistoryState.loading(selectedDate: now, availableDates: [now])));
    await tester.pump();

    expect(find.byType(AppBar), findsOneWidget);
    // Info and menu buttons should be visible
    expect(find.byIcon(Icons.info_outline), findsOneWidget);
    expect(find.byIcon(Icons.more_vert), findsOneWidget);
  });

  testWidgets('HistoryAppBar popup menu has specific items', (WidgetTester tester) async {
    final now = DateTime.now();
    await tester.pumpWidget(createWidgetUnderTest(HistoryState.loaded(
      images: [],
      selectedDate: now,
      availableDates: [now],
    )));
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.more_vert));
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.center_focus_strong), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
  });
}
