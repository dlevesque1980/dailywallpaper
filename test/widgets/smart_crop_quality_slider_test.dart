import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/widgets/smart_crop_quality_slider.dart';
import 'package:dailywallpaper/l10n/app_localizations.dart';

void main() {
  Widget createWidgetUnderTest({
    required int currentLevel,
    required Function(int) onLevelChanged,
    required bool subjectScalingEnabled,
    required Function(bool) onScalingToggled,
    bool enabled = true,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SmartCropQualitySlider(
          currentLevel: currentLevel,
          onLevelChanged: onLevelChanged,
          subjectScalingEnabled: subjectScalingEnabled,
          onScalingToggled: onScalingToggled,
          enabled: enabled,
        ),
      ),
    );
  }

  testWidgets(
      'SmartCropQualitySlider renders correctly and shows correct initial state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      createWidgetUnderTest(
        currentLevel: 2, // Balanced
        onLevelChanged: (_) {},
        subjectScalingEnabled: true,
        onScalingToggled: (_) {},
      ),
    );
    await tester.pump();

    // Verify main components render
    expect(find.text('Smart Crop Quality'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(
        find.text('Balanced'), findsWidgets); // Both label and value indicator
    expect(
        find.text(
            'Balanced quality - optimal performance and battery balance (recommended)'),
        findsOneWidget);

    // Scaling switch should be visible since level > 0
    expect(find.byType(SwitchListTile), findsOneWidget);
  });

  testWidgets(
      'SmartCropQualitySlider does not show scaling switch when level is 0',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      createWidgetUnderTest(
        currentLevel: 0, // Off
        onLevelChanged: (_) {},
        subjectScalingEnabled: false,
        onScalingToggled: (_) {},
      ),
    );
    await tester.pump();

    expect(find.text('Off'), findsWidgets);
    expect(find.text('Smart Crop disabled - uses standard cropping'),
        findsOneWidget);

    // Scaling switch should not be visible since level is 0
    expect(find.byType(SwitchListTile), findsNothing);
  });

  testWidgets('SmartCropQualitySlider toggles scaling switch correctly',
      (WidgetTester tester) async {
    bool toggledValue = false;
    await tester.pumpWidget(
      createWidgetUnderTest(
        currentLevel: 2,
        onLevelChanged: (_) {},
        subjectScalingEnabled: false,
        onScalingToggled: (val) {
          toggledValue = val;
        },
      ),
    );
    await tester.pump();

    // Find the SwitchListTile
    final switchFinder = find.byType(SwitchListTile);
    expect(switchFinder, findsOneWidget);

    // Tap on the switch
    await tester.tap(switchFinder);
    await tester.pump();

    expect(toggledValue, isTrue);
  });

  testWidgets('SmartCropQualitySlider triggers level changes on onChanged',
      (WidgetTester tester) async {
    int? changedLevel;
    await tester.pumpWidget(
      createWidgetUnderTest(
        currentLevel: 1, // Conservative
        onLevelChanged: (level) {
          changedLevel = level;
        },
        subjectScalingEnabled: false,
        onScalingToggled: (_) {},
      ),
    );
    await tester.pump();

    final sliderFinder = find.byType(Slider);
    expect(sliderFinder, findsOneWidget);

    final Slider slider = tester.widget(sliderFinder);

    // Trigger change to 3 (Aggressive)
    slider.onChanged?.call(3.0);
    slider.onChangeEnd?.call(3.0);
    await tester.pump();

    expect(changedLevel, equals(3));
  });

  testWidgets('SmartCropQualitySlider respects disabled state',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      createWidgetUnderTest(
        currentLevel: 1,
        onLevelChanged: (_) {},
        subjectScalingEnabled: false,
        onScalingToggled: (_) {},
        enabled: false,
      ),
    );
    await tester.pump();

    // Verify slider is disabled (Slider.onChanged is null)
    final Slider slider = tester.widget(find.byType(Slider));
    expect(slider.onChanged, isNull);

    // Verify switch is disabled (SwitchListTile.onChanged is null)
    final SwitchListTile switchTile = tester.widget(find.byType(SwitchListTile));
    expect(switchTile.onChanged, isNull);
  });
}
