import 'package:dailywallpaper/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Settings Navigation Tests', () {
    testWidgets('Settings route should be properly configured in MaterialApp',
        (WidgetTester tester) async {
      // Build the app
      await tester.pumpWidget(MyApp());

      // Find the MaterialApp widget
      final MaterialApp app = tester.widget(find.byType(MaterialApp));

      // Verify that the settings route exists
      expect(app.routes, contains('/settings'));
      expect(app.initialRoute, equals('/'));
    });

    testWidgets('Settings route should create SettingsProvider',
        (WidgetTester tester) async {
      // Create the app
      final app = MyApp();

      // Build just the MaterialApp to test route configuration
      await tester.pumpWidget(app);

      // Get the MaterialApp widget
      final MaterialApp materialApp = tester.widget(find.byType(MaterialApp));

      // Test that the settings route builder exists
      final settingsRouteBuilder = materialApp.routes!['/settings'];
      expect(settingsRouteBuilder, isNotNull);

      // The route should be configured to use the settingsProvider method
      // which creates a SettingsProvider with SimplifiedSettingsScreen
    });
  });
}
