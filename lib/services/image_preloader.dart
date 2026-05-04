import 'dart:ui' as ui;
import 'package:dailywallpaper/data/models/image_item.dart';

abstract class ImagePreloader {
  Future<void> preloadImages(List<ImageItem> images, int currentIndex);
  ui.Image? getPreloadedImage(ImageItem imageItem);
  ui.Image? getProcessedImage(ImageItem imageItem);
  bool isLoading(ImageItem imageItem);
  bool isProcessing(ImageItem imageItem);
  void clearCache();
}
