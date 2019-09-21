import 'dart:ui';

import 'package:flutter/material.dart';

class Menu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new PopupMenuButton<String>(
      onSelected: (choice) => Navigator.pushNamed(context, choice),
      padding: EdgeInsets.all(0.0),
      offset: Offset.fromDirection(2, 55),
      icon: new Icon(
        Icons.more_vert,
        color: Colors.white,
      ),
      itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
        PopupMenuItem<String>(
          value: '/settings',
          child: const Text('Settings', textAlign: TextAlign.center),
          height: 40.0,
        ),
      ],
    );
  }
}
