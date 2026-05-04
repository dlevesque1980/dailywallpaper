import 'dart:ui' as ui;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/services/image_preloader.dart';

class FakeImagePreloaderService implements ImagePreloader {
  int preloadCallCount = 0;
  List<ImageItem> lastPreloadedImages = [];
  int lastPreloadedIndex = -1;

  @override
  Future<void> preloadImages(List<ImageItem> images, int currentIndex) async {
    preloadCallCount++;
    lastPreloadedImages = images;
    lastPreloadedIndex = currentIndex;
  }

  @override
  ui.Image? getPreloadedImage(ImageItem imageItem) => null;

  @override
  ui.Image? getProcessedImage(ImageItem imageItem) => null;

  @override
  bool isLoading(ImageItem imageItem) => false;

  @override
  bool isProcessing(ImageItem imageItem) => false;

  @override
  void clearCache() {}
}
