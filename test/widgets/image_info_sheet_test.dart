import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/widgets/html_text.dart';
import 'package:dailywallpaper/widgets/image_info_sheet.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the original HTML title and linked credit',
      (tester) async {
    final image = ImageItem(
      id: 'pexels-1',
      date: DateTime(2026, 10, 25),
      source: 'pexels',
      imageUrl: 'https://example.com/image.jpg',
      createdAt: DateTime(2026, 10, 25),
      title: '<strong>Original photo title</strong>',
      category: 'portrait',
      credit:
          'Photo by <a href="https://example.com/photographer">Photographer</a>',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ImageInfoBottomSheet(image: image),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Original photo title'), findsOneWidget);
    expect(
      find.text('Photo by Photographer', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Pexel portrait'), findsNothing);
  });

  testWidgets('opens links found in HTML anchors', (tester) async {
    String? openedUrl;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HtmlText(
            data: 'Credit <a href="https://example.com/credit">link</a>',
            style: const TextStyle(),
            linkStyle: const TextStyle(color: Colors.blue),
            onLinkTap: (url) => openedUrl = url,
          ),
        ),
      ),
    );

    final richText = tester.widget<RichText>(find.byType(RichText));
    _findFirstRecognizer(richText.text)!.onTap!();

    expect(openedUrl, 'https://example.com/credit');
  });
}

TapGestureRecognizer? _findFirstRecognizer(InlineSpan span) {
  if (span is! TextSpan) return null;
  if (span.recognizer is TapGestureRecognizer) {
    return span.recognizer! as TapGestureRecognizer;
  }
  for (final child in span.children ?? const <InlineSpan>[]) {
    final recognizer = _findFirstRecognizer(child);
    if (recognizer != null) return recognizer;
  }
  return null;
}
