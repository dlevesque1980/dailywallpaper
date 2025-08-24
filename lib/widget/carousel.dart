import 'package:dailywallpaper/models/image_item.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import '../services/smart_crop/smart_cropper.dart';
import '../services/smart_crop/smart_crop_preferences.dart';
import '../services/smart_crop/utils/screen_utils.dart';
import '../services/smart_crop/utils/image_utils.dart';

@immutable
class Carousel extends StatefulWidget {
  ///All the [Widget] on this Carousel.
  final List<ImageItem> list;
  final Function onChange;

  ///Returns [children]`s [lenght].
  int get childrenCount => list.length;

  Carousel({required this.list, required this.onChange})
      : assert(list.length > 1);

  @override
  State createState() => new _CarouselState();
}

class _CarouselState extends State<Carousel> with TickerProviderStateMixin {
  TabController? _controller;
  int _numOfTab = 0;

  ///Actual index of the displaying Widget
  int get actualIndex => _controller!.index;
  ValueNotifier<int> notifierIndex = new ValueNotifier(0);

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
    this.widget.onChange(_controller!.index, false);
  }

  @override
  void dispose() {

    if (_controller !=null) _controller!.dispose();
    super.dispose();
  }

  Widget tabViewChild(ImageItem image) {
    return FutureBuilder<Widget>(
      future: _buildImageWidget(image),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading state during crop processing
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(image.url),
                fit: BoxFit.cover,
              ),
            ),
            child: Container(
              alignment: Alignment.center,
              child: CircularProgressIndicator(
                backgroundColor: Colors.black26,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
              ),
            ),
          );
        } else if (snapshot.hasError) {
          // Fallback to standard cropping on error
          return Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(image.url),
                fit: BoxFit.cover,
              ),
            ),
          );
        } else {
          return snapshot.data ?? Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(image.url),
                fit: BoxFit.cover,
              ),
            ),
          );
        }
      },
    );
  }

  Future<Widget> _buildImageWidget(ImageItem image) async {
    try {
      // Check if smart crop is enabled
      final isSmartCropEnabled = await SmartCropPreferences.isSmartCropEnabled();
      
      if (!isSmartCropEnabled) {
        // Use standard BoxFit.cover if smart crop is disabled
        return _buildStandardImageWidget(image);
      }

      // Get crop settings and physical screen size (including system bars)
      final cropSettings = await SmartCropPreferences.getCropSettings();
      final screenSize = ScreenUtils.getPhysicalScreenSize();
      
      // Load the image for smart cropping
      final sourceImage = await ImageUtils.loadImageFromUrl(image.url);
      
      if (sourceImage == null) {
        // Fallback to standard widget if image loading fails
        return _buildStandardImageWidget(image);
      }

      // Calculate target size based on physical screen dimensions (including system bars)
      final targetSize = ScreenUtils.calculateTargetSize(
        ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        screenSize.width / screenSize.height,
        maxDimension: screenSize.width > screenSize.height ? screenSize.width.round() : screenSize.height.round(),
      );

      // Process image with smart crop
      final result = await SmartCropper.processImage(
        image.url,
        sourceImage,
        targetSize,
        cropSettings,
      );

      if (result.success) {
        // Use the smart cropped image
        return _buildSmartCroppedImageWidget(result.image);
      } else {
        // Fallback to standard cropping if smart crop fails
        return _buildStandardImageWidget(image);
      }
    } catch (e) {
      // Fallback to standard cropping on any error
      debugPrint('Smart crop error for ${image.url}: $e');
      return _buildStandardImageWidget(image);
    }
  }

  Widget _buildStandardImageWidget(ImageItem image) {
    return Container(
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(image.url),
          fit: BoxFit.cover,
        ),
      ),
    );
  }

  Widget _buildSmartCroppedImageWidget(ui.Image croppedImage) {
    return Container(
      child: CustomPaint(
        painter: _SmartCroppedImagePainter(croppedImage),
        size: Size.infinite,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.childrenCount != _numOfTab) {
      int oldIndex = _controller?.index ?? 0;
      _numOfTab = widget.childrenCount;
      
      // Dispose old controller if it exists
      if (_controller != null) {
        _controller!.removeListener(this._onChange);
        _controller!.dispose();
      }
      
      _controller = new TabController(length: widget.childrenCount, vsync: this);
      _controller!.addListener(this._onChange);
      
      // Adjust index if it's out of bounds
      if (oldIndex >= widget.childrenCount) {
        // If old index is out of bounds, go to last item
        _controller!.index = widget.childrenCount - 1;
      } else {
        _controller!.index = oldIndex;
      }
    }
    return Stack(children: <Widget>[
      TabBarView(
        children: List<Widget>.generate(
            widget.list.length, (i) => tabViewChild(widget.list[i])),
        controller: this._controller,
      ),

    ]);
  }
}

/// Custom painter for rendering smart cropped images
class _SmartCroppedImagePainter extends CustomPainter {
  final ui.Image image;

  _SmartCroppedImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    // Calculate how to fit the cropped image to fill the container
    final imageAspectRatio = image.width / image.height;
    final containerAspectRatio = size.width / size.height;

    double drawWidth, drawHeight;
    double offsetX = 0, offsetY = 0;

    if (imageAspectRatio > containerAspectRatio) {
      // Image is wider than container - fit to height
      drawHeight = size.height;
      drawWidth = drawHeight * imageAspectRatio;
      offsetX = (size.width - drawWidth) / 2;
    } else {
      // Image is taller than container - fit to width
      drawWidth = size.width;
      drawHeight = drawWidth / imageAspectRatio;
      offsetY = (size.height - drawHeight) / 2;
    }

    final destRect = Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight);
    final srcRect = Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    canvas.drawImageRect(image, srcRect, destRect, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _SmartCroppedImagePainter || oldDelegate.image != image;
  }
}
