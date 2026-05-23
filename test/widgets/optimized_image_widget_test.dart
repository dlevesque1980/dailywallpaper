import 'dart:ui' as ui;
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/widgets/optimized_image_widget.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/services/intelligent_cache_service.dart';

class MockImagePreloaderService extends Mock implements ImagePreloaderService {}

void main() {
  late MockImagePreloaderService mockPreloader;
  late ui.Image realTestImage;
  late ImageItem imageItem;

  // Helper to create a real 1x1 pixel PNG in memory
  Future<ui.Image> createTestImage() async {
    final completer = Completer<ui.Image>();
    final bytes = Uint8List.fromList([
      0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D,
      0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
      0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
      0x0A, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0x00, 0x01, 0x00, 0x00,
      0x05, 0x00, 0x01, 0x0D, 0x0A, 0x2D, 0xB4, 0x00, 0x00, 0x00, 0x00, 0x49,
      0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82
    ]);
    ui.decodeImageFromList(bytes, (ui.Image image) {
      completer.complete(image);
    });
    return completer.future;
  }

  setUpAll(() async {
    registerFallbackValue(ImageItem(
      "Source",
      "https://example.com/image.jpg",
      "Description",
      DateTime.now(),
      DateTime.now().add(const Duration(days: 1)),
      "image_ident",
      null,
      "Copyright",
    ));
    realTestImage = await createTestImage();
  });

  setUp(() {
    mockPreloader = MockImagePreloaderService();

    imageItem = ImageItem(
      "Source",
      "https://example.com/image.jpg",
      "Description",
      DateTime.now(),
      DateTime.now().add(const Duration(days: 1)),
      "image_ident",
      null,
      "Copyright",
    );

    // Set the singleton instance of ImagePreloaderService to our mock
    ImagePreloaderService.setInstance(mockPreloader);

    // Clear IntelligentCacheService to ensure clean state
    IntelligentCacheService().clear();
  });

  Widget createWidgetUnderTest({
    bool enableSmartCrop = true,
    Widget? placeholder,
    Widget? errorWidget,
  }) {
    return MaterialApp(
      home: Scaffold(
        body: OptimizedImageWidget(
          imageItem: imageItem,
          enableSmartCrop: enableSmartCrop,
          placeholder: placeholder,
          errorWidget: errorWidget,
        ),
      ),
    );
  }

  testWidgets(
      'OptimizedImageWidget displays preloaded/processed image on success',
      (WidgetTester tester) async {
    // Stub the preloader to return our real image
    when(() => mockPreloader.getProcessedImage(any()))
        .thenReturn(realTestImage);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pump(); // Pump to let setState run

    // Verify CustomPaint inside OptimizedImageWidget is rendered (since _displayImage != null)
    final customPaintFinder = find.descendant(
      of: find.byType(OptimizedImageWidget),
      matching: find.byType(CustomPaint),
    );
    expect(customPaintFinder, findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets(
      'OptimizedImageWidget displays placeholder or circular progress when loading',
      (WidgetTester tester) async {
    // Stub preloader to return null (forcing fallback to standard loading which will remain loading)
    when(() => mockPreloader.getProcessedImage(any())).thenReturn(null);
    when(() => mockPreloader.getPreloadedImage(any())).thenReturn(null);

    await tester.pumpWidget(createWidgetUnderTest(
      placeholder: const Text('Loading Placeholder...'),
    ));

    // Verify that the placeholder is displayed
    expect(find.text('Loading Placeholder...'), findsOneWidget);
  });

  testWidgets('OptimizedImageWidget displays error widget on failure',
      (WidgetTester tester) async {
    // Stub preloader to throw an error during getProcessedImage
    when(() => mockPreloader.getProcessedImage(any()))
        .thenThrow(Exception('Failed to load'));

    await tester.pumpWidget(createWidgetUnderTest(
      errorWidget: const Text('Custom Error Widget'),
    ));
    await tester.pump(); // Rebuild with error

    expect(find.text('Custom Error Widget'), findsOneWidget);
  });
}
