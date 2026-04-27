import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/widgets/smart_crop_quality_slider.dart';

void main() {
  group('SmartCropQualitySlider', () {
    testWidgets('displays correct labels and colors',
        (WidgetTester tester) async {
      int selectedLevel = 2; // Balanced

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartCropQualitySlider(
              currentLevel: selectedLevel,
              onLevelChanged: (level) {
                selectedLevel = level;
              },
            ),
          ),
        ),
      );

      // Check that the title is present
      expect(find.text('Smart Crop Quality'), findsOneWidget);

      // Check that all labels are present (some appear twice due to current selection)
      expect(find.text('Off'), findsOneWidget);
      expect(find.text('Conservative'), findsOneWidget);
      expect(find.text('Balanced'),
          findsNWidgets(2)); // Appears in labels and as current selection
      expect(find.text('Aggressive'), findsOneWidget);
    });

    testWidgets('shows correct description for each level',
        (WidgetTester tester) async {
      // Test level 0 (Off)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartCropQualitySlider(
              currentLevel: 0,
              onLevelChanged: (level) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('Smart Crop disabled'), findsOneWidget);

      // Test level 2 (Balanced)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartCropQualitySlider(
              currentLevel: 2,
              onLevelChanged: (level) {},
            ),
          ),
        ),
      );

      expect(find.textContaining('optimal performance and battery balance'),
          findsOneWidget);
    });

    testWidgets('slider is disabled when enabled is false',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartCropQualitySlider(
              currentLevel: 2,
              onLevelChanged: (level) {},
              enabled: false,
            ),
          ),
        ),
      );

      final slider = tester.widget<Slider>(find.byType(Slider));
      expect(slider.onChanged, isNull);
    });

    testWidgets('updates current level when widget updates',
        (WidgetTester tester) async {
      int currentLevel = 1;

      await tester.pumpWidget(
        MaterialApp(
          home: StatefulBuilder(
            builder: (context, setState) {
              return Scaffold(
                body: Column(
                  children: [
                    SmartCropQualitySlider(
                      currentLevel: currentLevel,
                      onLevelChanged: (level) {
                        setState(() {
                          currentLevel = level;
                        });
                      },
                    ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          currentLevel = 3;
                        });
                      },
                      child: const Text('Change to Aggressive'),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );

      // Initially should show Conservative (appears twice - in labels and indicator)
      expect(find.text('Conservative'), findsNWidgets(2));

      // Tap button to change level
      await tester.tap(find.text('Change to Aggressive'));
      await tester.pumpAndSettle();

      // Should now show Aggressive (appears twice - in labels and indicator)
      expect(find.text('Aggressive'), findsNWidgets(2));
    });

    testWidgets('clamps level values to valid range',
        (WidgetTester tester) async {
      // Test with invalid level (too high)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartCropQualitySlider(
              currentLevel: 10, // Invalid, should be clamped to 3
              onLevelChanged: (level) {},
            ),
          ),
        ),
      );

      expect(find.text('Aggressive'),
          findsNWidgets(2)); // Should show level 3 (twice)

      // Test with invalid level (too low)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SmartCropQualitySlider(
              currentLevel: -5, // Invalid, should be clamped to 0
              onLevelChanged: (level) {},
            ),
          ),
        ),
      );

      expect(find.text('Off'), findsNWidgets(2)); // Should show level 0 (twice)
    });
  });
}
