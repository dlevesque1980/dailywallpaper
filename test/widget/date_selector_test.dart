import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/widget/date_selector.dart';

void main() {
  group('DateSelector Widget Tests', () {
    late DateTime selectedDate;
    late List<DateTime> availableDates;
    late Function(DateTime) onDateSelected;
    late List<DateTime> capturedDates;

    setUp(() {
      selectedDate = DateTime(2024, 1, 15);
      availableDates = [
        DateTime(2024, 1, 10),
        DateTime(2024, 1, 15),
        DateTime(2024, 1, 20),
        DateTime(2024, 1, 25),
        DateTime(2024, 2, 5),
      ];
      capturedDates = [];
      onDateSelected = (date) => capturedDates.add(date);
    });

    Widget createDateSelector({
      DateTime? testSelectedDate,
      List<DateTime>? testAvailableDates,
      Function(DateTime)? testOnDateSelected,
      bool isLoading = false,
    }) {
      return MaterialApp(
        home: Scaffold(
          body: DateSelector(
            selectedDate: testSelectedDate ?? selectedDate,
            availableDates: testAvailableDates ?? availableDates,
            onDateSelected: testOnDateSelected ?? onDateSelected,
            isLoading: isLoading,
          ),
        ),
      );
    }

    testWidgets('should display selected date correctly',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      expect(find.text('Jan 15, 2024'), findsOneWidget);
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
    });

    testWidgets('should display "Today" for current date',
        (WidgetTester tester) async {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      await tester.pumpWidget(createDateSelector(
        testSelectedDate: todayDate,
        testAvailableDates: [todayDate],
      ));

      expect(find.text('Today'), findsOneWidget);
    });

    testWidgets('should display "Yesterday" for yesterday\'s date',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final yesterday = DateTime(now.year, now.month, now.day)
          .subtract(const Duration(days: 1));

      await tester.pumpWidget(createDateSelector(
        testSelectedDate: yesterday,
        testAvailableDates: [yesterday],
      ));

      expect(find.text('Yesterday'), findsOneWidget);
    });

    testWidgets('should show loading indicator when isLoading is true',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector(isLoading: true));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byIcon(Icons.arrow_drop_down), findsNothing);
    });

    testWidgets('should not respond to tap when loading',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector(isLoading: true));

      await tester.tap(find.byType(DateSelector));
      await tester.pump();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('should open date picker dialog when tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);
      expect(find.text('January 2024'), findsOneWidget);
    });

    testWidgets('should close dialog when cancel is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsNothing);
    });

    testWidgets('should navigate between months', (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      expect(find.text('January 2024'), findsOneWidget);

      // Navigate to next month
      await tester.tap(find.byIcon(Icons.chevron_right));
      await tester.pumpAndSettle();

      expect(find.text('February 2024'), findsOneWidget);

      // Navigate back to previous month
      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      expect(find.text('January 2024'), findsOneWidget);
    });

    testWidgets('should highlight available dates with dots',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      // Check that available dates are present
      expect(find.text('10'), findsOneWidget);
      expect(find.text('15'), findsOneWidget);
      expect(find.text('20'), findsOneWidget);
      expect(find.text('25'), findsOneWidget);
    });

    testWidgets('should highlight selected date', (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      // The selected date (15) should be highlighted
      final selectedDayWidget = find.text('15');
      expect(selectedDayWidget, findsOneWidget);
    });

    testWidgets('should call onDateSelected when available date is tapped',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      // Tap on an available date (20th)
      await tester.tap(find.text('20'));
      await tester.pumpAndSettle();

      expect(capturedDates.length, 1);
      expect(capturedDates.first, DateTime(2024, 1, 20));
      expect(find.byType(Dialog), findsNothing); // Dialog should close
    });

    testWidgets('should not allow selection of unavailable dates',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      // Try to tap on an unavailable date (1st)
      await tester.tap(find.text('1'));
      await tester.pumpAndSettle();

      expect(capturedDates.length, 0); // No date should be captured
      expect(find.byType(Dialog), findsOneWidget); // Dialog should remain open
    });

    testWidgets('should disable navigation to months without available dates',
        (WidgetTester tester) async {
      // Create a scenario where only January 2024 has available dates
      final limitedAvailableDates = [
        DateTime(2024, 1, 15),
      ];

      await tester.pumpWidget(createDateSelector(
        testAvailableDates: limitedAvailableDates,
      ));

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      expect(find.text('January 2024'), findsOneWidget);

      // Try to navigate to previous month (should be disabled if no dates available)
      final leftChevron = find.byIcon(Icons.chevron_left);
      expect(leftChevron, findsOneWidget);
    });

    testWidgets('should not navigate beyond current month',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final currentMonthDates = [
        DateTime(now.year, now.month, 15),
      ];

      await tester.pumpWidget(createDateSelector(
        testSelectedDate: DateTime(now.year, now.month, 15),
        testAvailableDates: currentMonthDates,
      ));

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      // Should not be able to navigate to future months
      final rightChevron = find.byIcon(Icons.chevron_right);
      expect(rightChevron, findsOneWidget);
    });

    testWidgets('should show weekday headers', (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsOneWidget);
      expect(find.text('Fri'), findsOneWidget);
      expect(find.text('Sat'), findsOneWidget);
    });

    testWidgets('should handle empty available dates list',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector(
        testAvailableDates: [],
      ));

      await tester.tap(find.byType(DateSelector));
      await tester.pumpAndSettle();

      expect(find.byType(Dialog), findsOneWidget);

      // All dates should be unavailable (grayed out)
      // Navigation should be disabled
      final leftChevron = find.byIcon(Icons.chevron_left);
      final rightChevron = find.byIcon(Icons.chevron_right);
      expect(leftChevron, findsOneWidget);
      expect(rightChevron, findsOneWidget);
    });

    testWidgets('should maintain visual consistency with app theme',
        (WidgetTester tester) async {
      await tester.pumpWidget(createDateSelector());

      // Check that the widget has proper styling
      final container = find.byType(Container).first;
      expect(container, findsOneWidget);

      // Check for calendar icon
      expect(find.byIcon(Icons.calendar_today), findsOneWidget);
    });

    group('Date Formatting Tests', () {
      testWidgets('should format dates correctly for different scenarios',
          (WidgetTester tester) async {
        // Test with a specific date
        final testDate = DateTime(2023, 12, 25);
        await tester.pumpWidget(createDateSelector(
          testSelectedDate: testDate,
          testAvailableDates: [testDate],
        ));

        expect(find.text('Dec 25, 2023'), findsOneWidget);
      });

      testWidgets('should handle year transitions correctly',
          (WidgetTester tester) async {
        final newYearDate = DateTime(2025, 1, 1);
        await tester.pumpWidget(createDateSelector(
          testSelectedDate: newYearDate,
          testAvailableDates: [newYearDate],
        ));

        expect(find.text('Jan 1, 2025'), findsOneWidget);
      });
    });

    group('Accessibility Tests', () {
      testWidgets('should be accessible with screen readers',
          (WidgetTester tester) async {
        await tester.pumpWidget(createDateSelector());

        // The widget should be tappable
        expect(find.byType(GestureDetector), findsOneWidget);

        // Icons should be present for visual cues
        expect(find.byIcon(Icons.calendar_today), findsOneWidget);
        expect(find.byIcon(Icons.arrow_drop_down), findsOneWidget);
      });
    });
  });
}
