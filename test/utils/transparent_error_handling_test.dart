import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/utils/transparent_error_handling.dart';

void main() {
  group('TransparentErrorHandling Unit Tests', () {
    testWidgets('safeFutureBuilder prevents persistent loading on success',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransparentErrorHandling.safeFutureBuilder<String>(
              future: Future.value('success'),
              builder: (context, data) => Text(data),
              showLoadingOnWaiting: false, // Key: prevent persistent loading
            ),
          ),
        ),
      );

      await tester.pump();

      // Should show the success text, not loading
      expect(find.text('success'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('safeStreamBuilder prevents persistent loading on data',
        (WidgetTester tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TransparentErrorHandling.safeStreamBuilder<String>(
              stream: controller.stream,
              builder: (context, data) => Text(data),
              showLoadingOnWaiting: false, // Key: prevent persistent loading
            ),
          ),
        ),
      );

      // Initially should show empty container (no loading)
      await tester.pump();
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Add data to stream
      controller.add('stream_data');
      await tester.pump();

      // Should show data, not loading
      expect(find.text('stream_data'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      controller.close();
    });

    testWidgets(
        'handleLoadingError returns empty container when showLoadingOnWaiting is false',
        (WidgetTester tester) async {
      final snapshot = AsyncSnapshot<String?>.withData(
        ConnectionState.waiting,
        null,
      );

      final result = TransparentErrorHandling.handleLoadingError(
        snapshot,
        showLoadingOnWaiting: false,
      );

      // Should return a Container (not loading widget)
      expect(result, isA<Container>());
      expect(result, isNot(isA<CircularProgressIndicator>()));
    });

    testWidgets(
        'handleLoadingError shows loading only when explicitly requested',
        (WidgetTester tester) async {
      final snapshot = AsyncSnapshot<String?>.withData(
        ConnectionState.waiting,
        null,
      );

      final result = TransparentErrorHandling.handleLoadingError(
        snapshot,
        showLoadingOnWaiting: true,
        loadingWidget: CircularProgressIndicator(),
      );

      // Should return loading widget when explicitly requested
      expect(result, isA<CircularProgressIndicator>());
    });

    test('handleConfigurationError provides fallback without throwing',
        () async {
      // This should not throw an exception
      final result = await TransparentErrorHandling.handleConfigurationError(
        () => throw Exception('Configuration failed'),
        'fallback_value',
        errorContext: 'Test configuration',
      );

      expect(result, equals('fallback_value'));
    });
  });
}
