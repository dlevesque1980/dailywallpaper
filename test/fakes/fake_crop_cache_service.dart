import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'dart:ui' as ui;

class FakeCropCacheService {
  CropCoordinates? cachedCrop;
  int cacheCallCount = 0;
  int getCacheCallCount = 0;
  int clearCallCount = 0;

  Future<CropCoordinates?> getCachedCrop(String imageUrl, ui.Size targetSize, String settingsIdent) async {
    getCacheCallCount++;
    return cachedCrop;
  }

  Future<void> cacheCrop(String imageUrl, ui.Size targetSize, String settingsIdent, CropCoordinates coordinates) async {
    cacheCallCount++;
    cachedCrop = coordinates;
  }

  Future<void> clearCache() async {
    clearCallCount++;
    cachedCrop = null;
  }
}
