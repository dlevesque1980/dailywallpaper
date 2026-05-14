import 'dart:async';
import 'dart:ui' as ui;
import 'dart:typed_data';

import 'models/crop_coordinates.dart';
import 'models/crop_result.dart';
import 'models/crop_settings.dart';
import 'services/image_processor.dart';
import 'services/crop_analyzer_service.dart';
import 'services/crop_cache_service.dart';
import 'services/device_service.dart';

/// Coordinator class for intelligent image cropping.
/// 
/// Refactored to delegate logic to specialized services.
class SmartCropper {
  static final ImageProcessor _processor = ImageProcessor();
  static final CropAnalyzerService _analyzer = CropAnalyzerService();
  static final CropCacheService _cache = CropCacheService();
  static final DeviceService _device = DeviceService();

  // Memory cache for processed images to avoid flickering (delegated to CacheService)
  static void cacheProcessedImage(String key, ui.Image image) => _cache.cacheProcessedImage(key, image);
  static ui.Image? getProcessedImage(String key) => _cache.getProcessedImage(key);

  // Rendered bytes cache (delegated to CacheService)
  static void cacheRenderedBytes(String key, Uint8List bytes) => _cache.cacheRenderedBytes(key, bytes);
  static Uint8List? getRenderedBytes(String key) => _cache.getRenderedBytes(key);
  static void clearRenderedBytesCache() => _cache.clearRenderedBytesCache();

  /// Gets a cached crop if available
  static Future<CropCoordinates?> getCachedCrop(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
  ) => _cache.getCachedCrop(imageUrl, targetSize, settings);

  /// Analyzes an image and returns the best crop coordinates
  static Future<CropResult> analyzeCrop(
    String imageUrl,
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    // 1. Check cache
    final cached = await _cache.getCachedCrop(imageUrl, targetSize, settings);
    if (cached != null) {
      return CropResult(
        bestCrop: cached,
        allScores: [],
        processingTime: Duration.zero,
        fromCache: true,
        performanceMetrics: PerformanceMetrics.empty(),
        analyzerMetadata: const {'source': 'cache'},
        scoringBreakdown: const {},
      );
    }

    // 2. Perform analysis
    final capability = await _device.getDeviceCapability();
    final result = await _analyzer.analyzeCrop(
      imageUrl: imageUrl,
      image: image,
      targetSize: targetSize,
      settings: settings,
      deviceCapability: capability,
    );

    // 3. Save to cache if successful
    if (result.success && !result.fromCache) {
      unawaited(_cache.cacheCrop(imageUrl, targetSize, settings, result.bestCrop));
    }

    return result;
  }

  /// Applies crop coordinates to an image
  static Future<ui.Image> applyCrop(
    ui.Image sourceImage,
    CropCoordinates coordinates,
  ) => _processor.applyCrop(sourceImage, coordinates);

  /// Applies crop and resizes in one operation
  static Future<ui.Image> applyCropAndResize(
    ui.Image sourceImage,
    CropCoordinates coordinates,
    ui.Size targetSize,
  ) => _processor.applyCropAndResize(sourceImage, coordinates, targetSize);

  /// Full pipeline: analyze + apply
  static Future<ProcessedImageResult> processImage(
    String imageUrl,
    ui.Image sourceImage,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    final cropResult = await analyzeCrop(imageUrl, sourceImage, targetSize, settings);
    final processedImage = await applyCropAndResize(sourceImage, cropResult.bestCrop, targetSize);

    return ProcessedImageResult(
      image: processedImage,
      cropResult: cropResult,
      success: cropResult.success,
      error: cropResult.analyzerMetadata['error'] as String?,
    );
  }

  /// Cache management
  static Future<int> clearCache() => _cache.clearCache();
  static Future<int> invalidateImageCache(String imageUrl) => _cache.invalidateImageCache(imageUrl);
  static Future<Map<String, dynamic>> getCacheStats() => _cache.getStats();

  /// Memory and capability
  static int estimateMemoryUsage(ui.Image image, ui.Size targetSize) => 
      _device.estimateMemoryUsage(image, targetSize);
  
  static bool shouldProcessImage(ui.Image image, ui.Size targetSize, {int maxMemoryMB = 100}) {
    final usage = estimateMemoryUsage(image, targetSize);
    return usage <= (maxMemoryMB * 1024 * 1024);
  }

  static Future<void> close() async {
    await _cache.close();
    await _analyzer.close();
    _device.clearCache();
  }
}

/// Result of a complete image processing operation
class ProcessedImageResult {
  final ui.Image image;
  final CropResult cropResult;
  final bool success;
  final String? error;

  const ProcessedImageResult({
    required this.image,
    required this.cropResult,
    required this.success,
    this.error,
  });
}
