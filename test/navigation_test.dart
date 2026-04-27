import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/main.dart';

void main() {
  group('Routing Configuration Tests', () {
    testWidgets('Should have correct route configuration',
        (WidgetTester tester) async {
      final app = MyApp();

      // Build the app
      await tester.pumpWidget(app);

      // Verify the app builds without errors
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Should have History menu item available',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(MyApp());

      // Wait for initial load
      await tester.pump();

      // Find and tap the menu button
      final menuButton = find.byIcon(Icons.more_vert);
      expect(menuButton, findsOneWidget);
      await tester.tap(menuButton);
      await tester.pump();

      // Verify History menu item is present
      final historyMenuItem = find.text('History');
      expect(historyMenuItem, findsOneWidget);

      // Verify Settings menu item is also present
      final settingsMenuItem = find.text('Settings');
      expect(settingsMenuItem, findsOneWidget);
    });

    testWidgets('Should be able to navigate to /older route',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(MyApp());

      // Navigate programmatically to the /older route
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed('/older');
      await tester.pump();

      // Verify navigation succeeded (no exceptions thrown)
      expect(find.byType(MaterialApp), findsOneWidget);
    });

    testWidgets('Should be able to navigate to /settings route',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(MyApp());

      // Navigate programmatically to the /settings route
      final NavigatorState navigator = tester.state(find.byType(Navigator));
      navigator.pushNamed('/settings');
      await tester.pump();

      // Verify navigation succeeded (no exceptions thrown)
      expect(find.byType(MaterialApp), findsOneWidget);
    });
  });
}
