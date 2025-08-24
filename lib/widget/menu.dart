import 'package:flutter/material.dart';

class Menu extends StatelessWidget {
  const Menu({required Key key, required this.callback}) : super(key: key);
  final void Function() callback;

  @override
  Widget build(BuildContext context) {
    return new PopupMenuButton<String>(
      onSelected: (choice) =>
          Navigator.pushNamed(context, choice).then((value) => this.callback()),
      padding: EdgeInsets.all(0.0),
      offset: Offset.fromDirection(2, 55),
      icon: new Icon(
        Icons.more_vert,
        color: Colors.white,
      ),
      itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
        PopupMenuItem<String>(
          value: '/settings',
          child: Row(
            children: [
              Icon(Icons.settings, size: 20),
              SizedBox(width: 8),
              Text('Settings'),
            ],
          ),
          height: 40.0,
        ) //,
        // PopupMenuItem<String>(
        //   value: '/older',
        //   child: Row(
        //     children: [
        //       Icon(Icons.history, size: 20),
        //       SizedBox(width: 8),
        //       Text('History'),
        //     ],
        //   ),
        //   height: 40.0,
        // ),
      ],
    );
  }
}
