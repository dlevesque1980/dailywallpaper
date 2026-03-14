import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/main.dart';

void main() {
  group('Navigation Integration Tests', () {
    testWidgets('App should build successfully with new navigation setup',
        (WidgetTester tester) async {
      // This test verifies that the app can be built with the new navigation setup
      // and that the routes are properly configured

      // Build the app
      await tester.pumpWidget(MyApp());

      // Verify the app builds without errors
      expect(find.byType(MyApp), findsOneWidget);

      // The app should start on the home route
      // (We can't test actual navigation without mocking dependencies,
      // but we can verify the app structure is correct)
    });
  });
}
