import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/widgets/carousel_item.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('shows a spinner while the wallpaper image is loading',
      (tester) async {
    final image = ImageItem(
      id: 'wallpaper-1',
      date: DateTime(2026, 10, 25),
      source: 'test',
      imageUrl: 'https://example.com/wallpaper.jpg',
      createdAt: DateTime(2026, 10, 25),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CarouselItem(image: image),
        ),
      ),
    );

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });
}
