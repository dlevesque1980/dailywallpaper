import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/widgets/date_picker_dialog.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    // initializeDateFormatting is needed because DateFormat uses formatting
    await initializeDateFormatting('en', null);
  });

  testWidgets('DatePickerDialogCustom renders correctly with selected date',
      (WidgetTester tester) async {
    final selectedDate = DateTime(2026, 5, 15);
    final availableDates = [
      DateTime(2026, 5, 10),
      DateTime(2026, 5, 15),
      DateTime(2026, 5, 20),
    ];
    DateTime? selectedResult;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePickerDialogCustom(
            selectedDate: selectedDate,
            availableDates: availableDates,
            onDateSelected: (date) {
              selectedResult = date;
            },
          ),
        ),
      ),
    );

    // Verify dialog layout renders
    expect(find.byType(DatePickerDialogCustom), findsOneWidget);
    expect(find.text('May 2026'), findsOneWidget); // Header text for month
    expect(find.text('Sun'), findsOneWidget); // Weekday header

    // Check cells
    // Day 15 should be visible
    expect(find.text('15'), findsOneWidget);

    // Tap on available date 10
    await tester.tap(find.text('10'));
    await tester.pump();

    // Verify callback was triggered
    expect(selectedResult, isNotNull);
    expect(selectedResult!.day, equals(10));
  });

  testWidgets('DatePickerDialogCustom month navigation chevron buttons work',
      (WidgetTester tester) async {
    final selectedDate = DateTime(2026, 5, 15);
    // Two months of available dates
    final availableDates = [
      DateTime(2026, 4, 10),
      DateTime(2026, 5, 15),
      DateTime(2026, 6, 20),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: DatePickerDialogCustom(
            selectedDate: selectedDate,
            availableDates: availableDates,
            onDateSelected: (_) {},
          ),
        ),
      ),
    );

    // Verify initial month
    expect(find.text('May 2026'), findsOneWidget);

    // Tap chevron_left to navigate to April
    await tester.tap(find.byIcon(Icons.chevron_left));
    await tester.pumpAndSettle();
    expect(find.text('April 2026'), findsOneWidget);

    // Tap chevron_right to navigate back to May
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('May 2026'), findsOneWidget);

    // Tap chevron_right to navigate to June
    await tester.tap(find.byIcon(Icons.chevron_right));
    await tester.pumpAndSettle();
    expect(find.text('June 2026'), findsOneWidget);
  });

  testWidgets('DatePickerDialogCustom Cancel button closes the dialog',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => DatePickerDialogCustom(
                      selectedDate: DateTime(2026, 5, 15),
                      availableDates: [DateTime(2026, 5, 15)],
                      onDateSelected: (_) {},
                    ),
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog is open
    expect(find.byType(DatePickerDialogCustom), findsOneWidget);

    // Click Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify dialog is closed
    expect(find.byType(DatePickerDialogCustom), findsNothing);
  });
}
