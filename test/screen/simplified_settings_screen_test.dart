import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/settings/screens/simplified_settings_screen.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_provider.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/pexels_categories_bloc.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_profile_manager.dart';
import 'package:dailywallpaper/core/utils/transparent_error_handling.dart';

void main() {
  group('SimplifiedSettingsScreen UI Tests', () {
    testWidgets('should render without persistent loading widgets',
        (WidgetTester tester) async {
      // Create mock blocs
      final settingsBloc = SettingsBloc();
      final pexelsCategoriesBloc = PexelsCategoriesBloc();

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsProvider(
            settingsBloc: settingsBloc,
            pexelsCategoriesBloc: pexelsCategoriesBloc,
            child: SimplifiedSettingsScreen(),
          ),
        ),
      );

      // Wait for initial build
      await tester.pump();

      // Verify the screen loads
      expect(find.text('Settings'), findsOneWidget);

      // Verify essential settings are present
      expect(find.text('Set lock screen wallpaper'), findsOneWidget);
      expect(find.text('Bing region'), findsOneWidget);
      expect(find.text('Pexels Categories'), findsOneWidget);
      expect(find.text('Smart Crop Quality'), findsOneWidget);

      // Clean up
      settingsBloc.dispose();
      pexelsCategoriesBloc.dispose();
    });

    testWidgets('should scroll without persistent loading indicators',
        (WidgetTester tester) async {
      // Create mock blocs
      final settingsBloc = SettingsBloc();
      final pexelsCategoriesBloc = PexelsCategoriesBloc();

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsProvider(
            settingsBloc: settingsBloc,
            pexelsCategoriesBloc: pexelsCategoriesBloc,
            child: SimplifiedSettingsScreen(),
          ),
        ),
      );

      // Wait for initial build
      await tester.pump();

      // Scroll down
      await tester.drag(find.byType(ListView), const Offset(0, -200));
      await tester.pump();

      // Verify no persistent loading indicators
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Scroll back up
      await tester.drag(find.byType(ListView), const Offset(0, 200));
      await tester.pump();

      // Still no persistent loading indicators
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Clean up
      settingsBloc.dispose();
      pexelsCategoriesBloc.dispose();
    });

    testWidgets('should handle errors transparently without blocking UI',
        (WidgetTester tester) async {
      // Create mock blocs
      final settingsBloc = SettingsBloc();
      final pexelsCategoriesBloc = PexelsCategoriesBloc();

      // Build the widget
      await tester.pumpWidget(
        MaterialApp(
          home: SettingsProvider(
            settingsBloc: settingsBloc,
            pexelsCategoriesBloc: pexelsCategoriesBloc,
            child: SimplifiedSettingsScreen(),
          ),
        ),
      );

      // Wait for initial build
      await tester.pump();

      // Verify that even if streams have errors, the UI remains functional
      // The TransparentErrorHandling should prevent UI blocking

      // Scroll to test stability
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pump();

      // UI should remain responsive
      expect(find.byType(ListView), findsOneWidget);
      expect(find.text('Smart Crop Quality'), findsOneWidget);

      // Clean up
      settingsBloc.dispose();
      pexelsCategoriesBloc.dispose();
    });
  });

  group('TransparentErrorHandling Tests', () {
    testWidgets('safeFutureBuilder should handle errors gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransparentErrorHandling.safeFutureBuilder<String>(
              future: Future.error('Test error'),
              builder: (context, data) => Text(data),
              errorWidget: Text('Error handled'),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show error widget instead of crashing
      expect(find.text('Error handled'), findsOneWidget);
    });

    testWidgets('safeStreamBuilder should handle errors gracefully',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransparentErrorHandling.safeStreamBuilder<String>(
              stream: Stream.error('Test error'),
              builder: (context, data) => Text(data),
              errorWidget: Text('Stream error handled'),
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show error widget instead of crashing
      expect(find.text('Stream error handled'), findsOneWidget);
    });

    test('handleConfigurationError should return default on error', () async {
      final result = await TransparentErrorHandling.handleConfigurationError(
        () => throw Exception('Test error'),
        'default_value',
        errorContext: 'Test context',
      );

      expect(result, equals('default_value'));
    });
  });

  group('Smart Crop Slider Configuration Tests', () {
    test('Smart Crop slider should have 4 positions with correct labels', () {
      // Test that the SmartCropProfileManager has the correct level labels
      expect(SmartCropProfileManager.levelLabels[0], equals("Off"));
      expect(SmartCropProfileManager.levelLabels[1], equals("Conservative"));
      expect(SmartCropProfileManager.levelLabels[2], equals("Balanced"));
      expect(SmartCropProfileManager.levelLabels[3], equals("Aggressive"));
    });

    test('Smart Crop level descriptions should be available', () {
      // Test that each level has a description
      expect(
          SmartCropProfileManager.getLevelDescription(0), contains("disabled"));
      expect(SmartCropProfileManager.getLevelDescription(1),
          contains("Conservative"));
      expect(
          SmartCropProfileManager.getLevelDescription(2), contains("Balanced"));
      expect(SmartCropProfileManager.getLevelDescription(3),
          contains("Aggressive"));
    });

    test('SmartCropProfileManager should reject invalid levels', () {
      // Test invalid levels
      expect(() => SmartCropProfileManager.setSmartCropLevel(-1),
          throwsArgumentError);
      expect(() => SmartCropProfileManager.setSmartCropLevel(4),
          throwsArgumentError);
    });

    test('Default level should be 2 (Balanced)', () {
      expect(SmartCropProfileManager.defaultLevel, equals(2));
    });

    test('All levels should have labels and descriptions', () {
      for (int level = 0; level <= 3; level++) {
        expect(SmartCropProfileManager.getLevelLabel(level), isNotEmpty);
        expect(SmartCropProfileManager.getLevelDescription(level), isNotEmpty);
      }
    });
  });
}
