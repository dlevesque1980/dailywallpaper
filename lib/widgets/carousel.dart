import 'dart:ui' as ui;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:flutter/material.dart';
import 'package:dailywallpaper/widgets/carousel_item.dart';


@immutable
class Carousel extends StatefulWidget {
  ///All the [Widget] on this Carousel.
  final List<ImageItem> list;
  final Function onChange;
  final int initialPage;

  ///Returns [children]`s [lenght].
  int get childrenCount => list.length;

  Carousel({required this.list, required this.onChange, this.initialPage = 0})
      : assert(list.length > 0);

  @override
  State createState() => _CarouselState();
}

class _CarouselState extends State<Carousel> with TickerProviderStateMixin {
  TabController? _controller;
  PageController? _pageController;
  int _numOfTab = 0;

  // Cache for processed images to avoid reprocessing
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Widget> _widgetCache = {};

  // Track which images are currently being processed to avoid duplicate work
  final Set<String> _processingImages = {};



  ///Actual index of the displaying Widget
  int get actualIndex => _controller!.index;
  ValueNotifier<int> notifierIndex = ValueNotifier(0);

  ///Returns the calculated value of the next index.
  int get nextIndex {
    var nextIndexValue = actualIndex;

    if (nextIndexValue < _controller!.length - 1)
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
    notifierIndex.value = _controller!.index;
    widget.onChange(_controller!.index, false);
  }

  @override
  void dispose() {
    // Dispose cached images to free memory
    _disposeImageCache();

    if (_controller != null) _controller!.dispose();
    if (_pageController != null) _pageController!.dispose();
    super.dispose();
  }

  /// Dispose all cached images to free memory
  void _disposeImageCache() {
    for (final image in _imageCache.values) {
      image.dispose();
    }
    _imageCache.clear();
    _widgetCache.clear();
    _processingImages.clear();
  }

  /// Clear cache when widget list changes (e.g., date change)
  void _clearCacheIfNeeded() {
    // Clear cache when the image list changes to prevent memory leaks
    if (_numOfTab != widget.childrenCount) {
      _disposeImageCache();
    }
  }



  @override
  Widget build(BuildContext context) {
    if (widget.childrenCount != _numOfTab || _pageController == null) {
      int oldIndex = _controller?.index ?? widget.initialPage;

      // Clear cache when image list changes (e.g., date change)
      _clearCacheIfNeeded();

      _numOfTab = widget.childrenCount;

      // Dispose old controllers if they exist
      if (_controller != null) {
        _controller!.removeListener(_onChange);
        _controller!.dispose();
      }

      if (_pageController != null) {
        _pageController!.dispose();
      }

      _controller =
          TabController(length: widget.childrenCount, vsync: this);
      _controller!.addListener(_onChange);

      // Adjust index if it's out of bounds
      if (oldIndex >= widget.childrenCount) {
        // If old index is out of bounds, go to last item
        _controller!.index = widget.childrenCount - 1;
      } else {
        _controller!.index = oldIndex;
      }

      _pageController = PageController(initialPage: _controller!.index);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Prevent Flutter PageView bug during Android surface recreation
        // When the width temporarily drops to 0, PageView calculates its page as 0
        if (constraints.maxWidth == 0 || constraints.maxHeight == 0) {
          return const SizedBox.shrink();
        }

        return PageView.builder(
          controller: _pageController,
          itemCount: widget.list.length,
          onPageChanged: (index) {
            // Sync TabController index when PageView changes
            if (_controller!.index != index) {
              _controller!.index = index;
              // IMPORTANT: Manually notify listeners/parent of the index change
              // This ensures HomeScreen.notifierIndex is updated for the Crop Info button
              _onChange();
            }
          },
          itemBuilder: (context, index) {
            return CarouselItem(image: widget.list[index]);
          },
        );
      },
    );
  }
}


