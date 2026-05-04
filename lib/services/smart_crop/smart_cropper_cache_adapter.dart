import 'dart:typed_data';
import 'dart:ui' as ui;
import 'crop_render_cache.dart';
import 'smart_cropper.dart';

/// Adapter that delegates to the static SmartCropper class.
class SmartCropperCacheAdapter implements CropRenderCache {
  const SmartCropperCacheAdapter();

  @override
  Uint8List? getRenderedBytes(String imageIdent) =>
      SmartCropper.getRenderedBytes(imageIdent);

  @override
  ui.Image? getProcessedImage(String imageIdent) =>
      SmartCropper.getProcessedImage(imageIdent);
}
