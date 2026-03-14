import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/bloc/history_bloc.dart';
import 'package:dailywallpaper/bloc_provider/history_provider.dart';

void main() {
  group('HistoryProvider', () {
    late HistoryBloc historyBloc;

    setUp(() {
      historyBloc = HistoryBloc();
    });

    tearDown(() {
      historyBloc.dispose();
    });

    testWidgets('should provide HistoryBloc to child widgets',
        (WidgetTester tester) async {
      HistoryBloc? retrievedBloc;

      await tester.pumpWidget(
        HistoryProvider(
          historyBloc: historyBloc,
          child: Builder(
            builder: (context) {
              retrievedBloc = HistoryProvider.of(context);
              return Container();
            },
          ),
        ),
      );

      expect(retrievedBloc, equals(historyBloc));
    });

    testWidgets('should update when updateShouldNotify returns true',
        (WidgetTester tester) async {
      final firstBloc = HistoryBloc();
      final secondBloc = HistoryBloc();

      await tester.pumpWidget(
        HistoryProvider(
          historyBloc: firstBloc,
          child: Container(),
        ),
      );

      // Update with a new bloc
      await tester.pumpWidget(
        HistoryProvider(
          historyBloc: secondBloc,
          child: Container(),
        ),
      );

      // Should not throw any errors and should update
      expect(tester.takeException(), isNull);

      // Clean up
      firstBloc.dispose();
      secondBloc.dispose();
    });

    testWidgets('should throw when HistoryProvider is not found in context',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        Builder(
          builder: (context) {
            expect(
              () => HistoryProvider.of(context),
              throwsA(isA<TypeError>()),
            );
            return Container();
          },
        ),
      );
    });

    testWidgets(
        'should provide the same bloc instance to multiple child widgets',
        (WidgetTester tester) async {
      HistoryBloc? firstRetrievedBloc;
      HistoryBloc? secondRetrievedBloc;

      await tester.pumpWidget(
        HistoryProvider(
          historyBloc: historyBloc,
          child: Column(
            children: [
              Builder(
                builder: (context) {
                  firstRetrievedBloc = HistoryProvider.of(context);
                  return Container();
                },
              ),
              Builder(
                builder: (context) {
                  secondRetrievedBloc = HistoryProvider.of(context);
                  return Container();
                },
              ),
            ],
          ),
        ),
      );

      expect(firstRetrievedBloc, equals(historyBloc));
      expect(secondRetrievedBloc, equals(historyBloc));
      expect(firstRetrievedBloc, equals(secondRetrievedBloc));
    });

    testWidgets('should properly handle nested providers',
        (WidgetTester tester) async {
      final outerBloc = HistoryBloc();
      final innerBloc = HistoryBloc();
      HistoryBloc? retrievedBloc;

      await tester.pumpWidget(
        HistoryProvider(
          historyBloc: outerBloc,
          child: HistoryProvider(
            historyBloc: innerBloc,
            child: Builder(
              builder: (context) {
                retrievedBloc = HistoryProvider.of(context);
                return Container();
              },
            ),
          ),
        ),
      );

      // Should get the inner (closest) provider's bloc
      expect(retrievedBloc, equals(innerBloc));
      expect(retrievedBloc, isNot(equals(outerBloc)));

      // Clean up
      outerBloc.dispose();
      innerBloc.dispose();
    });

    test('should have correct properties', () {
      final provider = HistoryProvider(
        historyBloc: historyBloc,
        child: Container(),
      );

      expect(provider.historyBloc, equals(historyBloc));
      expect(provider.child, isA<Container>());
    });

    test('updateShouldNotify should always return true', () {
      final provider = HistoryProvider(
        historyBloc: historyBloc,
        child: Container(),
      );

      final oldProvider = HistoryProvider(
        historyBloc: HistoryBloc(),
        child: Container(),
      );

      expect(provider.updateShouldNotify(oldProvider), isTrue);

      // Clean up
      oldProvider.historyBloc.dispose();
    });
  });
}
