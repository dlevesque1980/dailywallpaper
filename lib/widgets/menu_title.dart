import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:flutter/material.dart';

class MenuTitle extends StatelessWidget {
  const MenuTitle({
    super.key,
    required this.images,
    required this.imageIndex,
  });

  final int imageIndex;
  final List<ImageItem> images;
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(images[imageIndex].displayTitle,
          style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white)),
    );
  }
}
