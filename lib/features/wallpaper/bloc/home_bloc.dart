import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:setwallpaper/setwallpaper.dart';
import 'package:flutter/foundation.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_preferences.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/services/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_type_detector.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';

class HomeBloc {
  final _resultsController = BehaviorSubject<HomeState>();
  var _query = BehaviorSubject<String>();
  Stream<String> _wallpaper = Stream.empty();
  var _setWallpaper = BehaviorSubject<int>();
  var fetchingInitialData = false;

  Stream<HomeState> get results => _resultsController.stream;
  Sink<String> get query => _query;
  Stream<String> get wallpaper => _wallpaper;
  Sink<int> get setWallpaper => _setWallpaper;
  HomeState? state;

  // Service de préchargement
  final ImagePreloaderService _preloaderService = ImagePreloaderService();

  HomeBloc() {
    _query.distinct().listen((q) async {
      final newState = await _imageHandler(q);
      _resultsController.add(newState);
    });
    _wallpaper = _setWallpaper.asyncMap(_updateWallpaper).asBroadcastStream();
  }

  HomeState? initialData(int index) {
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();
    if (!fetchingInitialData) {
      fetchingInitialData = true;
      PrefHelper.getStringWithDefault(sp_BingRegion, "en-US").then((region) {
        PrefHelper.getStringListWithDefault(
                sp_PexelsCategories, defaultPexelsCategories.take(3).toList())
            .then((categories) {
          var catStr = categories.join(";");
          print("query:$dateStr.$region;$catStr");
          query.add('$dateStr.$region;$catStr');
          fetchingInitialData = false;
        });
      });
    }
    return state;
  }

  /// Refresh data when settings change
  void refresh() {
    fetchingInitialData = false; // Reset the flag
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();
    PrefHelper.getStringWithDefault(sp_BingRegion, "en-US").then((region) {
      PrefHelper.getStringListWithDefault(
              sp_PexelsCategories, defaultPexelsCategories.take(3).toList())
          .then((categories) {
        var catStr = categories.join(";");
        // Add a timestamp to force refresh
        var timestamp = DateTime.now().millisecondsSinceEpoch.toString();
        print("refresh query:$dateStr.$region;$catStr;refresh=$timestamp");
        query.add('$dateStr.$region;$catStr;refresh=$timestamp');
      });
    });
  }

  /// Refresh smart crop processing for current images
  /// This should be called when smart crop settings change
  void refreshSmartCrop() async {
    try {
      if (state?.list != null && state!.list.isNotEmpty) {
        debugPrint('Refreshing smart crop for ${state!.list.length} images');

        // Clear existing crop cache to force reprocessing with new settings
        await SmartCropPreferences.clearCropCache();

        // Reprocess all current images with new settings
        _processImagesWithSmartCrop(state!.list);
      }
    } catch (e) {
      debugPrint('Error refreshing smart crop: $e');
    }
  }

  Future<HomeState> _imageHandler(String query) async {
    var list = <ImageItem>[];

    // Clean up old images periodically (keep last 30 days)
    var dbHelper = new DatabaseHelper();
    // Start cleanup without waiting to avoid blocking
    dbHelper.cleanupOldImages(daysToKeep: 30);

    bool forceRefresh = query.contains('refresh=');
    debugPrint('Loading images concurrently... forceRefresh: $forceRefresh');

    // Launch all API requests concurrently
    var bingFuture = _bingHandler(query);
    var pexelsFutures = _fetchPexelsParallel();
    var nasaFuture = _nasaHandler(query, forceRefresh: forceRefresh);

    var results = await Future.wait([
      bingFuture,
      pexelsFutures,
      nasaFuture,
    ]);

    // Add Bing result
    if (results[0] != null) {
      list.add(results[0] as ImageItem);
    }

    // Add Pexels results
    if (results[1] != null) {
      list.addAll(results[1] as List<ImageItem>);
    }

    // Add NASA result
    var nasaResult = results[2] as ImageItem?;
    if (nasaResult != null) {
      debugPrint('NASA image added to list: ${nasaResult.source}');
      list.add(nasaResult);
    } else {
      debugPrint('NASA image is null - not available');
    }

    // 1. Démarrer le préchargement et le smart crop via le service dédié (prioritaire)
    // On attend que les images prioritaires soient prêtes (avec un timeout de sécurité)
    try {
      await _preloaderService
          .preloadImages(list, 0)
          .timeout(const Duration(seconds: 45));
    } catch (e) {
      debugPrint('Warning: Preloading timed out or failed ($e). Proceeding with available data.');
    }

    // 2. Notifier l'état initial
    state = HomeState(list, 0);
    _resultsController.add(state!);

    // 3. Traiter les images restantes de manière séquentielle si nécessaire
    // (Mais on laisse le service de préchargement faire le gros du travail)
    return state!;
  }

  void _updateImageCropResult(String imageIdent, CropResult result) {
    if (state == null) return;

    final updatedList = state!.list.map((item) {
      if (item.imageIdent == imageIdent) {
        // Return a copy with the updated crop result
        return item.copyWith(smartCropResult: result);
      }
      return item;
    }).toList();

    state = HomeState(updatedList, state!.imageIndex);
    _resultsController.add(state!);
  }

  /// Process images with smart crop in the background
  /// This method runs asynchronously and doesn't block the UI
  void _processImagesWithSmartCrop(List<ImageItem> images) async {
    try {
      // Check if smart crop is enabled
      final isSmartCropEnabled =
          await SmartCropPreferences.isSmartCropEnabled();
      if (!isSmartCropEnabled) {
        debugPrint('Smart crop is disabled, skipping background processing');
        return;
      }

      final baseCropSettings = await SmartCropPreferences.getCropSettings();
      final screenSize = ScreenUtils.getPhysicalScreenSize();

      debugPrint(
          'Starting background smart crop processing for ${images.length} images');

      // Process each image in the background sequentially to avoid peak CPU load
      for (final imageItem in images) {
        // Optimiser les paramètres selon la source de l'image
        final optimizedSettings =
            _getOptimizedCropSettings(imageItem, baseCropSettings);

        // Wait for each image to be processed before starting the next one
        await _processImageWithSmartCrop(
            imageItem, screenSize, optimizedSettings);

        // Add a tiny delay between images to allow the UI thread to remain responsive
        await Future.delayed(const Duration(milliseconds: 50));
      }
    } catch (e) {
      debugPrint('Error in background smart crop processing: $e');
    }
  }

  /// Process a single image with smart crop in the background
  Future<void> _processImageWithSmartCrop(
    ImageItem imageItem,
    ui.Size screenSize,
    dynamic cropSettings,
  ) async {
    try {
      debugPrint('Processing smart crop for: ${imageItem.imageIdent}');

      // Load the image
      final sourceImage = await ImageUtils.loadImageFromUrl(imageItem.url);
      if (sourceImage == null) {
        debugPrint('Failed to load image for smart crop: ${imageItem.url}');
        return;
      }

      // Calculate target size based on physical screen dimensions (including system bars)
      final targetSize = ScreenUtils.calculateTargetSize(
        ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        screenSize.width / screenSize.height,
        maxDimension: math
            .max(screenSize.width, screenSize.height)
            .round(), // Use actual screen size
      );

      // Check if we already have a cached crop for this image and target size
      final cachedCrop = await SmartCropper.getCachedCrop(
          imageItem.url, targetSize, cropSettings);
      if (cachedCrop != null) {
        debugPrint('Smart crop already cached for: ${imageItem.imageIdent}');
        return;
      }

      // Process the image with smart crop
      final result = await SmartCropper.processImage(
        imageItem.url,
        sourceImage,
        targetSize,
        cropSettings,
      );

      if (result.success) {
        debugPrint(
            'Smart crop completed successfully for: ${imageItem.imageIdent} (strategy: ${result.cropResult.bestCrop.strategy})');

        // Cache the pre-rendered image for immediate zero-flicker display
        SmartCropper.cacheProcessedImage(imageItem.imageIdent, result.image);

        // The result is automatically cached by SmartCropper
        _updateImageCropResult(imageItem.imageIdent, result.cropResult);
      } else {
        debugPrint(
            'Smart crop failed for: ${imageItem.imageIdent}, error: ${result.error}');
      }
    } catch (e) {
      debugPrint('Error processing smart crop for ${imageItem.imageIdent}: $e');
    }
  }

  Future<ImageItem> _bingHandler(String query) async {
    ImageItem? image;
    var region = await PrefHelper.getString(sp_BingRegion);
    var dbHelper = new DatabaseHelper();
    image = await dbHelper.getCurrentImage("bing.$region");
    if (image == null) {
      image = await ImageRepository.fetchFromBing(region!);
      await dbHelper.insertImage(image);
    }
    return image;
  }

  Future<List<ImageItem>> _fetchPexelsParallel() async {
    var categories = await PrefHelper.getStringListWithDefault(
        sp_PexelsCategories, defaultPexelsCategories.take(3).toList());

    // Get current date string for daily wallpaper logic
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();

    // Launch all Pexels category requests concurrently
    var futures = categories
        .map((category) => _fetchSinglePexels(category, dateStr))
        .toList();

    var results = await Future.wait(futures);
    // Filter out nulls and return the list
    return results.whereType<ImageItem>().toList();
  }

  Future<ImageItem?> _fetchSinglePexels(String category, String dateStr) async {
    var dbHelper = new DatabaseHelper();
    try {
      // Create unique identifier with date like Bing does
      var imageIdent = 'pexels.$category.$dateStr';
      ImageItem? pexelsImage = await dbHelper.getCurrentImage(imageIdent);

      if (pexelsImage == null) {
        // Fetch new image and update its identifier to include date
        pexelsImage = await ImageRepository.fetchFromPexels(category);
        // Update the imageIdent to include the date for daily persistence
        pexelsImage.imageIdent = imageIdent;
        await dbHelper.insertImage(pexelsImage);
      }
      return pexelsImage;
    } catch (e) {
      print('Error loading Pexels image for category $category: $e');
      return null;
    }
  }

  Future<ImageItem?> _nasaHandler(String query,
      {bool forceRefresh = false}) async {
    // NASA images are now always included (no toggle check)
    debugPrint('Loading NASA image (always enabled)');

    var dbHelper = new DatabaseHelper();
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();
    var imageIdent = 'nasa.apod.$dateStr';

    try {
      ImageItem? nasaImage;

      if (forceRefresh) {
        // Force refresh: delete existing cached image and fetch new one
        print('Force refreshing NASA image...');
        await dbHelper.deleteImageByIdent(imageIdent);
        nasaImage = null;
      } else {
        nasaImage = await dbHelper.getCurrentImage(imageIdent);
      }

      if (nasaImage == null) {
        // Fetch new NASA APOD
        print('Fetching new NASA APOD...');
        nasaImage = await ImageRepository.fetchFromNASA();
        // Update the imageIdent to include the date for daily persistence
        nasaImage.imageIdent = imageIdent;
        await dbHelper.insertImage(nasaImage);
      }

      return nasaImage;
    } catch (e) {
      print('Error loading NASA APOD: $e');
      // Check if it's a rate limit error
      if (e.toString().contains('429') || e.toString().contains('rate limit')) {
        debugPrint(
            'NASA API rate limit exceeded. Try again later or use a real API key.');
      }
      // Return null if NASA fails, don't break the entire app
      return null;
    }
  }

  Future<String> _updateWallpaper(int index) async {
    var setLocked =
        await PrefHelper.getBoolWithDefault(sp_IncludeLockWallpaper, true);
    String? message;
    var image = state!.list[index];

    try {
      final isSmartCropEnabled =
          await SmartCropPreferences.isSmartCropEnabled();

      if (isSmartCropEnabled) {
        debugPrint('Smart crop is enabled, processing image for wallpaper');

        // First, check if we have bytes captured from the carousel render
        // (pixel-perfect match between preview and applied wallpaper)
        final renderedBytes = SmartCropper.getRenderedBytes(image.imageIdent);
        if (renderedBytes != null) {
          debugPrint(
              'Using captured carousel render bytes for wallpaper (${renderedBytes.length} bytes)');
          if (setLocked) {
            message = await Setwallpaper.instance
                .setBothWallpaperFromBytes(renderedBytes);
          } else {
            message = await Setwallpaper.instance
                .setSystemWallpaperFromBytes(renderedBytes);
          }
          return message;
        }

        final baseCropSettings = await SmartCropPreferences.getCropSettings();
        final optimizedSettings =
            _getOptimizedCropSettings(image, baseCropSettings);
        final screenSize = ScreenUtils.getPhysicalScreenSize();

        // Load the source image
        final sourceImage = await ImageUtils.loadImageFromUrl(image.url);
        if (sourceImage != null) {
          final targetSize = ScreenUtils.calculateTargetSize(
            ui.Size(
                sourceImage.width.toDouble(), sourceImage.height.toDouble()),
            screenSize.width / screenSize.height,
            maxDimension: math.max(screenSize.width, screenSize.height).round(),
          );

          debugPrint(
              'Target size for wallpaper: ${targetSize.width}x${targetSize.height}');

          // Try to get the cached crop coordinates
          final cachedCrop = await SmartCropper.getCachedCrop(
              image.url, targetSize, optimizedSettings);
          if (cachedCrop != null) {
            debugPrint(
                'Found cached crop coordinates: ${cachedCrop.toString()}');

            // Apply the crop to create the wallpaper image
            final croppedImage = await SmartCropper.applyCropAndResize(
              sourceImage,
              cachedCrop,
              targetSize,
            );

            // Convert the cropped image to bytes
            final imageBytes = await ImageUtils.imageToBytes(croppedImage);

            if (imageBytes != null) {
              debugPrint(
                  'Using cropped image bytes for wallpaper (${imageBytes.length} bytes)');

              // Use the new methods that accept bytes
              if (setLocked) {
                message = await Setwallpaper.instance
                    .setBothWallpaperFromBytes(imageBytes);
              } else {
                message = await Setwallpaper.instance
                    .setSystemWallpaperFromBytes(imageBytes);
              }

              return message;
            } else {
              debugPrint(
                  'Failed to convert cropped image to bytes, falling back to original');
            }
          } else {
            debugPrint('No cached crop found, processing image now...');

            // Process the image with smart crop
            final processedResult = await SmartCropper.processImage(
              image.url,
              sourceImage,
              targetSize,
              optimizedSettings,
            );

            if (processedResult.success) {
              // Convert the processed image to bytes
              final imageBytes =
                  await ImageUtils.imageToBytes(processedResult.image);

              if (imageBytes != null) {
                debugPrint(
                    'Using newly processed cropped image bytes for wallpaper (${imageBytes.length} bytes)');

                // Use the new methods that accept bytes
                if (setLocked) {
                  message = await Setwallpaper.instance
                      .setBothWallpaperFromBytes(imageBytes);
                } else {
                  message = await Setwallpaper.instance
                      .setSystemWallpaperFromBytes(imageBytes);
                }

                return message;
              } else {
                debugPrint(
                    'Failed to convert processed image to bytes, falling back to original');
              }
            } else {
              debugPrint('Failed to process image: ${processedResult.error}');
            }
          }
        } else {
          debugPrint('Failed to load source image from URL');
        }
      } else {
        debugPrint('Smart crop is disabled, using original image');
      }
    } catch (e) {
      debugPrint('Error processing smart crop for wallpaper: $e');
    }

    // Fallback to original image URL if smart crop fails or is disabled
    debugPrint('Using original image URL for wallpaper: ${image.url}');
    if (setLocked) {
      message = await Setwallpaper.instance.setBothWallpaper(image.url);
    } else {
      message = await Setwallpaper.instance.setSystemWallpaper(image.url);
    }

    return message;
  }

  /// Optimise les paramètres de crop selon le type d'image
  dynamic _getOptimizedCropSettings(ImageItem imageItem, dynamic baseSettings) {
    // Déterminer la source de l'image
    String? imageSource;
    if (imageItem.source.toLowerCase().contains('bing')) {
      imageSource = 'bing';
    } else if (imageItem.source.toLowerCase().contains('nasa')) {
      imageSource = 'nasa';
    } else if (imageItem.source.toLowerCase().contains('pexels')) {
      imageSource = 'pexels';
    }

    // Retourner les paramètres optimisés selon la source
    switch (imageSource) {
      case 'bing':
        return ImageTypeDetector.getBingOptimizedSettings();
      case 'nasa':
        return ImageTypeDetector.getNASAOptimizedSettings();
      case 'pexels':
        return ImageTypeDetector.getPexelsOptimizedSettings();
      default:
        // Utiliser les paramètres de base si la source n'est pas reconnue
        return baseSettings;
    }
  }

  /// Notifie le changement d'index pour le préchargement
  void onIndexChanged(int newIndex) {
    if (state?.list != null && state!.list.isNotEmpty) {
      // Relancer le préchargement avec le nouvel index
      unawaited(_preloaderService.preloadImages(state!.list, newIndex));
    }
  }

  void dispose() {
    _resultsController.close();
    _preloaderService.clearCache();
    _query.close();
    _setWallpaper.close();
  }
}
