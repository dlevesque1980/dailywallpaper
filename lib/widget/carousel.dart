import 'package:dailywallpaper/models/image_item.dart';
import 'package:flutter/material.dart';

import 'info_image.dart';
import 'menu.dart';
import 'menu_title.dart';

@immutable
class Carousel extends StatefulWidget {
  ///All the [Widget] on this Carousel.
  final List<ImageItem> list;
  final Function onChange;

  ///Returns [children]`s [lenght].
  int get childrenCount => list.length;

  Carousel({this.list, this.onChange})
      : assert(list != null),
        assert(list.length > 1);

  @override
  State createState() => new _CarouselState();
}

class _CarouselState extends State<Carousel> with TickerProviderStateMixin {
  TabController _controller;
  int _numOfTab = 0;

  ///Actual index of the displaying Widget
  int get actualIndex => _controller.index;
  ValueNotifier<int> notifierIndex = new ValueNotifier(0);

  ///Returns the calculated value of the next index.
  int get nextIndex {
    var nextIndexValue = actualIndex;

    if (nextIndexValue < _controller.length - 1)
      nextIndexValue++;
    else
      nextIndexValue = 0;

    return nextIndexValue;
  }

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
  }

  void _onChange() {
    notifierIndex.value = _controller.index;
    this.widget.onChange(_controller.index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Widget tabViewChild(ImageItem image) {
    return Container(
        padding: EdgeInsets.only(top: 48.0),
        alignment: Alignment.topLeft,
        decoration: new BoxDecoration(
            image: new DecorationImage(
          image: new NetworkImage(image.url),
          fit: BoxFit.cover,
        )));
  }

  @override
  Widget build(BuildContext context) {
    if (widget.childrenCount != _numOfTab) {
      _numOfTab = widget.childrenCount;
      _controller = new TabController(length: widget.childrenCount, vsync: this);
      _controller.addListener(this._onChange);
    }
    return Stack(children: <Widget>[
      TabBarView(
        children: List<Widget>.generate(widget.list.length, (i) => tabViewChild(widget.list[i])),
        controller: this._controller,
      ),
      ValueListenableBuilder(
          valueListenable: notifierIndex,
          builder: (context, value, child) {
            return SafeArea(
                child: Container(
                    color: Colors.black.withOpacity(0.2),
                    padding: EdgeInsets.only(left: 16.0),
                    child: new Row(children: <Widget>[
                      MenuTitle(images: widget.list, imageIndex: notifierIndex.value),
                      InfoImage(image: widget.list[notifierIndex.value]),
                      Menu()
                    ])));
          })
    ]);
  }
}
