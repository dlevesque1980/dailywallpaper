import 'dart:ui' as ui;
import 'dart:async';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/services/image_preloader.dart';

class FakeImagePreloaderService implements ImagePreloader {
  int preloadCallCount = 0;
  List<ImageItem> lastPreloadedImages = [];
  int lastPreloadedIndex = -1;

  @override
  int currentIndex = 0;

  @override
  List<ImageItem> currentImages = [];

  @override
  Future<void> preloadImages(List<ImageItem> images, int currentIndex) async {
    preloadCallCount++;
    lastPreloadedImages = images;
    lastPreloadedIndex = currentIndex;
    currentImages = images;
    this.currentIndex = currentIndex;
  }

  int preloadCurrentImageWithCropCallCount = 0;
  ImageItem? lastPreloadedImage;
  bool shouldTimeout = false;

  @override
  Future<void> preloadCurrentImageWithCrop(ImageItem imageItem) async {
    preloadCurrentImageWithCropCallCount++;
    lastPreloadedImage = imageItem;
    if (shouldTimeout) {
      throw TimeoutException('Simulated timeout');
    }
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
  Future<ui.Image?>? getLoadingTask(ImageItem imageItem) => null;

  @override
  Future<ui.Image?>? getProcessingTask(ImageItem imageItem) => null;

  int clearCacheCallCount = 0;

  @override
  void clearCache() {
    clearCacheCallCount++;
  }
}
