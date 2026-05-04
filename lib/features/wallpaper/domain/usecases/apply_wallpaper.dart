import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_preferences.dart';
import 'package:dailywallpaper/services/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_type_detector.dart';
import 'package:dailywallpaper/services/smart_crop/crop_render_cache.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper_cache_adapter.dart';
import 'package:dailywallpaper/services/wallpaper/wallpaper_service.dart';
import 'package:flutter/foundation.dart';

class ApplyWallpaperUseCase {
  final WallpaperService _wallpaperService;
  final PreferencesReader _prefHelper;
  final CropRenderCache _cropCache;

  ApplyWallpaperUseCase({
    WallpaperService? wallpaperService,
    PreferencesReader? prefHelper,
    CropRenderCache? cropCache,
  })  : _wallpaperService = wallpaperService ?? WallpaperServiceImpl(),
        _prefHelper = prefHelper ?? PrefHelperAdapter(),
        _cropCache = cropCache ?? const SmartCropperCacheAdapter();

  Future<String?> call(ImageItem image) async {
    var setLocked = await _prefHelper.getBoolWithDefault(sp_IncludeLockWallpaper, true);
    String? message;

    try {
      final isSmartCropEnabled = await SmartCropPreferences.isSmartCropEnabled();

      if (isSmartCropEnabled) {
        debugPrint('Smart crop is enabled, processing image for wallpaper');

        final renderedBytes = _cropCache.getRenderedBytes(image.imageIdent);
        if (renderedBytes != null) {
          debugPrint('Using captured carousel render bytes for wallpaper (${renderedBytes.length} bytes)');
          if (setLocked) {
            message = await _wallpaperService.setBothWallpaperFromBytes(renderedBytes);
          } else {
            message = await _wallpaperService.setSystemWallpaperFromBytes(renderedBytes);
          }
          return message;
        }

        final baseCropSettings = await SmartCropPreferences.getCropSettings();
        final optimizedSettings = _getOptimizedCropSettings(image, baseCropSettings);
        final screenSize = ScreenUtils.getPhysicalScreenSize();

        final sourceImage = await ImageUtils.loadImageFromUrl(image.url);
        if (sourceImage != null) {
          final targetSize = ScreenUtils.calculateTargetSize(
            ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
            screenSize.width / screenSize.height,
            maxDimension: math.max(screenSize.width, screenSize.height).round(),
          );

          final cachedCrop = await SmartCropper.getCachedCrop(image.url, targetSize, optimizedSettings);
          if (cachedCrop != null) {
            final croppedImage = await SmartCropper.applyCropAndResize(
              sourceImage,
              cachedCrop,
              targetSize,
            );

            final imageBytes = await ImageUtils.imageToBytes(croppedImage);

            if (imageBytes != null) {
              if (setLocked) {
                message = await _wallpaperService.setBothWallpaperFromBytes(imageBytes);
              } else {
                message = await _wallpaperService.setSystemWallpaperFromBytes(imageBytes);
              }
              return message;
            }
          } else {
            final processedResult = await SmartCropper.processImage(
              image.url,
              sourceImage,
              targetSize,
              optimizedSettings,
            );

            if (processedResult.success) {
              final imageBytes = await ImageUtils.imageToBytes(processedResult.image);

              if (imageBytes != null) {
                if (setLocked) {
                  message = await _wallpaperService.setBothWallpaperFromBytes(imageBytes);
                } else {
                  message = await _wallpaperService.setSystemWallpaperFromBytes(imageBytes);
                }
                return message;
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing smart crop for wallpaper: $e');
    }

    // Fallback
    if (setLocked) {
      message = await _wallpaperService.setBothWallpaper(image.url);
    } else {
      message = await _wallpaperService.setSystemWallpaper(image.url);
    }

    return message;
  }

  dynamic _getOptimizedCropSettings(ImageItem imageItem, dynamic baseSettings) {
    String? imageSource;
    if (imageItem.source.toLowerCase().contains('bing')) {
      imageSource = 'bing';
    } else if (imageItem.source.toLowerCase().contains('nasa')) {
      imageSource = 'nasa';
    } else if (imageItem.source.toLowerCase().contains('pexels')) {
      imageSource = 'pexels';
    }

    switch (imageSource) {
      case 'bing':
        return ImageTypeDetector.getBingOptimizedSettings();
      case 'nasa':
        return ImageTypeDetector.getNASAOptimizedSettings();
      case 'pexels':
        return ImageTypeDetector.getPexelsOptimizedSettings();
      default:
        return baseSettings;
    }
  }
}
