import 'package:flutter/material.dart';

class Menu extends StatelessWidget {
  const Menu({Key key, @required this.callback}) : super(key: key);
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
          child: const Text('Settings', textAlign: TextAlign.center),
          height: 40.0,
        ),
      ],
    );
  }
}
