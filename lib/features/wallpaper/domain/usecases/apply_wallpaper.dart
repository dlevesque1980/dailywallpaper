import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/services/wallpaper/wallpaper_service.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper_cache_adapter.dart';
import 'package:dailywallpaper/features/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/features/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/features/smart_crop/crop_render_cache.dart';
import 'package:dailywallpaper/features/smart_crop/smart_crop_preferences.dart';
import 'package:dailywallpaper/features/smart_crop/services/crop_image_resolver.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:math' as math;

class ApplyWallpaperUseCase {
  final WallpaperService _wallpaperService;
  final PreferencesReader _prefHelper;
  final CropRenderCache _cropCache;
  final ImageCacheService _imageCache;

  ApplyWallpaperUseCase({
    WallpaperService? wallpaperService,
    PreferencesReader? prefHelper,
    CropRenderCache? cropCache,
    ImageCacheService? imageCache,
  })  : _wallpaperService = wallpaperService ?? WallpaperServiceImpl(),
        _prefHelper = prefHelper ?? PrefHelperAdapter(),
        _cropCache = cropCache ?? const SmartCropperCacheAdapter(),
        _imageCache = imageCache ?? ImageCacheServiceImpl();

  Future<String?> call(ImageItem image) async {
    final setLocked =
        await _prefHelper.getBoolWithDefault(sp_IncludeLockWallpaper, true);
    final startTime = DateTime.now();
    String? message;

    try {
      // 1. Direct path for processed PNG on disk (Option D - Zero RAM overhead)
      final appDir = await getApplicationDocumentsDirectory();
      final processedFilePath = '${appDir.path}/wallpapers/${image.imageIdent}_processed.png';
      final processedFile = File(processedFilePath);

      if (await processedFile.exists()) {
        debugPrint('Using direct filesystem path for wallpaper: $processedFilePath');
        if (setLocked) {
          message = await _wallpaperService.setBothWallpaper('file://$processedFilePath');
        } else {
          message = await _wallpaperService.setSystemWallpaper('file://$processedFilePath');
        }
        await _ensureMinAnimationDuration(startTime);
        return _normalizeMessage(message);
      }

      // 2. Fallback: Charger la source (depuis le disque, ou téléchargement si absent)
      var sourceImage = await _imageCache.loadSourceImage(image.imageIdent);
      if (sourceImage == null) {
        debugPrint('Source image not on disk, downloading from URL: ${image.url} (15s timeout)');
        sourceImage = await _imageCache.loadImageFromUrl(image.url).timeout(const Duration(seconds: 15));
        if (sourceImage != null) {
          // Sauvegarde en background
          unawaited(_imageCache.downloadAndSaveSourceImage(image.url, image.imageIdent));
        }
      }

      if (sourceImage != null) {
        final settings = await SmartCropPreferences.getCropSettings();
        final screenSize = ScreenUtils.getPhysicalScreenSize();
        final targetSize = ScreenUtils.calculateTargetSize(
          ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
          screenSize.width / screenSize.height,
          maxDimension: math.max(screenSize.width, screenSize.height).round(),
        );

        final result = await CropImageResolver.resolve(
          image: image,
          sourceImage: sourceImage,
          targetSize: targetSize,
          settings: settings,
          imageCache: _imageCache,
          allowPipeline: false,
          saveToDb: false,
        );

        if (result.isRawSource) {
          debugPrint('Using raw source image (no crop coordinates found)');
        } else {
          debugPrint('Using saved CropCoordinates to apply wallpaper without ML Kit');
        }

        // Save resolved cropped image to disk
        final savedPath = await _imageCache.saveProcessedImage(result.image, image.imageIdent);
        if (savedPath != null) {
          debugPrint('Saved resolved cropped image to $savedPath; applying directly');
          if (setLocked) {
            message = await _wallpaperService.setBothWallpaper('file://$savedPath');
          } else {
            message = await _wallpaperService.setSystemWallpaper('file://$savedPath');
          }
          await _ensureMinAnimationDuration(startTime);
          return _normalizeMessage(message);
        }
      }
    } catch (e) {
      debugPrint('Error applying wallpaper: $e');
    }

    // Default return if everything failed
    await _ensureMinAnimationDuration(startTime);
    return _normalizeMessage(message ?? 'failedToSetWallpaper');
  }



  Future<void> _ensureMinAnimationDuration(DateTime startTime) async {
    final elapsed = DateTime.now().difference(startTime);
    if (elapsed < const Duration(milliseconds: 600)) {
      await Future.delayed(const Duration(milliseconds: 600) - elapsed);
    }
  }

  String? _normalizeMessage(String? message) {
    // The setwallpaper plugin returns "Wallpaper set successfully!" (not "Success").
    // Normalise any success variant to our internal token.
    if (message == null) return null;
    if (message == 'Success' ||
        message.toLowerCase().startsWith('wallpaper set')) {
      return 'wallpaperSetSuccess';
    }
    return message;
  }
}
