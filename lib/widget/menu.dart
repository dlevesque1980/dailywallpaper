import 'dart:ui';

import 'package:flutter/material.dart';

class Menu extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return new PopupMenuButton<String>(
      onSelected: (choice) => Navigator.pushNamed(context, choice),
      padding: EdgeInsets.all(0.0),
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
            PopupMenuItem<String>(value: '/older', enabled: false, child: const Text('Older wallpaper', textAlign: TextAlign.center), height: 40.0),
          ],
    );
  }
}
