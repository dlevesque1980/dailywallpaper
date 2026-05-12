import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/core/preferences/pref_helper_adapter.dart';
import 'package:dailywallpaper/services/wallpaper/wallpaper_service.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper_cache_adapter.dart';
import 'package:dailywallpaper/services/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/services/smart_crop/crop_render_cache.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
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
    var setLocked = await _prefHelper.getBoolWithDefault(sp_IncludeLockWallpaper, true);
    String? message;

    try {
      final isSmartCropEnabled = await _prefHelper.getBoolWithDefault(sp_SmartCropEnabled, true);

      if (isSmartCropEnabled) {
        debugPrint('Smart crop is enabled, processing image for wallpaper');

        final renderedBytes = _cropCache.getRenderedBytes(image.imageIdent);
        if (renderedBytes != null) {
          debugPrint('Using captured carousel render bytes for wallpaper (${renderedBytes.length} bytes)');
          final startTime = DateTime.now();
          message = await _setWallpaperViaFile(renderedBytes, setLocked);
          
          await _ensureMinAnimationDuration(startTime);
          return _normalizeMessage(message);
        }

        // --- NEW: Check local processed cache ---
        final localProcessedBytes = await _imageCache.getProcessedImageBytes(image.imageIdent);
        if (localProcessedBytes != null) {
          debugPrint('Using local cached processed image for wallpaper (${localProcessedBytes.length} bytes)');
          final startTime = DateTime.now();
          message = await _setWallpaperViaFile(localProcessedBytes, setLocked);
          
          await _ensureMinAnimationDuration(startTime);
          return _normalizeMessage(message);
        }

        final baseCropSettings = await _getCropSettingsFromPrefs();
        final optimizedSettings = _getOptimizedCropSettings(image, baseCropSettings);
        final screenSize = ScreenUtils.getPhysicalScreenSize();

        // --- NEW: Try loading source from disk first ---
        var sourceImage = await _imageCache.loadSourceImage(image.imageIdent);
        if (sourceImage == null) {
          debugPrint('Source image not on disk, downloading from URL: ${image.url}');
          sourceImage = await _imageCache.loadImageFromUrl(image.url);
          if (sourceImage != null) {
            await _imageCache.downloadAndSaveSourceImage(image.url, image.imageIdent);
          }
        }

        if (sourceImage != null) {
          final targetSize = ScreenUtils.calculateTargetSize(
            ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
            screenSize.width / screenSize.height,
            maxDimension: math.max(screenSize.width, screenSize.height).round(),
          );

          final cachedCrop = await SmartCropper.getCachedCrop(image.url, targetSize, optimizedSettings);
          if (cachedCrop != null) {
            final croppedImage = await SmartCropper.applyCropAndResize(sourceImage, cachedCrop, targetSize);
            final imageBytes = await ImageUtils.imageToBytes(croppedImage);

            if (imageBytes != null) {
              final startTime = DateTime.now();
              message = await _setWallpaperViaFile(imageBytes, setLocked);
              await _ensureMinAnimationDuration(startTime);
              return _normalizeMessage(message);
            }
          } else {
            final processedResult = await SmartCropper.processImage(image.url, sourceImage, targetSize, optimizedSettings);
            if (processedResult.success) {
              final imageBytes = await ImageUtils.imageToBytes(processedResult.image);
              if (imageBytes != null) {
                final startTime = DateTime.now();
                message = await _setWallpaperViaFile(imageBytes, setLocked);
                await _ensureMinAnimationDuration(startTime);
                return _normalizeMessage(message);
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error processing smart crop for wallpaper: $e');
    }

    // Fallback
    final startTime = DateTime.now();
    if (setLocked) {
      message = await _wallpaperService.setBothWallpaper(image.url);
    } else {
      message = await _wallpaperService.setSystemWallpaper(image.url);
    }
    await _ensureMinAnimationDuration(startTime);
    return _normalizeMessage(message);
  }

  /// Sets the wallpaper by first writing the bytes to a temporary file.
  /// This avoids the TransactionTooLargeException (1MB Binder limit) 
  /// when passing large image bytes over the MethodChannel.
  Future<String?> _setWallpaperViaFile(Uint8List bytes, bool setLocked) async {
    try {
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/temp_wallpaper_${DateTime.now().millisecondsSinceEpoch}.jpg');
      await tempFile.writeAsBytes(bytes);
      
      String? message;
      final fileUri = 'file://${tempFile.path}';
      if (setLocked) {
        message = await _wallpaperService.setBothWallpaper(fileUri);
      } else {
        message = await _wallpaperService.setSystemWallpaper(fileUri);
      }
      
      // Clean up the temp file non-blockingly
      unawaited(tempFile.delete().catchError((_) => tempFile));
      
      return message;
    } catch (e) {
      debugPrint('Error in _setWallpaperViaFile: $e');
      return 'Error: $e';
    }
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
    if (message == 'Success' || message.toLowerCase().startsWith('wallpaper set')) {
      return 'wallpaperSetSuccess';
    }
    return message;
  }

  Future<CropSettings> _getCropSettingsFromPrefs() async {
    final aggIndex = await _prefHelper.getIntWithDefault(sp_SmartCropAggressiveness, CropAggressiveness.balanced.index);
    return CropSettings(
      aggressiveness: CropAggressiveness.values[aggIndex % CropAggressiveness.values.length],
      enableRuleOfThirds: await _prefHelper.getBoolWithDefault(sp_SmartCropRuleOfThirds, true),
      enableEntropyAnalysis: await _prefHelper.getBoolWithDefault(sp_SmartCropEntropyAnalysis, true),
      enableEdgeDetection: await _prefHelper.getBoolWithDefault(sp_SmartCropEdgeDetection, true),
      enableCenterWeighting: await _prefHelper.getBoolWithDefault(sp_SmartCropCenterWeighting, true),
    );
  }

  CropSettings _getOptimizedCropSettings(ImageItem imageItem, CropSettings baseSettings) {
    if (imageItem.source.toLowerCase().contains('bing')) {
       return baseSettings.copyWith(enableCenterWeighting: true, aggressiveness: CropAggressiveness.conservative);
    } else if (imageItem.source.toLowerCase().contains('nasa')) {
       return baseSettings.copyWith(enableEntropyAnalysis: true, aggressiveness: CropAggressiveness.aggressive);
    }
    return baseSettings;
  }
}
