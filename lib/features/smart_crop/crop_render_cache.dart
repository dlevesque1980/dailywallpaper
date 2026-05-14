import 'dart:typed_data';
import 'dart:ui' as ui;

/// Interface for accessing image crop and render caches.
/// Used to decouple the application from the static SmartCropper class.
abstract interface class CropRenderCache {
  /// Retrieves rendered bytes from the memory cache (captured from carousel).
  /// Used for WYSIWYG wallpaper application.
  Uint8List? getRenderedBytes(String imageIdent);

  /// Retrieves a processed (cropped) image from the memory cache.
  ui.Image? getProcessedImage(String imageIdent);
}
