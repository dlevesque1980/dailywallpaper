import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:dailywallpaper/services/smart_crop/crop_render_cache.dart';

class FakeCropRenderCache implements CropRenderCache {
  final Map<String, Uint8List> _renderedBytes = {};
  final Map<String, ui.Image> _processedImages = {};

  void setRenderedBytes(String imageIdent, Uint8List bytes) {
    _renderedBytes[imageIdent] = bytes;
  }

  void setProcessedImage(String imageIdent, ui.Image image) {
    _processedImages[imageIdent] = image;
  }

  void clearAll() {
    _renderedBytes.clear();
    _processedImages.clear();
  }

  @override
  Uint8List? getRenderedBytes(String imageIdent) => _renderedBytes[imageIdent];

  @override
  ui.Image? getProcessedImage(String imageIdent) => _processedImages[imageIdent];
}
