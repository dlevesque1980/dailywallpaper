import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:flutter/material.dart';

ImageProvider<Object> wallpaperImageProvider(
  BuildContext context,
  ImageItem image,
) {
  final media = MediaQuery.of(context);
  return ResizeImage(
    NetworkImage(image.imageUrl),
    width: (media.size.width * media.devicePixelRatio).round(),
    height: (media.size.height * media.devicePixelRatio).round(),
  );
}

class CarouselItem extends StatelessWidget {
  const CarouselItem({super.key, required this.image});

  final ImageItem image;

  @override
  Widget build(BuildContext context) {
    return Image(
      image: wallpaperImageProvider(context, image),
      fit: BoxFit.cover,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (frame != null || wasSynchronouslyLoaded) return child;
        return const Center(
          child: CircularProgressIndicator(color: Colors.white),
        );
      },
      errorBuilder: (context, error, stackTrace) => const ColoredBox(
        color: Colors.black87,
        child: Center(
          child: Icon(Icons.error_outline, color: Colors.white54, size: 48),
        ),
      ),
    );
  }
}
