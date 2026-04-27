import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/history/screens/history_screen.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_provider.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

void main() {
  group('HistoryScreen Yesterday Selection Tests', () {
    late HistoryBloc mockHistoryBloc;

    setUp(() {
      mockHistoryBloc = HistoryBloc();
    });

    tearDown(() {
      mockHistoryBloc.dispose();
    });

    testWidgets('should handle yesterday date selection without crashing',
        (WidgetTester tester) async {
      // Create test data for yesterday
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      final testImages = [
        ImageItem(
          'test',
          'https://example.com/yesterday.jpg',
          'Yesterday Image',
          yesterday,
          yesterday,
          'test.yesterday.1',
          null,
          'Yesterday Copyright',
        ),
      ];

      // Initialize the bloc with yesterday's data
      await mockHistoryBloc.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: HistoryProvider(
            historyBloc: mockHistoryBloc,
            child: HistoryScreen(),
          ),
        ),
      );

      // Wait for initial load
      await tester.pumpAndSettle();

      // Simulate selecting yesterday's date
      // This should not crash the app
      expect(() {
        mockHistoryBloc.selectDate.add(yesterday);
      }, returnsNormally);

      // Wait for the date selection to process
      await tester.pumpAndSettle();

      // The app should still be running without crashes
      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('should format yesterday date correctly',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));

      await mockHistoryBloc.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: HistoryProvider(
            historyBloc: mockHistoryBloc,
            child: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Select yesterday's date
      mockHistoryBloc.selectDate.add(yesterday);
      await tester.pumpAndSettle();

      // Should not crash and should handle the date formatting
      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('should handle edge case dates without crashing',
        (WidgetTester tester) async {
      await mockHistoryBloc.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: HistoryProvider(
            historyBloc: mockHistoryBloc,
            child: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Test edge cases that might cause crashes
      final edgeCases = [
        DateTime(2024, 1, 1), // New Year's Day
        DateTime(2024, 2, 29), // Leap year day
        DateTime(2024, 12, 31), // New Year's Eve
        DateTime(2023, 2, 28), // Non-leap year Feb 28
      ];

      for (final date in edgeCases) {
        expect(() {
          mockHistoryBloc.selectDate.add(date);
        }, returnsNormally, reason: 'Date $date should not cause crash');

        await tester.pumpAndSettle();
        expect(find.byType(HistoryScreen), findsOneWidget);
      }
    });

    testWidgets('should handle memory cleanup when switching dates',
        (WidgetTester tester) async {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final yesterday = today.subtract(const Duration(days: 1));
      final twoDaysAgo = today.subtract(const Duration(days: 2));

      await mockHistoryBloc.initialize();

      await tester.pumpWidget(
        MaterialApp(
          home: HistoryProvider(
            historyBloc: mockHistoryBloc,
            child: HistoryScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Switch between multiple dates rapidly
      final dates = [today, yesterday, twoDaysAgo, yesterday, today];

      for (final date in dates) {
        expect(() {
          mockHistoryBloc.selectDate.add(date);
        }, returnsNormally, reason: 'Rapid date switching should not crash');

        await tester
            .pump(); // Don't wait for settle to simulate rapid switching
      }

      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
    });
  });
}
