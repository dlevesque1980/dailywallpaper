import 'package:dailywallpaper/models/image_item.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class MenuTitle extends StatelessWidget {
  const MenuTitle({
    Key key,
    @required List<ImageItem> images,
    @required int imageIndex,
  })  : _imageIndex = imageIndex,
        _images = images,
        super(key: key);

  final int _imageIndex;
  final List<ImageItem> _images;
  @override
  Widget build(BuildContext context) {
    return new Expanded(
      child: new Text(_images[_imageIndex].source ?? "", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w500, color: Colors.white)),
    );
  }
}
