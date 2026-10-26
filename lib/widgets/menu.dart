import 'package:flutter/material.dart';

class Menu extends StatelessWidget {
  const Menu({super.key, required this.callback});
  final void Function() callback;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      onSelected: (choice) =>
          Navigator.pushNamed(context, choice).then((value) => callback()),
      padding: EdgeInsets.all(0.0),
      offset: Offset.fromDirection(2, 55),
      icon: const Icon(
        Icons.more_vert,
        color: Colors.white,
      ),
      itemBuilder: (BuildContext context) => <PopupMenuItem<String>>[
        PopupMenuItem<String>(
          value: '/settings',
          height: 40.0,
          child: Row(
            children: [
              const Icon(Icons.settings, size: 20),
              const SizedBox(width: 8),
              const Text('Settings'),
            ],
          ),
        ),
        PopupMenuItem<String>(
          value: '/older',
          height: 40.0,
          child: Row(
            children: [
              const Icon(Icons.history, size: 20),
              const SizedBox(width: 8),
              const Text('History'),
            ],
          ),
        ),
      ],
    );
  }
}
