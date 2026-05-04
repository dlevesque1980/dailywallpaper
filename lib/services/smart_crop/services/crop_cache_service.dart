import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:dailywallpaper/services/smart_crop/cache/crop_cache_manager.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';

class CropCacheService {
  final Map<String, ui.Image> _processedCache = {};
  final Map<String, Uint8List> _renderedBytesCache = {};
  final CropCacheManager _persistentCache = CropCacheManager();

  void cacheProcessedImage(String key, ui.Image image) {
    _processedCache[key] = image;
  }

  ui.Image? getProcessedImage(String key) {
    return _processedCache[key];
  }

  void cacheRenderedBytes(String key, Uint8List bytes) {
    _renderedBytesCache[key] = bytes;
  }

  Uint8List? getRenderedBytes(String key) {
    return _renderedBytesCache[key];
  }

  void clearRenderedBytesCache() {
    _renderedBytesCache.clear();
  }

  Future<CropCoordinates?> getCachedCrop(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    return await _persistentCache.getCachedCrop(imageUrl, targetSize, settings);
  }

  Future<bool> cacheCrop(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
    CropCoordinates coordinates,
  ) async {
    return await _persistentCache.cacheCrop(imageUrl, targetSize, settings, coordinates);
  }

  Future<int> invalidateImageCache(String imageUrl) async {
    return await _persistentCache.invalidateImageCache(imageUrl);
  }

  Future<int> invalidateSettingsCache(CropSettings newSettings) async {
    return await _persistentCache.invalidateSettingsCache(newSettings);
  }

  Future<int> clearCache() async {
    _processedCache.clear();
    _renderedBytesCache.clear();
    return await _persistentCache.clearCache();
  }

  Future<Map<String, dynamic>> getStats() async {
    final cacheStats = await _persistentCache.getStats();
    final hitRateStats = await _persistentCache.getHitRateStats();

    return {
      'crop_cache_size': cacheStats.totalEntries,
      'crop_cache_size_mb': cacheStats.totalSizeMB,
      'processed_cache_size': _processedCache.length,
      'rendered_bytes_cache_size': _renderedBytesCache.length,
      'average_access_count': cacheStats.averageAccessCount,
      'hit_rate_percentage': hitRateStats.hitRatePercentage,
    };
  }

  Future<void> close() async {
    await _persistentCache.close();
    _processedCache.clear();
    _renderedBytesCache.clear();
  }
}
