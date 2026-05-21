import 'dart:ui' as ui;
import 'package:dailywallpaper/data/models/image_item.dart';

abstract class ImagePreloader {
  int get currentIndex;
  set currentIndex(int value);
  List<ImageItem> get currentImages;
  set currentImages(List<ImageItem> value);

  Future<void> preloadImages(List<ImageItem> images, int currentIndex);
  Future<void> preloadCurrentImageWithCrop(ImageItem imageItem);
  ui.Image? getPreloadedImage(ImageItem imageItem);
  ui.Image? getProcessedImage(ImageItem imageItem);
  bool isLoading(ImageItem imageItem);
  bool isProcessing(ImageItem imageItem);
  Future<ui.Image?>? getLoadingTask(ImageItem imageItem);
  Future<ui.Image?>? getProcessingTask(ImageItem imageItem);
  void clearCache();
}
