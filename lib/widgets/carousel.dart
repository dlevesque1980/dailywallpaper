import 'dart:async';

import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/widgets/carousel_item.dart';
import 'package:flutter/material.dart';

class Carousel extends StatefulWidget {
  const Carousel({
    super.key,
    required this.list,
    required this.onChange,
    this.initialPage = 0,
  }) : assert(list.length > 0);

  final List<ImageItem> list;
  final void Function(int index, bool refresh) onChange;
  final int initialPage;

  @override
  State<Carousel> createState() => _CarouselState();
}

class _CarouselState extends State<Carousel> {
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void didUpdateWidget(Carousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    final idsChanged = oldWidget.list.length != widget.list.length ||
        List.generate(oldWidget.list.length, (index) => index).any(
          (index) => oldWidget.list[index].id != widget.list[index].id,
        );
    final urlsChanged = oldWidget.list.length != widget.list.length ||
        List.generate(oldWidget.list.length, (index) => index).any(
          (index) =>
              oldWidget.list[index].imageUrl != widget.list[index].imageUrl,
        );
    if (idsChanged) {
      _pageController.dispose();
      _pageController = PageController(initialPage: widget.initialPage);
    }
    if (urlsChanged) {
      _precacheImages();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _precacheImages();
  }

  void _precacheImages() {
    final precachedUrls = <String>{};
    for (final image in widget.list) {
      if (!precachedUrls.add(image.imageUrl)) continue;
      unawaited(
        precacheImage(
          wallpaperImageProvider(context, image),
          context,
          onError: (error, _) {
            debugPrint('Unable to preload wallpaper ${image.id}: $error');
          },
        ),
      );
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 0 || constraints.maxHeight <= 0) {
          return const SizedBox.shrink();
        }
        return PageView.builder(
          controller: _pageController,
          itemCount: widget.list.length,
          onPageChanged: (index) => widget.onChange(index, false),
          itemBuilder: (context, index) =>
              CarouselItem(image: widget.list[index]),
        );
      },
    );
  }
}
