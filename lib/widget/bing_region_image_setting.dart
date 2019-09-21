import 'dart:ui';

import 'package:dailywallpaper/bloc/settings_bloc.dart';
import 'package:dailywallpaper/bloc_state/bing_region_state.dart';
import 'package:dailywallpaper/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/widget/header_clipper.dart';
import 'package:flutter/material.dart';
import 'package:flutter/material.dart' as material;

class BingImageRegionSetting extends StatelessWidget {
  const BingImageRegionSetting({Key key, @required this.settingsBloc, @required this.item, @required this.choice}) : super(key: key);
  final SettingsBloc settingsBloc;
  final RegionItem item;
  final BingRegionEnum choice;

  Widget _buildWidgetDesc() {
    if (choice == item.value) {
      return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        ClipRect(
          clipper: HeaderClipper(),
          child: Container(
            color: Colors.grey,
            child: Align(
                alignment: Alignment.topCenter,
                child: Text(BingRegionEnum.labelOf(item.value),
                    style: material.TextStyle(fontSize: 15.0, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
          ),
        ),
        Expanded(child: ClipRect(child: Icon(Icons.check_circle_outline, color: Colors.green, size: 50.0)))
      ]);
    }
    return ClipRect(
      clipper: HeaderClipper(),
      child: Container(
        color: Colors.grey,
        child: Align(
            alignment: Alignment.topCenter,
            child: Text(BingRegionEnum.labelOf(item.value),
                style: material.TextStyle(fontSize: 15.0, color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: GestureDetector(
        onTap: () {
          settingsBloc.regionQuery.add(BingRegionEnum.definitionOf(item.value));
          Navigator.pop(context);
        },
        child: Container(
          decoration: BoxDecoration(
            image: DecorationImage(image: NetworkImage(item.url), fit: BoxFit.cover),
          ),
          child: _buildWidgetDesc(),
        ),
      ),
    );
  }
}
