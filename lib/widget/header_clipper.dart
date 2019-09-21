import 'package:flutter/cupertino.dart';

class HeaderClipper extends CustomClipper<Rect> {
  @override
  Rect getClip(Size size) {
    return new Rect.fromLTRB(0.0, 0.0, 150.0, 20.0);
  }

  @override
  bool shouldReclip(CustomClipper<Rect> oldClipper) {
    return false;
  }
}
