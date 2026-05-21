import 'dart:ui' as ui;
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';

class CropResolveResult {
  final ui.Image image;
  final bool isFromMemory;
  final bool isFromDisk;
  final bool isFromCoords;
  final bool isFromPipeline;
  final bool isRawSource;

  CropResolveResult({
    required this.image,
    this.isFromMemory = false,
    this.isFromDisk = false,
    this.isFromCoords = false,
    this.isFromPipeline = false,
    this.isRawSource = false,
  });
}

class CropImageResolver {
  /// Retourne l'image croppée + met à jour ImageItem (smartCropResult, paths, cropResultJson).
  static Future<CropResolveResult> resolve({
    required ImageItem image,
    required ui.Image sourceImage,
    required ui.Size targetSize,
    required CropSettings settings,
    ImageCacheService? imageCache,
    bool allowPipeline = true,
    bool saveToDb = true,
  }) async {
    final imageIdent = image.imageIdent;

    // 1. Image PNG traitée en mémoire
    final memImage = SmartCropper.getProcessedImage(imageIdent);
    if (memImage != null) {
      return CropResolveResult(image: memImage, isFromMemory: true);
    }

    // 2. Image PNG traitée sur disque
    if (imageCache != null) {
      final diskImage = await imageCache.loadProcessedImage(imageIdent);
      if (diskImage != null) {
        SmartCropper.cacheProcessedImage(imageIdent, diskImage);
        return CropResolveResult(image: diskImage, isFromDisk: true);
      }
    }

    // 3. CropCoordinates (court-circuit sans pipeline d'analyse)
    CropResult? savedResult;

    // a. image.cropResultJson (ImageItem / SQLite)
    if (image.cropResultJson != null) {
      try {
        savedResult = CropResult.deserialize(image.cropResultJson!);
      } catch (_) {}
    }

    // b. imageCache.loadCropResultJson(imageIdent) (fichier JSON disque)
    if (savedResult == null && imageCache != null) {
      final diskJson = await imageCache.loadCropResultJson(imageIdent);
      if (diskJson != null) {
        try {
          savedResult = CropResult.deserialize(diskJson);
        } catch (_) {}
      }
    }

    // c. SmartCropper.getCachedCrop(url, targetSize, settings) (SQLite)
    if (savedResult == null) {
      final cachedCrop =
          await SmartCropper.getCachedCrop(image.url, targetSize, settings);
      if (cachedCrop != null) {
        savedResult = CropResult(
          bestCrop: cachedCrop,
          allScores: [],
          processingTime: Duration.zero,
          fromCache: true,
          performanceMetrics: PerformanceMetrics.empty(),
          analyzerMetadata: const {'source': 'cache'},
          scoringBreakdown: const {},
        );
      }
    }

    if (savedResult != null) {
      // Hydrater l'ImageItem
      image.smartCropResult = savedResult;
      image.cropResultJson = savedResult.serialize();

      final croppedImage = await SmartCropper.applyCropAndResize(
          sourceImage, savedResult.bestCrop, targetSize);
      SmartCropper.cacheProcessedImage(imageIdent, croppedImage);

      if (imageCache != null) {
        final processedPath = await imageCache.saveProcessedImage(croppedImage, imageIdent);
        image.localProcessedPath = processedPath;
        
        if (saveToDb) {
          final dbHelper = DatabaseHelper();
          await dbHelper.updateImagePaths(
            imageIdent,
            localProcessedPath: processedPath,
            cropResultJson: image.cropResultJson,
          );
        }
      }

      return CropResolveResult(image: croppedImage, isFromCoords: true);
    }

    // 4. Pipeline d'analyse complet
    if (!allowPipeline) {
      return CropResolveResult(image: sourceImage, isRawSource: true);
    }

    final processedResult = await SmartCropper.processImage(
        image.url, sourceImage, targetSize, settings);

    // Persister les coordonnées
    image.smartCropResult = processedResult.cropResult;
    image.cropResultJson = processedResult.cropResult.serialize();

    SmartCropper.cacheProcessedImage(imageIdent, processedResult.image);

    if (imageCache != null) {
      final processedPath = await imageCache.saveProcessedImage(processedResult.image, imageIdent);
      await imageCache.saveCropResult(processedResult.cropResult, imageIdent);
      image.localProcessedPath = processedPath;

      if (saveToDb) {
        final dbHelper = DatabaseHelper();
        await dbHelper.updateImagePaths(
          imageIdent,
          localProcessedPath: processedPath,
          cropResultJson: image.cropResultJson,
        );
      }
    }

    return CropResolveResult(
        image: processedResult.image, isFromPipeline: true);
  }
}
