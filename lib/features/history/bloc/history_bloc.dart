import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;

import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/pref_helper.dart';
import 'package:rxdart/rxdart.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/database/database_helper.dart';
import 'package:setwallpaper/setwallpaper.dart';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dailywallpaper/services/smart_crop/smart_cropper.dart';
import 'package:dailywallpaper/services/smart_crop/smart_crop_preferences.dart';
import 'package:dailywallpaper/services/smart_crop/utils/screen_utils.dart';
import 'package:dailywallpaper/services/smart_crop/utils/image_utils.dart';

class HistoryBloc {
  Stream<HistoryState> _results = Stream.empty();
  var _selectDate = BehaviorSubject<DateTime>();
  Stream<String> _wallpaper = Stream.empty();
  var _setWallpaper = BehaviorSubject<int>();

  HistoryState? _currentState;

  // Cache for loaded images to avoid reloading
  final Map<String, List<ImageItem>> _imageCache = {};
  final Map<String, DateTime> _cacheTimestamps = {};

  // Performance monitoring
  final Map<String, int> _loadTimes = {};

  // Cache expiry time (5 minutes)
  static const Duration _cacheExpiry = Duration(minutes: 5);

  Stream<HistoryState> get results => _results;
  Sink<DateTime> get selectDate => _selectDate;
  Stream<String> get wallpaper => _wallpaper;
  Sink<int> get setWallpaper => _setWallpaper;

  HistoryBloc() {
    _results =
        _selectDate.distinct().asyncMap(_dateHandler).asBroadcastStream();
    _wallpaper = _setWallpaper.asyncMap(_updateWallpaper).asBroadcastStream();
  }

  /// Initialize with today's date and load available dates
  Future<HistoryState> initialize() async {
    try {
      // Clear expired cache entries on initialization
      _clearExpiredCache();

      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Load available dates from database
      final availableDates = await getAvailableDates();

      // Create initial state
      _currentState = HistoryState.initial().copyWith(
        selectedDate: todayDate,
        availableDates: availableDates,
      );

      // Load images for today
      selectDate.add(todayDate);

      return _currentState!;
    } catch (e) {
      debugPrint('Error initializing HistoryBloc: $e');
      _currentState =
          HistoryState.initial().withError('Failed to initialize history: $e');
      return _currentState!;
    }
  }

  /// Get all available dates that have stored images
  Future<List<DateTime>> getAvailableDates() async {
    try {
      final dbHelper = DatabaseHelper();
      return await dbHelper.getAvailableDates();
    } catch (e) {
      debugPrint('Error getting available dates: $e');
      return [];
    }
  }

  /// Handle date selection and load images for the selected date
  Future<HistoryState> _dateHandler(DateTime selectedDate) async {
    final stopwatch = Stopwatch()..start();

    try {
      debugPrint('Loading images for date: $selectedDate');

      // Update state to loading
      _currentState = (_currentState ?? HistoryState.initial()).copyWith(
        selectedDate: selectedDate,
        isLoading: true,
        clearError: true,
      );

      // Check cache first
      final cacheKey = _getCacheKey(selectedDate);
      List<ImageItem> images = [];

      if (_isValidCache(cacheKey)) {
        images = _imageCache[cacheKey]!;
        debugPrint(
            'Using cached images for date: $selectedDate (${images.length} images)');
      } else {
        // Load images from database
        final dbHelper = DatabaseHelper();
        images = await dbHelper.getImagesForDate(selectedDate);

        // Cache the results
        _imageCache[cacheKey] = images;
        _cacheTimestamps[cacheKey] = DateTime.now();

        debugPrint(
            'Loaded ${images.length} images from database for date: $selectedDate');
      }

      // Update available dates if needed (use cached version if available)
      final availableDates = await getAvailableDates();

      // Start background smart crop processing for loaded images (only if not from cache)
      if (images.isNotEmpty && !_isValidCache(cacheKey)) {
        _processImagesWithSmartCrop(images);
      }

      // Update state with loaded images
      _currentState = _currentState!.copyWith(
        images: images,
        availableDates: availableDates,
        isLoading: false,
        clearError: true,
      );

      stopwatch.stop();
      _loadTimes[cacheKey] = stopwatch.elapsedMilliseconds;
      debugPrint(
          'Date loading completed in ${stopwatch.elapsedMilliseconds}ms');

      return _currentState!;
    } on DatabaseException catch (e) {
      debugPrint('Database error loading images for date $selectedDate: $e');

      _currentState = (_currentState ?? HistoryState.initial()).copyWith(
        selectedDate: selectedDate,
        isLoading: false,
        error:
            'Database error: Unable to access stored images. Please try again.',
      );

      return _currentState!;
    } catch (e) {
      debugPrint('Error loading images for date $selectedDate: $e');

      String errorMessage;
      if (e.toString().contains('connection') ||
          e.toString().contains('network')) {
        errorMessage =
            'Network error: Unable to load images. Please check your connection.';
      } else {
        errorMessage =
            'Failed to load images for selected date. Please try again.';
      }

      _currentState = (_currentState ?? HistoryState.initial()).copyWith(
        selectedDate: selectedDate,
        isLoading: false,
        error: errorMessage,
      );

      return _currentState!;
    }
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

      final cropSettings = await SmartCropPreferences.getCropSettings();
      final screenSize = ScreenUtils.getPhysicalScreenSize();

      debugPrint(
          'Starting background smart crop processing for ${images.length} historical images');

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
      debugPrint(
          'Processing smart crop for historical image: ${imageItem.imageIdent}');

      // Load the image
      final sourceImage = await ImageUtils.loadImageFromUrl(imageItem.url);
      if (sourceImage == null) {
        debugPrint(
            'Failed to load historical image for smart crop: ${imageItem.url}');
        return;
      }

      // Calculate target size based on physical screen dimensions
      final targetSize = ScreenUtils.calculateTargetSize(
        ui.Size(sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        screenSize.width / screenSize.height,
        maxDimension: math.max(screenSize.width, screenSize.height).round(),
      );

      // Check if we already have a cached crop for this image and target size
      final cachedCrop = await SmartCropper.getCachedCrop(
          imageItem.url, targetSize, cropSettings);
      if (cachedCrop != null) {
        debugPrint(
            'Smart crop already cached for historical image: ${imageItem.imageIdent}');
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
            'Smart crop completed successfully for historical image: ${imageItem.imageIdent}');
        // The result is automatically cached by SmartCropper
      } else {
        debugPrint(
            'Smart crop failed for historical image: ${imageItem.imageIdent}, error: ${result.error}');
      }
    } catch (e) {
      debugPrint(
          'Error processing smart crop for historical image ${imageItem.imageIdent}: $e');
    }
  }

  /// Handle wallpaper setting for historical images
  Future<String> _updateWallpaper(int index) async {
    try {
      if (_currentState == null || _currentState!.images.isEmpty) {
        return 'No images available to set as wallpaper';
      }

      if (index < 0 || index >= _currentState!.images.length) {
        return 'Invalid image selection. Please try again.';
      }

      final setLocked =
          await PrefHelper.getBoolWithDefault(sp_IncludeLockWallpaper, true);
      final image = _currentState!.images[index];
      String? message;

      debugPrint(
          'Setting wallpaper from historical image: ${image.imageIdent}');

      try {
        final isSmartCropEnabled =
            await SmartCropPreferences.isSmartCropEnabled();

        if (isSmartCropEnabled) {
          debugPrint(
              'Smart crop is enabled, processing historical image for wallpaper');
          final cropSettings = await SmartCropPreferences.getCropSettings();
          final screenSize = ScreenUtils.getPhysicalScreenSize();

          // Load the source image
          final sourceImage = await ImageUtils.loadImageFromUrl(image.url);
          if (sourceImage != null) {
            final targetSize = ScreenUtils.calculateTargetSize(
              ui.Size(
                  sourceImage.width.toDouble(), sourceImage.height.toDouble()),
              screenSize.width / screenSize.height,
              maxDimension:
                  math.max(screenSize.width, screenSize.height).round(),
            );

            debugPrint(
                'Target size for historical wallpaper: ${targetSize.width}x${targetSize.height}');

            // Try to get the cached crop coordinates
            final cachedCrop = await SmartCropper.getCachedCrop(
                image.url, targetSize, cropSettings);
            if (cachedCrop != null) {
              debugPrint(
                  'Found cached crop coordinates for historical image: ${cachedCrop.toString()}');

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
                    'Using cropped historical image bytes for wallpaper (${imageBytes.length} bytes)');

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
                    'Failed to convert cropped historical image to bytes, falling back to original');
              }
            } else {
              debugPrint(
                  'No cached crop found for historical image, processing now...');

              // Process the image with smart crop
              final processedResult = await SmartCropper.processImage(
                image.url,
                sourceImage,
                targetSize,
                cropSettings,
              );

              if (processedResult.success) {
                // Convert the processed image to bytes
                final imageBytes =
                    await ImageUtils.imageToBytes(processedResult.image);

                if (imageBytes != null) {
                  debugPrint(
                      'Using newly processed cropped historical image bytes for wallpaper (${imageBytes.length} bytes)');

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
                      'Failed to convert processed historical image to bytes, falling back to original');
                }
              } else {
                debugPrint(
                    'Failed to process historical image: ${processedResult.error}');
              }
            }
          } else {
            debugPrint('Failed to load source historical image from URL');
          }
        } else {
          debugPrint('Smart crop is disabled, using original historical image');
        }
      } catch (e) {
        debugPrint('Error processing smart crop for historical wallpaper: $e');
      }

      // Fallback to original image URL if smart crop fails or is disabled
      debugPrint(
          'Using original historical image URL for wallpaper: ${image.url}');
      if (setLocked) {
        message = await Setwallpaper.instance.setBothWallpaper(image.url);
      } else {
        message = await Setwallpaper.instance.setSystemWallpaper(image.url);
      }

      return message;
    } catch (e) {
      debugPrint('Error setting wallpaper from historical image: $e');

      // Provide user-friendly error messages
      if (e.toString().contains('permission')) {
        return 'Permission denied. Please check wallpaper permissions in settings.';
      } else if (e.toString().contains('network') ||
          e.toString().contains('connection')) {
        return 'Network error. Please check your connection and try again.';
      } else if (e.toString().contains('storage') ||
          e.toString().contains('space')) {
        return 'Storage error. Please free up some space and try again.';
      } else {
        return 'Failed to set wallpaper. Please try again.';
      }
    }
  }

  /// Get cache key for a date
  String _getCacheKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Check if cache is valid for a given key
  bool _isValidCache(String cacheKey) {
    if (!_imageCache.containsKey(cacheKey) ||
        !_cacheTimestamps.containsKey(cacheKey)) {
      return false;
    }

    final cacheTime = _cacheTimestamps[cacheKey]!;
    final now = DateTime.now();
    return now.difference(cacheTime) < _cacheExpiry;
  }

  /// Clear expired cache entries
  void _clearExpiredCache() {
    final now = DateTime.now();
    final expiredKeys = <String>[];

    for (final entry in _cacheTimestamps.entries) {
      if (now.difference(entry.value) >= _cacheExpiry) {
        expiredKeys.add(entry.key);
      }
    }

    for (final key in expiredKeys) {
      _imageCache.remove(key);
      _cacheTimestamps.remove(key);
      _loadTimes.remove(key);
    }

    if (expiredKeys.isNotEmpty) {
      debugPrint('Cleared ${expiredKeys.length} expired cache entries');
    }
  }

  /// Get performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'cache_entries': _imageCache.length,
      'load_times': Map.from(_loadTimes),
      'average_load_time': _loadTimes.values.isEmpty
          ? 0
          : _loadTimes.values.reduce((a, b) => a + b) /
              _loadTimes.values.length,
    };
  }

  /// Clear all caches (useful for memory management)
  void clearCache() {
    _imageCache.clear();
    _cacheTimestamps.clear();
    _loadTimes.clear();
    debugPrint('Cleared all history caches');
  }

  /// Get current state (for initial data)
  HistoryState? get currentState => _currentState;

  void dispose() {
    // Clear caches to free memory
    clearCache();

    _selectDate.close();
    _setWallpaper.close();
  }
}
