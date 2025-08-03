import 'dart:ui';

import 'package:dailywallpaper/widget/text_with_hyperlink.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;

class ImageDescription extends StatelessWidget {
  const ImageDescription({required this.key, required this.description, required this.copyright}) : super(key: key);
  final Key key;
  final String description;
  final String copyright;

  @override
  Widget build(BuildContext context) {
    return new ClipRect(
      child: new BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: 50.0,
          sigmaY: 50.0,
        ),
        child: Container(
          padding: EdgeInsets.only(top: 16.0, bottom: 16.0, left: 16.0, right: 16.0),
          child: Column(
            children: <Widget>[
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  description ?? "",
                  style: material.TextStyle(fontSize: 20.0, color: Colors.white, package: "dailywallpaper"),
                ),
              ),
              Text(""),
              Align(alignment: Alignment.centerLeft, child: TextWithHyperLink(text: copyright)),
            ],
          ),
        ),
      ),
    );
  }
}
