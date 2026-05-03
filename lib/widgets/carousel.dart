import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';

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
  PageController? _pageController;
  int _numOfTab = 0;

  // Cache for processed images to avoid reprocessing
  final Map<String, ui.Image> _imageCache = {};
  final Map<String, Widget> _widgetCache = {};

  // Track which images are currently being processed to avoid duplicate work
  final Set<String> _processingImages = {};

  // Service de préchargement
  final ImagePreloaderService _preloaderService = ImagePreloaderService();

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

    // Notifier le changement d'index pour le préchargement
    _preloaderService.preloadImages(widget.list, _controller!.index);
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

  Widget tabViewChild(ImageItem image) {
    // 1. Zero Flicker Path: Check if HomeBloc already pre-rendered this image
    final cachedImage = SmartCropper.getProcessedImage(image.imageIdent);
    if (cachedImage != null) {
      // Trigger capture if bytes are not yet cached (non-blocking)
      if (SmartCropper.getRenderedBytes(image.imageIdent) == null) {
        unawaited(Future.microtask(
            () => _captureRenderedImage(cachedImage, image.imageIdent)));
      }
      return _buildSmartCroppedImageWidget(cachedImage);
    }

    // 2. Transition Path: Show standard and fade in smart crop later
    return Stack(
      fit: StackFit.expand,
      children: [
        // Level 1: Standard BoxFit.cover image (always present)
        _buildStandardImageWidget(image),

        // Level 2: Smart cropped image (fades in when ready)
        if (image.smartCropResult != null)
          FutureBuilder<ui.Image>(
            key: ValueKey(
                '${image.url}_${image.smartCropResult!.bestCrop.strategy}'),
            future: _loadAndCropImage(image),
            builder: (context, snapshot) {
              final bool isReady = snapshot.hasData;

              // Double check if it got cached while we were waiting
              if (isReady) {
                SmartCropper.cacheProcessedImage(
                    image.imageIdent, snapshot.data!);
                // Trigger capture of the rendered image non-blockingly
                if (SmartCropper.getRenderedBytes(image.imageIdent) == null) {
                  unawaited(Future.microtask(() =>
                      _captureRenderedImage(snapshot.data!, image.imageIdent)));
                }
              }

              return Stack(
                fit: StackFit.expand,
                children: [
                  AnimatedOpacity(
                    opacity: isReady ? 1.0 : 0.0,
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.easeIn,
                    child: isReady
                        ? _buildSmartCroppedImageWidget(snapshot.data!)
                        : const SizedBox.expand(),
                  ),
                  if (!isReady)
                    Center(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.black26,
                          shape: BoxShape.circle,
                        ),
                        child: const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor:
                                AlwaysStoppedAnimation<Color>(Colors.white70),
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
      ],
    );
  }

  Future<ui.Image> _loadAndCropImage(ImageItem image) async {
    final result = image.smartCropResult!;
    final sourceImage = await ImageUtils.loadImageFromUrl(image.url);
    if (sourceImage == null) throw Exception('Failed to load source image');

    final screenSize = ScreenUtils.getPhysicalScreenSize();
    final targetSize = ScreenUtils.calculateTargetSize(
      ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
      screenSize.width / screenSize.height,
      maxDimension: math.max(screenSize.width, screenSize.height).round(),
    );

    return await SmartCropper.applyCropAndResize(
      sourceImage,
      result.bestCrop,
      targetSize,
    );
  }

  /// Captures the carousel render at physical screen resolution and caches the bytes.
  ///
  /// Replicates the exact same aspect-fit drawImageRect logic used in
  /// [_SmartCroppedImagePainter.paint()] so the cached bytes are pixel-perfect
  /// matches of what the user sees in the carousel.
  Future<void> _captureRenderedImage(
      ui.Image croppedImage, String imageIdent) async {
    try {
      final screenSize = ScreenUtils.getPhysicalScreenSize();
      final width = screenSize.width;
      final height = screenSize.height;

      if (width <= 0 || height <= 0) return;

      // Replicate the aspect-fit logic from _SmartCroppedImagePainter.paint()
      final imageAspectRatio = croppedImage.width / croppedImage.height;
      final containerAspectRatio = width / height;

      double drawWidth, drawHeight;
      double offsetX = 0, offsetY = 0;

      if (imageAspectRatio > containerAspectRatio) {
        // Image is wider than container — fit to width, letterbox top/bottom
        drawWidth = width;
        drawHeight = drawWidth / imageAspectRatio;
        offsetY = (height - drawHeight) / 2;
      } else {
        // Image is taller than container — fit to height, letterbox left/right
        drawHeight = height;
        drawWidth = drawHeight * imageAspectRatio;
        offsetX = (width - drawWidth) / 2;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

      // Fill background with black (letterbox bars)
      canvas.drawRect(
        Rect.fromLTWH(0, 0, width, height),
        Paint()..color = const Color(0xFF000000),
      );

      final destRect = Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight);
      final srcRect = Rect.fromLTWH(
          0, 0, croppedImage.width.toDouble(), croppedImage.height.toDouble());

      canvas.drawImageRect(croppedImage, srcRect, destRect, Paint());

      final picture = recorder.endRecording();
      final renderedImage =
          await picture.toImage(width.round(), height.round());

      final byteData =
          await renderedImage.toByteData(format: ui.ImageByteFormat.png);
      renderedImage.dispose();

      if (byteData != null) {
        SmartCropper.cacheRenderedBytes(
            imageIdent, byteData.buffer.asUint8List());
      }
    } catch (e) {
      // Non-blocking — silently ignore errors to avoid impacting carousel UX
      debugPrint('_captureRenderedImage error for $imageIdent: $e');
    }
  }

  Widget _buildStandardImageWidget(ImageItem image) {
    return Image.network(
      image.url,
      fit: BoxFit.cover,
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          color: Colors.black87,
          child: Center(
            child: CircularProgressIndicator(
              valueColor: const AlwaysStoppedAnimation<Color>(Colors.white54),
              strokeWidth: 2,
            ),
          ),
        );
      },
      errorBuilder: (context, error, stackTrace) => Container(
        color: Colors.black87,
        child: const Center(
          child: Icon(Icons.error_outline, color: Colors.white24, size: 48),
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
    if (widget.childrenCount != _numOfTab || _pageController == null) {
      int oldIndex = _controller?.index ?? 0;

      // Clear cache when image list changes (e.g., date change)
      _clearCacheIfNeeded();

      _numOfTab = widget.childrenCount;

      // Dispose old controllers if they exist
      if (_controller != null) {
        _controller!.removeListener(this._onChange);
        _controller!.dispose();
      }

      if (_pageController != null) {
        _pageController!.dispose();
      }

      _controller =
          new TabController(length: widget.childrenCount, vsync: this);
      _controller!.addListener(this._onChange);

      // Adjust index if it's out of bounds
      if (oldIndex >= widget.childrenCount) {
        // If old index is out of bounds, go to last item
        _controller!.index = widget.childrenCount - 1;
      } else {
        _controller!.index = oldIndex;
      }

      _pageController = PageController(initialPage: _controller!.index);
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
        return tabViewChild(widget.list[index]);
      },
    );
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
      // Image is wider than container - fit to width to prevent cropping
      drawWidth = size.width;
      drawHeight = drawWidth / imageAspectRatio;
      offsetY = (size.height - drawHeight) / 2;
    } else {
      // Image is taller than container - fit to height to prevent cropping
      drawHeight = size.height;
      drawWidth = drawHeight * imageAspectRatio;
      offsetX = (size.width - drawWidth) / 2;
    }

    final destRect = Rect.fromLTWH(offsetX, offsetY, drawWidth, drawHeight);
    final srcRect =
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());

    canvas.drawImageRect(image, srcRect, destRect, Paint());
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _SmartCroppedImagePainter ||
        oldDelegate.image != image;
  }
}
