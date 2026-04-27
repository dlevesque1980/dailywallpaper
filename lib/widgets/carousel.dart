import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_preferences.dart';
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
    // Check if we have a cached widget first
    final cacheKey = '${image.url}_${image.imageIdent}';
    if (_widgetCache.containsKey(cacheKey)) {
      return _widgetCache[cacheKey]!;
    }

    return FutureBuilder<Widget>(
      future: _buildImageWidgetWithCache(image),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show loading state during crop processing with optimized placeholder
          return _buildPlaceholderWidget(image);
        } else if (snapshot.hasError) {
          debugPrint(
              'Error building image widget for ${image.url}: ${snapshot.error}');
          // Fallback to standard cropping on error
          return _buildStandardImageWidget(image);
        } else {
          final widget = snapshot.data ?? _buildStandardImageWidget(image);
          // Cache the built widget for reuse
          _widgetCache[cacheKey] = widget;
          return widget;
        }
      },
    );
  }

  /// Build optimized placeholder widget
  Widget _buildPlaceholderWidget(ImageItem image) {
    return Container(
      color: Colors.grey[900],
      child: Stack(
        children: [
          // Low-quality placeholder image
          Container(
            decoration: BoxDecoration(
              image: DecorationImage(
                image: NetworkImage(image.url),
                fit: BoxFit.cover,
                colorFilter: ColorFilter.mode(
                  Colors.black.withValues(alpha: 0.3),
                  BlendMode.darken,
                ),
              ),
            ),
          ),
          // Loading indicator
          Container(
            alignment: Alignment.center,
            child: CircularProgressIndicator(
              backgroundColor: Colors.black26,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
            ),
          ),
        ],
      ),
    );
  }

  /// Build image widget with caching and lazy loading optimization
  Future<Widget> _buildImageWidgetWithCache(ImageItem image) async {
    final cacheKey = '${image.url}_${image.imageIdent}';

    // Vérifier d'abord le service de préchargement
    final preloadedImage = _preloaderService.getProcessedImage(image);
    if (preloadedImage != null) {
      debugPrint('Utilisation image préchargée pour ${image.imageIdent}');
      return _buildSmartCroppedImageWidget(preloadedImage);
    }

    // Vérifier si on a une image brute préchargée
    final rawPreloadedImage = _preloaderService.getPreloadedImage(image);
    if (rawPreloadedImage != null) {
      debugPrint('Utilisation image brute préchargée pour ${image.imageIdent}');
      // Traiter rapidement l'image préchargée
      return _buildImageWidgetFromPreloaded(image, rawPreloadedImage);
    }

    // Check if we're already processing this image
    if (_processingImages.contains(cacheKey)) {
      // Wait a bit and return cached result if available
      await Future.delayed(Duration(milliseconds: 100));
      if (_imageCache.containsKey(cacheKey)) {
        return _buildSmartCroppedImageWidget(_imageCache[cacheKey]!);
      }
    }

    // Check if we have a cached processed image
    if (_imageCache.containsKey(cacheKey)) {
      return _buildSmartCroppedImageWidget(_imageCache[cacheKey]!);
    }

    // Mark as processing
    _processingImages.add(cacheKey);

    try {
      final result = await _buildImageWidget(image);
      return result;
    } finally {
      _processingImages.remove(cacheKey);
    }
  }

  Future<Widget> _buildImageWidget(ImageItem image) async {
    try {
      // Check if smart crop is enabled
      final isSmartCropEnabled =
          await SmartCropPreferences.isSmartCropEnabled();

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
        maxDimension: screenSize.width > screenSize.height
            ? screenSize.width.round()
            : screenSize.height.round(),
      );

      // Process image with smart crop
      final result = await SmartCropper.processImage(
        image.url,
        sourceImage,
        targetSize,
        cropSettings,
      );

      if (result.success) {
        // Cache the processed image for reuse
        final cacheKey = '${image.url}_${image.imageIdent}';
        _imageCache[cacheKey] = result.image;

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

  /// Construit un widget à partir d'une image préchargée
  Future<Widget> _buildImageWidgetFromPreloaded(
      ImageItem image, ui.Image preloadedImage) async {
    try {
      final isSmartCropEnabled =
          await SmartCropPreferences.isSmartCropEnabled();

      if (!isSmartCropEnabled) {
        return _buildSmartCroppedImageWidget(preloadedImage);
      }

      final cropSettings = await SmartCropPreferences.getCropSettings();
      final screenSize = ScreenUtils.getPhysicalScreenSize();

      final targetSize = ScreenUtils.calculateTargetSize(
        ui.Size(
            preloadedImage.width.toDouble(), preloadedImage.height.toDouble()),
        screenSize.width / screenSize.height,
        maxDimension: screenSize.width > screenSize.height
            ? screenSize.width.round()
            : screenSize.height.round(),
      );

      final result = await SmartCropper.processImage(
        image.url,
        preloadedImage,
        targetSize,
        cropSettings,
      );

      if (result.success) {
        final cacheKey = '${image.url}_${image.imageIdent}';
        _imageCache[cacheKey] = result.image;
        return _buildSmartCroppedImageWidget(result.image);
      } else {
        return _buildSmartCroppedImageWidget(preloadedImage);
      }
    } catch (e) {
      debugPrint('Erreur traitement image préchargée: $e');
      return _buildSmartCroppedImageWidget(preloadedImage);
    }
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

      // Clear cache when image list changes (e.g., date change)
      _clearCacheIfNeeded();

      _numOfTab = widget.childrenCount;

      // Dispose old controller if it exists
      if (_controller != null) {
        _controller!.removeListener(this._onChange);
        _controller!.dispose();
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
