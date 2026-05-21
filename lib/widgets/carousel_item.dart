import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:io';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';

class CarouselItem extends StatefulWidget {
  final ImageItem image;

  const CarouselItem({Key? key, required this.image}) : super(key: key);

  @override
  State<CarouselItem> createState() => _CarouselItemState();
}

class _CarouselItemState extends State<CarouselItem> {
  ui.Image? _processedImage;
  bool _isLoading = false;
  String? _loadedImageIdent;
  StreamSubscription<String>? _processedImageSub;

  @override
  void initState() {
    super.initState();
    _checkCacheAndLoad();
    // Subscribe to know when background crop processing finishes for THIS image
    _processedImageSub =
        SmartCropper.processedImageStream.listen(_onProcessedImageReady);
  }

  @override
  void didUpdateWidget(CarouselItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.image.imageIdent != widget.image.imageIdent) {
      _checkCacheAndLoad();
    }
  }

  @override
  void dispose() {
    _processedImageSub?.cancel();
    super.dispose();
  }

  void _onProcessedImageReady(String imageIdent) {
    if (imageIdent != widget.image.imageIdent) return;
    if (_processedImage != null) return; // Already showing processed image

    // First try the in-memory cache (populated by CropImageResolver)
    final memCached = SmartCropper.getProcessedImage(imageIdent);
    if (memCached != null && mounted) {
      setState(() {
        _processedImage = memCached;
        _loadedImageIdent = imageIdent;
      });
      return;
    }

    // Fallback: reload from disk (in case it was saved without caching in memory)
    _isLoading = false; // Reset guard so _loadFromDisk can run again
    _loadFromDisk(imageIdent);
  }

  void _checkCacheAndLoad() {
    final cachedImage = SmartCropper.getProcessedImage(widget.image.imageIdent);
    if (cachedImage != null) {
      setState(() {
        _processedImage = cachedImage;
        _loadedImageIdent = widget.image.imageIdent;
      });
      return;
    }

    _processedImage = null;
    _loadedImageIdent = widget.image.imageIdent;
    _loadFromDisk(widget.image.imageIdent);
  }

  Future<void> _loadFromDisk(String imageIdent) async {
    if (_isLoading) return;
    _isLoading = true;
    try {
      final imageCache = ImageCacheServiceImpl();
      final image = await imageCache.loadProcessedImage(imageIdent);
      if (image != null && mounted && _loadedImageIdent == imageIdent) {
        SmartCropper.cacheProcessedImage(imageIdent, image);
        setState(() {
          _processedImage = image;
        });
      }
    } catch (_) {
      // Ignore
    } finally {
      _isLoading = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasProcessed = _processedImage != null;

    return Stack(
      fit: StackFit.expand,
      children: [
        // Level 1: Standard BoxFit.cover image (always present)
        _buildStandardImageWidget(widget.image),

        // Level 2: Smart cropped image (fades in when loaded from disk)
        AnimatedOpacity(
          opacity: hasProcessed ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 600),
          curve: Curves.easeIn,
          child: hasProcessed
              ? _buildSmartCroppedImageWidget(_processedImage!)
              : const SizedBox.expand(),
        ),
      ],
    );
  }



  Widget _buildStandardImageWidget(ImageItem image) {
    final mediaQuery = MediaQuery.of(context);
    final size = mediaQuery.size;
    final pixelRatio = mediaQuery.devicePixelRatio;
    
    // Scale image decode target to exact physical screen dimensions to avoid decoding 4K pixels in RAM.
    final cacheWidth = (size.width * pixelRatio).round();
    final cacheHeight = (size.height * pixelRatio).round();

    if (image.localSourcePath != null) {
      return Image.file(
        File(image.localSourcePath!),
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        cacheHeight: cacheHeight,
        errorBuilder: (context, error, stackTrace) =>
            _buildNetworkImage(image, cacheWidth, cacheHeight),
      );
    }
    return _buildNetworkImage(image, cacheWidth, cacheHeight);
  }

  Widget _buildNetworkImage(ImageItem image, int cacheWidth, int cacheHeight) {
    return Image.network(
      image.url,
      fit: BoxFit.cover,
      cacheWidth: cacheWidth,
      cacheHeight: cacheHeight,
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
}

class _SmartCroppedImagePainter extends CustomPainter {
  final ui.Image image;

  _SmartCroppedImagePainter(this.image);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final imageAspectRatio = image.width / image.height;
    final containerAspectRatio = size.width / size.height;

    double drawWidth, drawHeight;
    double offsetX = 0, offsetY = 0;

    if (imageAspectRatio > containerAspectRatio) {
      drawWidth = size.width;
      drawHeight = drawWidth / imageAspectRatio;
      offsetY = (size.height - drawHeight) / 2;
    } else {
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
