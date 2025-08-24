import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:dailywallpaper/bloc_state/home_state.dart';
import 'package:dailywallpaper/helper/datetime_helper.dart';
import 'package:dailywallpaper/prefs/pref_consts.dart';
import 'package:dailywallpaper/prefs/pref_helper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:dailywallpaper/api/image_repository.dart';
import 'package:dailywallpaper/helper/database_helper.dart';
import 'package:setwallpaper/setwallpaper.dart';
import 'package:flutter/foundation.dart';
import '../services/smart_crop/smart_cropper.dart';
import '../services/smart_crop/smart_crop_preferences.dart';
import '../services/smart_crop/utils/screen_utils.dart';
import '../services/smart_crop/utils/image_utils.dart';

class HomeBloc {
  Stream<HomeState> _results = Stream.empty();
  var _query = BehaviorSubject<String>();
  Stream<String> _wallpaper = Stream.empty();
  var _setWallpaper = BehaviorSubject<int>();
  var fetchingInitialData = false;

  Stream<HomeState> get results => _results;
  Sink<String> get query => _query;
  Stream<String> get wallpaper => _wallpaper;
  Sink<int> get setWallpaper => _setWallpaper;
  HomeState? state;
  

  HomeBloc() {
    _results = _query.distinct().asyncMap(_imageHandler).asBroadcastStream();
    _wallpaper = _setWallpaper.asyncMap(_updateWallpaper).asBroadcastStream();
  }

  HomeState? initialData(int index) {
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();
    if (!fetchingInitialData) {
      fetchingInitialData = true;
      PrefHelper.getStringWithDefault(sp_BingRegion, "en-US").then((region) {
        PrefHelper.getStringListWithDefault(sp_PexelsCategories, defaultPexelsCategories.take(3).toList())
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
      PrefHelper.getStringListWithDefault(sp_PexelsCategories, defaultPexelsCategories.take(3).toList())
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
    await dbHelper.cleanupOldImages(daysToKeep: 30);
    
    list.add(await _bingHandler(query));
    await for (ImageItem i in _pexelsHandler(query)) {
      list.add(i);
    }
    
    // Add NASA image if enabled
    bool forceRefresh = query.contains('refresh=');
    debugPrint('Checking NASA image... forceRefresh: $forceRefresh');
    var nasaImage = await _nasaHandler(query, forceRefresh: forceRefresh);
    if (nasaImage != null) {
      debugPrint('NASA image added to list: ${nasaImage.source}');
      list.add(nasaImage);
    } else {
      debugPrint('NASA image is null - either disabled or not available');
    }
    
    // Start background smart crop processing for all images
    _processImagesWithSmartCrop(list);
    
    state = HomeState(list, 0);
    return state!;
  }

  /// Process images with smart crop in the background
  /// This method runs asynchronously and doesn't block the UI
  void _processImagesWithSmartCrop(List<ImageItem> images) async {
    try {
      // Check if smart crop is enabled
      final isSmartCropEnabled = await SmartCropPreferences.isSmartCropEnabled();
      if (!isSmartCropEnabled) {
        debugPrint('Smart crop is disabled, skipping background processing');
        return;
      }

      final cropSettings = await SmartCropPreferences.getCropSettings();
      final screenSize = ScreenUtils.getPhysicalScreenSize();
      
      debugPrint('Starting background smart crop processing for ${images.length} images');

      // Process each image in the background
      for (final imageItem in images) {
        _processImageWithSmartCrop(imageItem, screenSize, cropSettings);
      }
    } catch (e) {
      debugPrint('Error in background smart crop processing: $e');
    }
  }

  /// Process a single image with smart crop in the background
  void _processImageWithSmartCrop(
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
        maxDimension: math.max(screenSize.width, screenSize.height).round(), // Use actual screen size
      );

      // Check if we already have a cached crop for this image and target size
      final cachedCrop = await SmartCropper.getCachedCrop(imageItem.url, targetSize, cropSettings);
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
        debugPrint('Smart crop completed successfully for: ${imageItem.imageIdent}');
        // The result is automatically cached by SmartCropper
      } else {
        debugPrint('Smart crop failed for: ${imageItem.imageIdent}, error: ${result.error}');
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

  Stream<ImageItem> _pexelsHandler(String query) async* {
    var dbHelper = new DatabaseHelper();
    var categories = await PrefHelper.getStringListWithDefault(
      sp_PexelsCategories, 
      defaultPexelsCategories.take(3).toList()
    );
    
    // Get current date string for daily wallpaper logic
    var dateStr = DateTimeHelper.startDayDate(DateTime.now()).toString();
    
    for (var category in categories) {
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
        yield pexelsImage;
      } catch (e) {
        print('Error loading Pexels image for category $category: $e');
        // Continue with other categories if one fails
      }
    }
  }

  Future<ImageItem?> _nasaHandler(String query, {bool forceRefresh = false}) async {
    // Check if NASA is enabled in settings
    var nasaEnabled = await PrefHelper.getBoolWithDefault(sp_NASAEnabled, false);
    debugPrint('NASA enabled: $nasaEnabled');
    if (!nasaEnabled) {
      debugPrint('NASA is disabled in settings');
      return null;
    }
    
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
        debugPrint('NASA API rate limit exceeded. Try again later or use a real API key.');
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
      final isSmartCropEnabled = await SmartCropPreferences.isSmartCropEnabled();
      
      if (isSmartCropEnabled) {
        debugPrint('Smart crop is enabled, processing image for wallpaper');
        final cropSettings = await SmartCropPreferences.getCropSettings();
        final screenSize = ScreenUtils.getPhysicalScreenSize();
        
        // Load the source image
        final sourceImage = await ImageUtils.loadImageFromUrl(image.url);
        if (sourceImage != null) {
          final targetSize = ScreenUtils.calculateTargetSize(
            ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
            screenSize.width / screenSize.height,
            maxDimension: math.max(screenSize.width, screenSize.height).round(),
          );
          
          debugPrint('Target size for wallpaper: ${targetSize.width}x${targetSize.height}');
          
          // Try to get the cached crop coordinates
          final cachedCrop = await SmartCropper.getCachedCrop(image.url, targetSize, cropSettings);
          if (cachedCrop != null) {
            debugPrint('Found cached crop coordinates: ${cachedCrop.toString()}');
            
            // Apply the crop to create the wallpaper image
            final croppedImage = await SmartCropper.applyCropAndResize(
              sourceImage,
              cachedCrop,
              targetSize,
            );
            
            // Convert the cropped image to bytes
            final imageBytes = await ImageUtils.imageToBytes(croppedImage);
            
            if (imageBytes != null) {
              debugPrint('Using cropped image bytes for wallpaper (${imageBytes.length} bytes)');
              
              // Use the new methods that accept bytes
              if (setLocked) {
                message = await Setwallpaper.instance.setBothWallpaperFromBytes(imageBytes);
              } else {
                message = await Setwallpaper.instance.setSystemWallpaperFromBytes(imageBytes);
              }
              
              return message;
            } else {
              debugPrint('Failed to convert cropped image to bytes, falling back to original');
            }
          } else {
            debugPrint('No cached crop found, processing image now...');
            
            // Process the image with smart crop
            final processedResult = await SmartCropper.processImage(
              image.url,
              sourceImage,
              targetSize,
              cropSettings,
            );
            
            if (processedResult.success) {
              // Convert the processed image to bytes
              final imageBytes = await ImageUtils.imageToBytes(processedResult.image);
              
              if (imageBytes != null) {
                debugPrint('Using newly processed cropped image bytes for wallpaper (${imageBytes.length} bytes)');
                
                // Use the new methods that accept bytes
                if (setLocked) {
                  message = await Setwallpaper.instance.setBothWallpaperFromBytes(imageBytes);
                } else {
                  message = await Setwallpaper.instance.setSystemWallpaperFromBytes(imageBytes);
                }
                
                return message;
              } else {
                debugPrint('Failed to convert processed image to bytes, falling back to original');
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

  void dispose() {
    _query.close();
    _setWallpaper.close();
  }
}
