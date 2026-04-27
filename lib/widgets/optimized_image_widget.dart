import 'package:flutter/material.dart';
import 'dart:ui' as ui;
import 'dart:async';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/services/intelligent_cache_service.dart';

/// Widget d'image optimisé avec préchargement et cache intelligent
class OptimizedImageWidget extends StatefulWidget {
  final ImageItem imageItem;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final bool enableSmartCrop;

  const OptimizedImageWidget({
    Key? key,
    required this.imageItem,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.enableSmartCrop = true,
  }) : super(key: key);

  @override
  State<OptimizedImageWidget> createState() => _OptimizedImageWidgetState();
}

class _OptimizedImageWidgetState extends State<OptimizedImageWidget>
    with AutomaticKeepAliveClientMixin {
  final ImagePreloaderService _preloaderService = ImagePreloaderService();
  final IntelligentCacheService _cacheService = IntelligentCacheService();

  ui.Image? _displayImage;
  bool _isLoading = false;
  String? _error;

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  @override
  void didUpdateWidget(OptimizedImageWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageItem.url != widget.imageItem.url) {
      _loadImage();
    }
  }

  Future<void> _loadImage() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // 1. Vérifier le cache intelligent d'abord
      final cacheKey = _getCacheKey();
      final cachedImage = _cacheService.get(cacheKey);
      if (cachedImage != null) {
        if (mounted) {
          setState(() {
            _displayImage = cachedImage;
            _isLoading = false;
          });
        }
        return;
      }

      // 2. Vérifier le service de préchargement
      ui.Image? image;

      if (widget.enableSmartCrop) {
        image = _preloaderService.getProcessedImage(widget.imageItem);
      }

      image ??= _preloaderService.getPreloadedImage(widget.imageItem);

      if (image != null) {
        // Ajouter au cache intelligent
        _cacheService.put(cacheKey, image, priority: 2);

        if (mounted) {
          setState(() {
            _displayImage = image;
            _isLoading = false;
          });
        }
        return;
      }

      // 3. Chargement standard si pas de préchargement
      await _loadImageStandard();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadImageStandard() async {
    // Implémentation du chargement standard
    // Cette méthode sera appelée en dernier recours
    try {
      final imageProvider = NetworkImage(widget.imageItem.url);
      final imageStream = imageProvider.resolve(ImageConfiguration.empty);

      final completer = Completer<ui.Image>();
      late ImageStreamListener listener;

      listener = ImageStreamListener(
        (ImageInfo info, bool synchronousCall) {
          if (!completer.isCompleted) {
            completer.complete(info.image);
          }
          imageStream.removeListener(listener);
        },
        onError: (exception, stackTrace) {
          if (!completer.isCompleted) {
            completer.completeError(exception);
          }
          imageStream.removeListener(listener);
        },
      );

      imageStream.addListener(listener);

      final image = await completer.future;

      // Ajouter au cache
      final cacheKey = _getCacheKey();
      _cacheService.put(cacheKey, image, priority: 1);

      if (mounted) {
        setState(() {
          _displayImage = image;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  String _getCacheKey() {
    return '${widget.imageItem.url}_${widget.imageItem.imageIdent}_optimized';
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    if (_error != null) {
      return widget.errorWidget ??
          Container(
            color: Colors.grey[800],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.white54, size: 48),
                  SizedBox(height: 8),
                  Text(
                    'Erreur de chargement',
                    style: TextStyle(color: Colors.white54),
                  ),
                ],
              ),
            ),
          );
    }

    if (_displayImage != null) {
      return Container(
        child: CustomPaint(
          painter: _OptimizedImagePainter(_displayImage!, widget.fit),
          size: Size.infinite,
        ),
      );
    }

    if (_isLoading) {
      return widget.placeholder ??
          Container(
            color: Colors.grey[900],
            child: Stack(
              children: [
                // Image de fond floue pour un effet de transition
                Container(
                  decoration: BoxDecoration(
                    image: DecorationImage(
                      image: NetworkImage(widget.imageItem.url),
                      fit: BoxFit.cover,
                      colorFilter: ColorFilter.mode(
                        Colors.black.withValues(alpha: 0.5),
                        BlendMode.darken,
                      ),
                    ),
                  ),
                ),
                // Indicateur de chargement
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

    return Container(color: Colors.grey[900]);
  }
}

/// Painter optimisé pour le rendu d'images
class _OptimizedImagePainter extends CustomPainter {
  final ui.Image image;
  final BoxFit fit;

  _OptimizedImagePainter(this.image, this.fit);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0 || size.height <= 0) return;

    final imageSize = Size(image.width.toDouble(), image.height.toDouble());
    final fittedSizes = applyBoxFit(fit, imageSize, size);

    final sourceRect =
        Alignment.center.inscribe(fittedSizes.source, Offset.zero & imageSize);
    final destRect =
        Alignment.center.inscribe(fittedSizes.destination, Offset.zero & size);

    canvas.drawImageRect(image, sourceRect, destRect,
        Paint()..filterQuality = FilterQuality.high);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return oldDelegate is! _OptimizedImagePainter ||
        oldDelegate.image != image ||
        oldDelegate.fit != fit;
  }
}
