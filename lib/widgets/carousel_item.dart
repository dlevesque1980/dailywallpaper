import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/features/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';

class CarouselItem extends StatelessWidget {
  final ImageItem image;

  const CarouselItem({Key? key, required this.image}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
    final imageCache = ImageCacheServiceImpl();
    
    var sourceImage = await imageCache.loadSourceImage(image.imageIdent);
    if (sourceImage == null) {
      sourceImage = await imageCache.loadImageFromUrl(image.url);
    }
    
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

  Future<void> _captureRenderedImage(
      ui.Image croppedImage, String imageIdent) async {
    try {
      final screenSize = ScreenUtils.getPhysicalScreenSize();
      final width = screenSize.width;
      final height = screenSize.height;

      if (width <= 0 || height <= 0) return;

      final imageAspectRatio = croppedImage.width / croppedImage.height;
      final containerAspectRatio = width / height;

      double drawWidth, drawHeight;
      double offsetX = 0, offsetY = 0;

      if (imageAspectRatio > containerAspectRatio) {
        drawWidth = width;
        drawHeight = drawWidth / imageAspectRatio;
        offsetY = (height - drawHeight) / 2;
      } else {
        drawHeight = height;
        drawWidth = drawHeight * imageAspectRatio;
        offsetX = (width - drawWidth) / 2;
      }

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);

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
