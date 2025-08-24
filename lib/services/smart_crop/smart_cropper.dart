import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:io' as io;
import 'dart:isolate';
import 'dart:typed_data';

import 'models/crop_coordinates.dart';
import 'models/crop_score.dart';
import 'models/crop_result.dart';
import 'models/crop_settings.dart';
import 'interfaces/crop_analyzer.dart';
import 'analyzers/analyzers.dart';
import 'cache/crop_cache_manager.dart';
import 'utils/image_utils.dart';
import 'utils/device_capability_detector.dart';
import 'utils/battery_optimizer.dart';
import 'utils/performance_monitor.dart';

/// Main orchestrator class for intelligent image cropping
/// 
/// This class coordinates multiple crop analysis strategies to determine
/// the optimal crop area for an image based on the target size and settings.
class SmartCropper {
  static final Map<String, ui.Image> _imageCache = {};
  static CropCacheManager? _cacheManager;
  static DeviceCapability? _deviceCapability;
  static final PerformanceMonitor _performanceMonitor = PerformanceMonitor();
  
  // Memory pressure detection constants
  static const int _maxMemoryMB = 100;
  static const int _criticalMemoryMB = 150;
  static const Duration _memoryCheckInterval = Duration(milliseconds: 100);
  
  // Fallback timeout constants
  static const Duration _defaultTimeout = Duration(seconds: 2);
  static const Duration _maxTimeout = Duration(seconds: 5);
  
  // Performance optimization constants (will be overridden by device capability)
  static int _maxAnalysisDimension = 512;
  static int _minImageSizeForIsolate = 1024;
  static int _maxConcurrentAnalyzers = 3;
  static const Duration _isolateTimeout = Duration(seconds: 10);
  
  /// Gets the cache manager instance
  static CropCacheManager get _cache {
    _cacheManager ??= CropCacheManager();
    return _cacheManager!;
  }
  
  /// Gets device capability and updates performance constants
  static Future<DeviceCapability> _getDeviceCapability() async {
    if (_deviceCapability != null) {
      return _deviceCapability!;
    }
    
    _deviceCapability = await DeviceCapabilityDetector.getDeviceCapability();
    
    // Update performance constants based on device capability
    _maxAnalysisDimension = _deviceCapability!.maxImageDimension;
    _minImageSizeForIsolate = _deviceCapability!.useIsolateThreshold;
    _maxConcurrentAnalyzers = _deviceCapability!.maxConcurrentAnalyzers;
    
    return _deviceCapability!;
  }
  
  /// Detects if the system is under memory pressure
  static bool _isUnderMemoryPressure(ui.Image image, ui.Size targetSize) {
    try {
      final estimatedMemory = estimateMemoryUsage(image, targetSize);
      final memoryMB = estimatedMemory / (1024 * 1024);
      
      // Check if estimated memory usage exceeds critical limits
      if (memoryMB > _criticalMemoryMB) {
        return true;
      }
      
      // Check system-level memory pressure
      if (_isSystemUnderMemoryPressure()) {
        return true;
      }
      
      // On mobile platforms, be more conservative
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        return memoryMB > _maxMemoryMB;
      }
      
      // On desktop platforms, allow higher memory usage
      return memoryMB > (_maxMemoryMB * 2);
    } catch (e) {
      // If we can't determine memory usage, assume pressure to be safe
      return true;
    }
  }
  
  /// Determines if smart cropping should be skipped due to constraints
  static bool _shouldSkipSmartCrop(ui.Image image, ui.Size targetSize, CropSettings settings) {
    // Skip if under memory pressure
    if (_isUnderMemoryPressure(image, targetSize)) {
      return true;
    }
    
    // Skip if image is too small to benefit from smart cropping
    if (image.width < 100 || image.height < 100) {
      return true;
    }
    
    // Skip if target size is very small
    if (targetSize.width < 50 || targetSize.height < 50) {
      return true;
    }
    
    // Skip if no strategies are enabled
    if (settings.enabledStrategies.isEmpty) {
      return true;
    }
    
    return false;
  }
  
  /// Creates a timeout-aware completer with memory monitoring
  static Completer<CropResult> _createTimeoutCompleter(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) {
    final completer = Completer<CropResult>();
    Timer? timeoutTimer;
    Timer? memoryCheckTimer;
    
    // Set up timeout
    final timeout = settings.maxProcessingTime.inMilliseconds > _maxTimeout.inMilliseconds
        ? _maxTimeout
        : settings.maxProcessingTime;
    
    timeoutTimer = Timer(timeout, () {
      if (!completer.isCompleted) {
        memoryCheckTimer?.cancel();
        final fallbackCrop = _getFallbackCrop(image, targetSize);
        completer.complete(CropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: timeout,
          fromCache: false,
        ));
      }
    });
    
    // Set up periodic memory pressure checks
    memoryCheckTimer = Timer.periodic(_memoryCheckInterval, (timer) {
      if (!completer.isCompleted && _isUnderMemoryPressure(image, targetSize)) {
        timer.cancel();
        timeoutTimer?.cancel();
        final fallbackCrop = _getFallbackCrop(image, targetSize);
        completer.complete(CropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: Duration(milliseconds: timer.tick * _memoryCheckInterval.inMilliseconds),
          fromCache: false,
        ));
      }
    });
    
    // Clean up timers when completer completes
    completer.future.whenComplete(() {
      timeoutTimer?.cancel();
      memoryCheckTimer?.cancel();
    });
    
    return completer;
  }

  /// Analyzes an image and returns the best crop coordinates
  /// 
  /// [imageUrl] URL or identifier for the image
  /// [image] The source image to analyze
  /// [targetSize] The desired output size for the crop
  /// [settings] Configuration settings for the analysis
  /// 
  /// Returns a [CropResult] with the best crop area and analysis details
  static Future<CropResult> analyzeCrop(
    String imageUrl,
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    return await _withPerformanceMonitoring('analyzeCrop', () async {
      final stopwatch = Stopwatch()..start();
      
      try {
        // Get device capability and apply optimizations
        final deviceCapability = await _getDeviceCapability();
        
        // Apply battery optimizations
        final optimizedSettings = await BatteryOptimizer.optimizeSettingsForBattery(settings);
        
        // Check if processing should be deferred due to battery constraints
        if (await BatteryOptimizer.shouldDeferProcessing()) {
          final delay = await BatteryOptimizer.getRecommendedProcessingDelay();
          await Future.delayed(delay);
        }
        
        // Validate inputs first
        if (!_validateInputs(image, targetSize, optimizedSettings)) {
          throw ArgumentError('Invalid inputs for crop analysis');
        }
        
        // Check if we should skip smart cropping due to constraints
        if (_shouldSkipSmartCrop(image, targetSize, optimizedSettings)) {
          stopwatch.stop();
          final fallbackCrop = _getFallbackCrop(image, targetSize);
          final result = CropResult(
            bestCrop: fallbackCrop,
            allScores: [],
            processingTime: stopwatch.elapsed,
            fromCache: false,
          );
          
          _recordPerformanceMetric('analyzeCrop', stopwatch.elapsed, true, {
            'from_cache': false,
            'skipped_smart_crop': true,
            'memory_usage_mb': estimateMemoryUsage(image, targetSize) / (1024 * 1024),
          });
          
          return result;
        }
        
        // Check persistent cache first
        final cachedCrop = await _cache.getCachedCrop(imageUrl, targetSize, optimizedSettings);
        
        if (cachedCrop != null) {
          stopwatch.stop();
          final result = CropResult(
            bestCrop: cachedCrop,
            allScores: [], // Cache doesn't store all scores
            processingTime: stopwatch.elapsed,
            fromCache: true,
          );
          
          _recordPerformanceMetric('analyzeCrop', stopwatch.elapsed, true, {
            'from_cache': true,
            'memory_usage_mb': estimateMemoryUsage(image, targetSize) / (1024 * 1024),
          });
          
          return result;
        }
        
        // Apply device-specific timeout
        final adjustedSettings = optimizedSettings.copyWith(
          maxProcessingTime: Duration(
            milliseconds: (optimizedSettings.maxProcessingTime.inMilliseconds * 
                          deviceCapability.timeoutMultiplier).round(),
          ),
        );
        
        // Determine processing strategy based on image size and settings
        final CropResult result;
        if (_shouldUseIsolate(image, adjustedSettings)) {
          // Use background isolate for heavy processing
          result = await _processInIsolate(image, targetSize, adjustedSettings);
        } else {
          // Use optimized main thread processing
          result = await _performMainThreadAnalysis(image, targetSize, adjustedSettings);
        }
        
        // Cache the result if it's successful and not from timeout/fallback
        if (result.bestCrop.strategy != 'fallback_center' && 
            result.bestCrop.strategy != 'memory_fallback' &&
            result.bestCrop.strategy != 'timeout_fallback') {
          try {
            await _cache.cacheCrop(imageUrl, targetSize, adjustedSettings, result.bestCrop);
          } catch (cacheError) {
            // Don't fail the entire operation if caching fails
          }
        }
        
        stopwatch.stop();
        final finalResult = result.copyWith(processingTime: stopwatch.elapsed);
        
        _recordPerformanceMetric('analyzeCrop', stopwatch.elapsed, true, {
          'from_cache': false,
          'strategy': result.bestCrop.strategy,
          'confidence': result.bestCrop.confidence,
          'memory_usage_mb': estimateMemoryUsage(image, targetSize) / (1024 * 1024),
          'device_tier': deviceCapability.overallTier.toString(),
        });
        
        return finalResult;
        
      } catch (e) {
        stopwatch.stop();
        // Return fallback crop on any error
        final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'error');
        final result = CropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: stopwatch.elapsed,
          fromCache: false,
        );
        
        _recordPerformanceMetric('analyzeCrop', stopwatch.elapsed, false, {
          'error': e.toString(),
          'memory_usage_mb': estimateMemoryUsage(image, targetSize) / (1024 * 1024),
        });
        
        return result;
      }
    });
  }
  
  /// Performs the actual crop analysis using multiple strategies with enhanced fallback
  static Future<void> _performAnalysisWithFallback(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
    Completer<CropResult> completer,
  ) async {
    try {
      final analyzers = _createAnalyzers(settings);
      final scores = <CropScore>[];
      int failedAnalyzers = 0;
      
      // Run all enabled analyzers with individual error handling
      for (final analyzer in analyzers) {
        try {
          // Check if completer is already completed (timeout/memory pressure)
          if (completer.isCompleted) {
            break;
          }
          
          // Check memory pressure before each analyzer
          if (_isUnderMemoryPressure(image, targetSize)) {
            final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'memory_pressure');
            if (!completer.isCompleted) {
              completer.complete(CropResult(
                bestCrop: fallbackCrop,
                allScores: scores,
                processingTime: Duration.zero,
                fromCache: false,
              ));
            }
            return;
          }
          
          final score = await analyzer.analyze(image, targetSize);
          if (score.isValid && score.score >= analyzer.minConfidenceThreshold) {
            scores.add(score);
          }
        } catch (e) {
          failedAnalyzers++;
          // Continue with other analyzers if one fails
          continue;
        }
      }
      
      // If all analyzers failed, use fallback
      if (scores.isEmpty || failedAnalyzers == analyzers.length) {
        final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'analyzer_failure');
        if (!completer.isCompleted) {
          completer.complete(CropResult(
            bestCrop: fallbackCrop,
            allScores: [],
            processingTime: Duration.zero,
            fromCache: false,
          ));
        }
        return;
      }
      
      // Select best crop from all scores
      final bestCrop = _selectBestCrop(scores, settings);
      
      if (!completer.isCompleted) {
        completer.complete(CropResult(
          bestCrop: bestCrop,
          allScores: scores,
          processingTime: Duration.zero, // Will be updated by caller
          fromCache: false,
        ));
      }
    } catch (e) {
      if (!completer.isCompleted) {
        final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'analysis_error');
        completer.complete(CropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: Duration.zero,
          fromCache: false,
        ));
      }
    }
  }
  
  /// Legacy method for backward compatibility
  static Future<void> _performAnalysis(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
    Completer<CropResult> completer,
  ) async {
    return _performAnalysisWithFallback(image, targetSize, settings, completer);
  }
  
  /// Creates analyzer instances based on settings
  static List<CropAnalyzer> _createAnalyzers(CropSettings settings) {
    final analyzers = <CropAnalyzer>[];
    
    if (settings.enableRuleOfThirds) {
      analyzers.add(RuleOfThirdsCropAnalyzer());
    }
    
    if (settings.enableCenterWeighting) {
      analyzers.add(CenterWeightedCropAnalyzer());
    }
    
    if (settings.enableEntropyAnalysis) {
      analyzers.add(EntropyBasedCropAnalyzer());
    }
    
    if (settings.enableEdgeDetection) {
      analyzers.add(EdgeDetectionCropAnalyzer());
    }
    
    return analyzers;
  }
  
  /// Selects the best crop from all analyzer scores
  static CropCoordinates _selectBestCrop(List<CropScore> scores, CropSettings settings) {
    if (scores.isEmpty) {
      throw StateError('No valid crop scores available');
    }
    
    // Calculate weighted scores based on analyzer weights and aggressiveness
    final weightedScores = <CropScore>[];
    
    for (final score in scores) {
      final analyzer = _getAnalyzerByName(score.strategy);
      if (analyzer != null) {
        final aggressivenessMultiplier = _getAggressivenessMultiplier(
          score.strategy, 
          settings.aggressiveness,
        );
        
        final weightedScore = score.score * analyzer.weight * aggressivenessMultiplier;
        
        weightedScores.add(score.copyWith(
          score: weightedScore,
          metrics: {
            ...score.metrics,
            'weighted_score': weightedScore,
            'original_score': score.score,
            'analyzer_weight': analyzer.weight,
            'aggressiveness_multiplier': aggressivenessMultiplier,
          },
        ));
      }
    }
    
    // Sort by weighted score and return the best
    weightedScores.sort((a, b) => b.score.compareTo(a.score));
    return weightedScores.first.coordinates;
  }
  
  /// Gets aggressiveness multiplier for different strategies
  static double _getAggressivenessMultiplier(String strategy, CropAggressiveness aggressiveness) {
    switch (aggressiveness) {
      case CropAggressiveness.conservative:
        // Favor center-weighted and rule of thirds, reduce edge detection
        switch (strategy) {
          case 'center_weighted':
            return 1.2;
          case 'rule_of_thirds':
            return 1.0;
          case 'entropy':
            return 0.8;
          case 'edge_detection':
            return 0.6;
          default:
            return 1.0;
        }
        
      case CropAggressiveness.balanced:
        // Equal weighting for most strategies
        return 1.0;
        
      case CropAggressiveness.aggressive:
        // Favor entropy and edge detection for more dynamic crops
        switch (strategy) {
          case 'entropy':
            return 1.3;
          case 'edge_detection':
            return 1.2;
          case 'rule_of_thirds':
            return 1.1;
          case 'center_weighted':
            return 0.8;
          default:
            return 1.0;
        }
    }
  }
  
  /// Gets analyzer instance by strategy name
  static CropAnalyzer? _getAnalyzerByName(String strategyName) {
    switch (strategyName) {
      case 'rule_of_thirds':
        return RuleOfThirdsCropAnalyzer();
      case 'center_weighted':
        return CenterWeightedCropAnalyzer();
      case 'entropy':
        return EntropyBasedCropAnalyzer();
      case 'edge_detection':
        return EdgeDetectionCropAnalyzer();
      default:
        return null;
    }
  }
  
  /// Validates input parameters
  static bool _validateInputs(ui.Image image, ui.Size targetSize, CropSettings settings) {
    return image.width > 0 &&
           image.height > 0 &&
           targetSize.width > 0 &&
           targetSize.height > 0 &&
           settings.isValid;
  }
  
  /// Creates a fallback crop when analysis fails
  static CropCoordinates _getFallbackCrop(
    ui.Image image, 
    ui.Size targetSize, {
    String fallbackReason = 'general',
  }) {
    try {
      final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
      final targetAspectRatio = targetSize.width / targetSize.height;
      final imageAspectRatio = imageSize.width / imageSize.height;
      
      double cropWidth, cropHeight;
      String strategyName;
      double confidence;
      
      // Determine fallback strategy based on reason
      switch (fallbackReason) {
        case 'memory_pressure':
          strategyName = 'memory_fallback';
          confidence = 0.3;
          break;
        case 'timeout':
          strategyName = 'timeout_fallback';
          confidence = 0.4;
          break;
        case 'analyzer_failure':
          strategyName = 'analyzer_fallback';
          confidence = 0.4;
          break;
        case 'error':
          strategyName = 'error_fallback';
          confidence = 0.2;
          break;
        default:
          strategyName = 'fallback_center';
          confidence = 0.5;
      }
      
      if (targetAspectRatio > imageAspectRatio) {
        // Target is wider, use full width
        cropWidth = 1.0;
        cropHeight = imageAspectRatio / targetAspectRatio;
      } else {
        // Target is taller, use full height
        cropHeight = 1.0;
        cropWidth = targetAspectRatio / imageAspectRatio;
      }
      
      // Ensure crop dimensions are valid
      cropWidth = math.max(0.1, math.min(1.0, cropWidth));
      cropHeight = math.max(0.1, math.min(1.0, cropHeight));
      
      return CropCoordinates(
        x: (1.0 - cropWidth) / 2,
        y: (1.0 - cropHeight) / 2,
        width: cropWidth,
        height: cropHeight,
        confidence: confidence,
        strategy: strategyName,
      );
    } catch (e) {
      // Ultimate fallback - return full image
      return CropCoordinates(
        x: 0.0,
        y: 0.0,
        width: 1.0,
        height: 1.0,
        confidence: 0.1,
        strategy: 'ultimate_fallback',
      );
    }
  }
  
  /// Gets cached crop coordinates
  static Future<CropCoordinates?> getCachedCrop(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    return await _cache.getCachedCrop(imageUrl, targetSize, settings);
  }
  
  /// Caches crop coordinates
  static Future<bool> cacheCrop(
    String imageUrl,
    ui.Size targetSize,
    CropSettings settings,
    CropCoordinates coordinates,
  ) async {
    return await _cache.cacheCrop(imageUrl, targetSize, settings, coordinates);
  }
  
  /// Invalidates cache for a specific image
  static Future<int> invalidateImageCache(String imageUrl) async {
    return await _cache.invalidateImageCache(imageUrl);
  }
  
  /// Invalidates cache when settings change
  static Future<int> invalidateSettingsCache(CropSettings newSettings) async {
    return await _cache.invalidateSettingsCache(newSettings);
  }
  
  /// Clears all cached crop coordinates
  static Future<int> clearCache() async {
    _imageCache.clear();
    return await _cache.clearCache();
  }
  
  /// Gets cache statistics
  static Future<Map<String, dynamic>> getCacheStats() async {
    final cacheStats = await _cache.getStats();
    final hitRateStats = await _cache.getHitRateStats();
    
    return {
      'crop_cache_size': cacheStats.totalEntries,
      'crop_cache_size_mb': cacheStats.totalSizeMB,
      'image_cache_size': _imageCache.length,
      'average_access_count': cacheStats.averageAccessCount,
      'hit_rate_percentage': hitRateStats.hitRatePercentage,
      'oldest_entry': cacheStats.oldestEntry?.toIso8601String(),
      'newest_entry': cacheStats.newestEntry?.toIso8601String(),
      'cache_age_days': cacheStats.cacheAge?.inDays ?? 0,
    };
  }
  
  /// Performs cache maintenance (cleanup and optimization)
  static Future<Map<String, dynamic>> performCacheMaintenance({
    Duration ttl = const Duration(days: 7),
    int maxEntries = 1000,
  }) async {
    final result = await _cache.performMaintenance(ttl: ttl, maxEntries: maxEntries);
    
    return {
      'success': result.success,
      'expired_entries_deleted': result.expiredEntriesDeleted,
      'lru_entries_evicted': result.lruEntriesEvicted,
      'total_entries_deleted': result.totalEntriesDeleted,
      'error': result.error,
    };
  }
  
  /// Preloads cache for common screen sizes
  static Future<void> preloadCommonSizes(
    String imageUrl,
    ui.Image sourceImage,
    CropSettings settings,
  ) async {
    await _cache.preloadCommonSizes(
      imageUrl,
      sourceImage,
      settings,
      (targetSize) async {
        // Use the existing analysis logic
        final result = await analyzeCrop(imageUrl, sourceImage, targetSize, settings);
        return result.bestCrop;
      },
    );
  }
  
  /// Applies crop coordinates to an image and returns the cropped result
  /// 
  /// [sourceImage] The original image to crop
  /// [coordinates] The crop coordinates (normalized 0.0 to 1.0)
  /// 
  /// Returns a new [ui.Image] with the applied crop
  static Future<ui.Image> applyCrop(
    ui.Image sourceImage,
    CropCoordinates coordinates,
  ) async {
    try {
      // Validate inputs
      if (!coordinates.isValid) {
        throw ArgumentError('Invalid crop coordinates: $coordinates');
      }
      
      if (sourceImage.width <= 0 || sourceImage.height <= 0) {
        throw ArgumentError('Invalid source image dimensions');
      }
      
      // Convert normalized coordinates to pixel coordinates
      final sourceWidth = sourceImage.width;
      final sourceHeight = sourceImage.height;
      
      final cropX = (coordinates.x * sourceWidth).round();
      final cropY = (coordinates.y * sourceHeight).round();
      final cropWidth = (coordinates.width * sourceWidth).round();
      final cropHeight = (coordinates.height * sourceHeight).round();
      
      // Ensure crop bounds are within image bounds
      final clampedX = math.max(0, math.min(cropX, sourceWidth - 1));
      final clampedY = math.max(0, math.min(cropY, sourceHeight - 1));
      final clampedWidth = math.max(1, math.min(cropWidth, sourceWidth - clampedX));
      final clampedHeight = math.max(1, math.min(cropHeight, sourceHeight - clampedY));
      
      // Create crop rectangle
      final cropRect = ui.Rect.fromLTWH(
        clampedX.toDouble(),
        clampedY.toDouble(),
        clampedWidth.toDouble(),
        clampedHeight.toDouble(),
      );
      
      // Apply the crop using Canvas
      return await _cropImageWithCanvas(sourceImage, cropRect);
      
    } catch (e) {
      // On error, return the original image
      return sourceImage;
    }
  }
  
  /// Internal method to crop image using Canvas
  static Future<ui.Image> _cropImageWithCanvas(ui.Image sourceImage, ui.Rect cropRect) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    // Draw the cropped portion of the source image
    final srcRect = cropRect;
    final dstRect = ui.Rect.fromLTWH(0, 0, cropRect.width, cropRect.height);
    
    canvas.drawImageRect(sourceImage, srcRect, dstRect, ui.Paint());
    
    final picture = recorder.endRecording();
    
    // Convert to image with proper dimensions
    final croppedImage = await picture.toImage(
      cropRect.width.round(),
      cropRect.height.round(),
    );
    
    // Clean up
    picture.dispose();
    
    return croppedImage;
  }
  
  /// Applies crop and resizes to target size in one operation
  /// 
  /// [sourceImage] The original image to crop and resize
  /// [coordinates] The crop coordinates (normalized 0.0 to 1.0)
  /// [targetSize] The final desired size
  /// 
  /// Returns a new [ui.Image] with the applied crop and resize
  static Future<ui.Image> applyCropAndResize(
    ui.Image sourceImage,
    CropCoordinates coordinates,
    ui.Size targetSize,
  ) async {
    try {
      // Validate inputs
      if (!coordinates.isValid) {
        throw ArgumentError('Invalid crop coordinates: $coordinates');
      }
      
      if (targetSize.width <= 0 || targetSize.height <= 0) {
        throw ArgumentError('Invalid target size: $targetSize');
      }
      
      // Convert normalized coordinates to pixel coordinates
      final sourceWidth = sourceImage.width;
      final sourceHeight = sourceImage.height;
      
      final cropX = (coordinates.x * sourceWidth).round();
      final cropY = (coordinates.y * sourceHeight).round();
      final cropWidth = (coordinates.width * sourceWidth).round();
      final cropHeight = (coordinates.height * sourceHeight).round();
      
      // Ensure crop bounds are within image bounds
      final clampedX = math.max(0, math.min(cropX, sourceWidth - 1));
      final clampedY = math.max(0, math.min(cropY, sourceHeight - 1));
      final clampedWidth = math.max(1, math.min(cropWidth, sourceWidth - clampedX));
      final clampedHeight = math.max(1, math.min(cropHeight, sourceHeight - clampedY));
      
      // Create rectangles for crop and resize operation
      final srcRect = ui.Rect.fromLTWH(
        clampedX.toDouble(),
        clampedY.toDouble(),
        clampedWidth.toDouble(),
        clampedHeight.toDouble(),
      );
      
      final dstRect = ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height);
      
      // Apply crop and resize in one operation
      return await _cropAndResizeWithCanvas(sourceImage, srcRect, dstRect, targetSize);
      
    } catch (e) {
      // On error, return a resized version of the original image
      return await _resizeImage(sourceImage, targetSize);
    }
  }
  
  /// Internal method to crop and resize image using Canvas
  static Future<ui.Image> _cropAndResizeWithCanvas(
    ui.Image sourceImage,
    ui.Rect srcRect,
    ui.Rect dstRect,
    ui.Size targetSize,
  ) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    // Draw the cropped and resized image
    canvas.drawImageRect(sourceImage, srcRect, dstRect, ui.Paint());
    
    final picture = recorder.endRecording();
    
    // Convert to image with target dimensions
    final resultImage = await picture.toImage(
      targetSize.width.round(),
      targetSize.height.round(),
    );
    
    // Clean up
    picture.dispose();
    
    return resultImage;
  }
  
  /// Resizes an image to the target size
  static Future<ui.Image> _resizeImage(ui.Image sourceImage, ui.Size targetSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    
    final srcRect = ui.Rect.fromLTWH(0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble());
    final dstRect = ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height);
    
    canvas.drawImageRect(sourceImage, srcRect, dstRect, ui.Paint());
    
    final picture = recorder.endRecording();
    final resizedImage = await picture.toImage(
      targetSize.width.round(),
      targetSize.height.round(),
    );
    
    picture.dispose();
    return resizedImage;
  }
  
  /// Processes an image with smart crop analysis and application in one call
  /// 
  /// [imageUrl] URL or identifier for the image
  /// [sourceImage] The source image to process
  /// [targetSize] The desired output size
  /// [settings] Configuration settings for the analysis
  /// 
  /// Returns a [ProcessedImageResult] with the cropped image and analysis details
  static Future<ProcessedImageResult> processImage(
    String imageUrl,
    ui.Image sourceImage,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    try {
      // Analyze the crop
      final cropResult = await analyzeCrop(imageUrl, sourceImage, targetSize, settings);
      
      // Apply the crop and resize
      final processedImage = await applyCropAndResize(
        sourceImage,
        cropResult.bestCrop,
        targetSize,
      );
      
      return ProcessedImageResult(
        image: processedImage,
        cropResult: cropResult,
        success: true,
        error: null,
      );
      
    } catch (e) {
      // On error, return original image or a safe fallback
      ui.Image fallbackImage;
      CropCoordinates fallbackCrop;
      
      try {
        // Try to create a safe fallback size if target size is invalid
        final safeTargetSize = ui.Size(
          math.max(1, targetSize.width),
          math.max(1, targetSize.height),
        );
        
        fallbackImage = await _resizeImage(sourceImage, safeTargetSize);
        fallbackCrop = _getFallbackCrop(sourceImage, safeTargetSize);
      } catch (fallbackError) {
        // If even fallback fails, return original image
        fallbackImage = sourceImage;
        fallbackCrop = CropCoordinates(
          x: 0.0,
          y: 0.0,
          width: 1.0,
          height: 1.0,
          confidence: 0.0,
          strategy: 'error_fallback',
        );
      }
      
      return ProcessedImageResult(
        image: fallbackImage,
        cropResult: CropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: Duration.zero,
          fromCache: false,
        ),
        success: false,
        error: e.toString(),
      );
    }
  }
  
  /// Estimates memory usage for processing an image
  static int estimateMemoryUsage(ui.Image image, ui.Size targetSize) {
    try {
      // Estimate bytes per pixel (RGBA = 4 bytes)
      const bytesPerPixel = 4;
      
      // Source image memory
      final sourceMemory = image.width * image.height * bytesPerPixel;
      
      // Target image memory
      final targetMemory = targetSize.width.round() * targetSize.height.round() * bytesPerPixel;
      
      // Temporary processing memory for analysis
      // - Downscaled image for analysis (typically 1/4 of original)
      // - Edge detection buffers
      // - Entropy calculation buffers
      final analysisMemory = (sourceMemory / 4) * 3; // Conservative estimate
      
      // Canvas and picture recording memory
      final canvasMemory = math.max(sourceMemory, targetMemory);
      
      return sourceMemory + targetMemory + analysisMemory.round() + canvasMemory;
    } catch (e) {
      // If calculation fails, return a conservative high estimate
      return 200 * 1024 * 1024; // 200MB
    }
  }
  
  /// Gets available system memory (platform-specific)
  static int? _getAvailableMemoryMB() {
    try {
      if (io.Platform.isAndroid) {
        // On Android, we can't easily get available memory from Dart
        // Return null to indicate unknown
        return null;
      } else if (io.Platform.isIOS) {
        // On iOS, we can't easily get available memory from Dart
        // Return null to indicate unknown
        return null;
      } else {
        // On desktop platforms, assume more memory is available
        return 1024; // 1GB assumption for desktop
      }
    } catch (e) {
      return null;
    }
  }
  
  /// Enhanced memory pressure detection with system awareness
  static bool _isSystemUnderMemoryPressure() {
    try {
      final availableMemory = _getAvailableMemoryMB();
      if (availableMemory != null && availableMemory < 100) {
        return true;
      }
      
      // If we can't determine system memory, use conservative approach
      return availableMemory == null;
    } catch (e) {
      return true; // Assume pressure if we can't determine
    }
  }
  
  /// Creates degraded settings for low-resource scenarios
  static CropSettings _createDegradedSettings(CropSettings originalSettings) {
    return originalSettings.copyWith(
      // Disable resource-intensive analyzers
      enableEdgeDetection: false,
      enableEntropyAnalysis: false,
      // Keep only lightweight analyzers
      enableRuleOfThirds: true,
      enableCenterWeighting: true,
      // Reduce timeout
      maxProcessingTime: Duration(
        milliseconds: math.min(
          originalSettings.maxProcessingTime.inMilliseconds,
          1000, // Max 1 second for degraded mode
        ),
      ),
    );
  }
  
  /// Attempts graceful degradation when resources are constrained
  static Future<CropResult> _attemptGracefulDegradation(
    String imageUrl,
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    try {
      // Create degraded settings
      final degradedSettings = _createDegradedSettings(settings);
      
      // Check if even degraded processing is feasible
      if (_shouldSkipSmartCrop(image, targetSize, degradedSettings)) {
        final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'degradation_skip');
        return CropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: Duration.zero,
          fromCache: false,
        );
      }
      
      // Try with degraded settings
      final completer = _createTimeoutCompleter(image, targetSize, degradedSettings);
      _performAnalysisWithFallback(image, targetSize, degradedSettings, completer);
      
      final result = await completer.future;
      
      // Mark result as degraded
      return result.copyWith(
        bestCrop: result.bestCrop.copyWith(
          strategy: '${result.bestCrop.strategy}_degraded',
          confidence: result.bestCrop.confidence * 0.8, // Reduce confidence
        ),
      );
    } catch (e) {
      // If even degraded processing fails, return fallback
      final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'degradation_failure');
      return CropResult(
        bestCrop: fallbackCrop,
        allScores: [],
        processingTime: Duration.zero,
        fromCache: false,
      );
    }
  }
  
  /// Determines if processing should use background isolate
  static bool _shouldUseIsolate(ui.Image image, CropSettings settings) {
    // Use isolate for large images or when multiple heavy analyzers are enabled
    final imageSize = image.width * image.height;
    final heavyAnalyzersCount = [
      settings.enableEntropyAnalysis,
      settings.enableEdgeDetection,
    ].where((enabled) => enabled).length;
    
    return imageSize > (_minImageSizeForIsolate * _minImageSizeForIsolate) ||
           heavyAnalyzersCount >= 2;
  }
  
  /// Prepares image data for isolate processing
  static Future<Map<String, dynamic>> _prepareImageForIsolate(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    try {
      // Downscale image for analysis to reduce data transfer
      final analysisImage = await ImageUtils.downscaleForAnalysis(
        image,
        maxDimension: _maxAnalysisDimension,
      );
      
      // Convert to byte data for isolate transfer
      final imageBytes = await ImageUtils.imageToRgbaBytes(analysisImage);
      
      return {
        'imageBytes': imageBytes,
        'imageWidth': analysisImage.width,
        'imageHeight': analysisImage.height,
        'targetWidth': targetSize.width,
        'targetHeight': targetSize.height,
        'settings': _serializeSettings(settings),
        'originalWidth': image.width,
        'originalHeight': image.height,
      };
    } catch (e) {
      throw Exception('Failed to prepare image for isolate: $e');
    }
  }
  
  /// Serializes crop settings for isolate transfer
  static Map<String, dynamic> _serializeSettings(CropSettings settings) {
    return {
      'aggressiveness': settings.aggressiveness.index,
      'enableRuleOfThirds': settings.enableRuleOfThirds,
      'enableEntropyAnalysis': settings.enableEntropyAnalysis,
      'enableEdgeDetection': settings.enableEdgeDetection,
      'enableCenterWeighting': settings.enableCenterWeighting,
      'maxProcessingTimeMs': settings.maxProcessingTime.inMilliseconds,
    };
  }
  
  /// Deserializes crop settings from isolate data
  static CropSettings _deserializeSettings(Map<String, dynamic> data) {
    return CropSettings(
      aggressiveness: CropAggressiveness.values[data['aggressiveness']],
      enableRuleOfThirds: data['enableRuleOfThirds'],
      enableEntropyAnalysis: data['enableEntropyAnalysis'],
      enableEdgeDetection: data['enableEdgeDetection'],
      enableCenterWeighting: data['enableCenterWeighting'],
      maxProcessingTime: Duration(milliseconds: data['maxProcessingTimeMs']),
    );
  }
  
  /// Processes crop analysis in background isolate
  static Future<CropResult> _processInIsolate(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    try {
      final stopwatch = Stopwatch()..start();
      
      // Prepare data for isolate
      final isolateData = await _prepareImageForIsolate(image, targetSize, settings);
      
      // Create receive port for isolate communication
      final receivePort = ReceivePort();
      final completer = Completer<CropResult>();
      
      // Set up timeout for isolate
      Timer? timeoutTimer;
      timeoutTimer = Timer(_isolateTimeout, () {
        if (!completer.isCompleted) {
          receivePort.close();
          final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'isolate_timeout');
          completer.complete(CropResult(
            bestCrop: fallbackCrop,
            allScores: [],
            processingTime: _isolateTimeout,
            fromCache: false,
          ));
        }
      });
      
      // Listen for isolate results
      receivePort.listen((data) {
        timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          try {
            if (data is Map<String, dynamic> && data['success'] == true) {
              final cropData = data['crop'] as Map<String, dynamic>;
              final crop = CropCoordinates(
                x: cropData['x'],
                y: cropData['y'],
                width: cropData['width'],
                height: cropData['height'],
                confidence: cropData['confidence'],
                strategy: cropData['strategy'],
              );
              
              stopwatch.stop();
              completer.complete(CropResult(
                bestCrop: crop,
                allScores: [], // Isolate doesn't return all scores for performance
                processingTime: stopwatch.elapsed,
                fromCache: false,
              ));
            } else {
              // Isolate failed, use fallback
              final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'isolate_failure');
              stopwatch.stop();
              completer.complete(CropResult(
                bestCrop: fallbackCrop,
                allScores: [],
                processingTime: stopwatch.elapsed,
                fromCache: false,
              ));
            }
          } catch (e) {
            final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'isolate_error');
            stopwatch.stop();
            completer.complete(CropResult(
              bestCrop: fallbackCrop,
              allScores: [],
              processingTime: stopwatch.elapsed,
              fromCache: false,
            ));
          }
        }
        receivePort.close();
      });
      
      // Spawn isolate
      try {
        await Isolate.spawn(
          _isolateEntryPoint,
          {
            'sendPort': receivePort.sendPort,
            'data': isolateData,
          },
        );
      } catch (e) {
        timeoutTimer?.cancel();
        receivePort.close();
        // If isolate spawn fails, fall back to main thread processing
        return _performMainThreadAnalysis(image, targetSize, settings);
      }
      
      return await completer.future;
    } catch (e) {
      // If isolate processing fails completely, fall back to main thread
      return _performMainThreadAnalysis(image, targetSize, settings);
    }
  }
  
  /// Entry point for isolate processing
  static void _isolateEntryPoint(Map<String, dynamic> params) async {
    try {
      final sendPort = params['sendPort'] as SendPort;
      final data = params['data'] as Map<String, dynamic>;
      
      // Reconstruct image and settings in isolate
      final imageBytes = data['imageBytes'] as Uint8List;
      final imageWidth = data['imageWidth'] as int;
      final imageHeight = data['imageHeight'] as int;
      final targetSize = ui.Size(data['targetWidth'], data['targetHeight']);
      final settings = _deserializeSettings(data['settings']);
      
      // Perform lightweight analysis in isolate
      final result = await _performIsolateAnalysis(
        imageBytes,
        imageWidth,
        imageHeight,
        targetSize,
        settings,
      );
      
      sendPort.send({
        'success': true,
        'crop': {
          'x': result.x,
          'y': result.y,
          'width': result.width,
          'height': result.height,
          'confidence': result.confidence,
          'strategy': result.strategy,
        },
      });
    } catch (e) {
      try {
        final sendPort = params['sendPort'] as SendPort;
        sendPort.send({'success': false, 'error': e.toString()});
      } catch (_) {
        // If we can't even send the error, the isolate will timeout
      }
    }
  }
  
  /// Performs analysis within isolate using byte data
  static Future<CropCoordinates> _performIsolateAnalysis(
    Uint8List imageBytes,
    int imageWidth,
    int imageHeight,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    // Simplified analysis for isolate - focus on lightweight algorithms
    final scores = <CropScore>[];
    
    // Rule of thirds analysis (lightweight)
    if (settings.enableRuleOfThirds) {
      final ruleOfThirdsScore = _calculateRuleOfThirdsInIsolate(
        imageBytes,
        imageWidth,
        imageHeight,
        targetSize,
      );
      scores.add(ruleOfThirdsScore);
    }
    
    // Center weighted analysis (lightweight)
    if (settings.enableCenterWeighting) {
      final centerScore = _calculateCenterWeightedInIsolate(
        imageWidth,
        imageHeight,
        targetSize,
      );
      scores.add(centerScore);
    }
    
    // Select best score
    if (scores.isEmpty) {
      return _createFallbackCropInIsolate(imageWidth, imageHeight, targetSize);
    }
    
    scores.sort((a, b) => b.score.compareTo(a.score));
    return scores.first.coordinates;
  }
  
  /// Lightweight rule of thirds calculation for isolate
  static CropScore _calculateRuleOfThirdsInIsolate(
    Uint8List imageBytes,
    int imageWidth,
    int imageHeight,
    ui.Size targetSize,
  ) {
    // Simplified rule of thirds - just check intersection points
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageWidth / imageHeight;
    
    double cropWidth, cropHeight;
    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }
    
    // Position crop using rule of thirds
    final x = (1.0 - cropWidth) * 0.33; // Offset by 1/3
    final y = (1.0 - cropHeight) * 0.33;
    
    final coordinates = CropCoordinates(
      x: x,
      y: y,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.7,
      strategy: 'rule_of_thirds_isolate',
    );
    
    return CropScore(
      coordinates: coordinates,
      score: 0.7,
      strategy: 'rule_of_thirds_isolate',
      metrics: {'isolate_processed': 1.0},
    );
  }
  
  /// Lightweight center weighted calculation for isolate
  static CropScore _calculateCenterWeightedInIsolate(
    int imageWidth,
    int imageHeight,
    ui.Size targetSize,
  ) {
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageWidth / imageHeight;
    
    double cropWidth, cropHeight;
    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }
    
    final coordinates = CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.8,
      strategy: 'center_weighted_isolate',
    );
    
    return CropScore(
      coordinates: coordinates,
      score: 0.8,
      strategy: 'center_weighted_isolate',
      metrics: {'isolate_processed': 1.0},
    );
  }
  
  /// Creates fallback crop in isolate
  static CropCoordinates _createFallbackCropInIsolate(
    int imageWidth,
    int imageHeight,
    ui.Size targetSize,
  ) {
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageWidth / imageHeight;
    
    double cropWidth, cropHeight;
    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }
    
    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.5,
      strategy: 'isolate_fallback',
    );
  }
  
  /// Performs analysis on main thread with optimizations
  static Future<CropResult> _performMainThreadAnalysis(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      // Downscale image for analysis
      final analysisImage = await ImageUtils.downscaleForAnalysis(
        image,
        maxDimension: _maxAnalysisDimension,
      );
      
      // Create timeout completer
      final completer = _createTimeoutCompleter(analysisImage, targetSize, settings);
      
      // Perform optimized analysis
      _performOptimizedAnalysis(analysisImage, targetSize, settings, completer);
      
      final result = await completer.future;
      
      // Clean up analysis image if it's different from original
      if (analysisImage != image) {
        analysisImage.dispose();
      }
      
      stopwatch.stop();
      return result.copyWith(processingTime: stopwatch.elapsed);
    } catch (e) {
      stopwatch.stop();
      final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'main_thread_error');
      return CropResult(
        bestCrop: fallbackCrop,
        allScores: [],
        processingTime: stopwatch.elapsed,
        fromCache: false,
      );
    }
  }
  
  /// Performs optimized analysis with concurrent processing
  static Future<void> _performOptimizedAnalysis(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
    Completer<CropResult> completer,
  ) async {
    try {
      final analyzers = _createAnalyzers(settings);
      final futures = <Future<CropScore?>>[];
      
      // Limit concurrent analyzers to prevent resource exhaustion
      final concurrentAnalyzers = math.min(analyzers.length, _maxConcurrentAnalyzers);
      
      for (int i = 0; i < concurrentAnalyzers; i++) {
        if (i < analyzers.length) {
          futures.add(_runAnalyzerSafely(analyzers[i], image, targetSize));
        }
      }
      
      // Wait for all analyzers to complete or timeout
      final results = await Future.wait(futures);
      final scores = results.where((score) => score != null).cast<CropScore>().toList();
      
      // If we have remaining analyzers and time, run them
      if (analyzers.length > concurrentAnalyzers && !completer.isCompleted) {
        for (int i = concurrentAnalyzers; i < analyzers.length; i++) {
          if (completer.isCompleted) break;
          
          try {
            final score = await analyzers[i].analyze(image, targetSize);
            if (score.isValid && score.score >= analyzers[i].minConfidenceThreshold) {
              scores.add(score);
            }
          } catch (e) {
            // Continue with other analyzers
            continue;
          }
        }
      }
      
      // Select best crop
      if (scores.isEmpty) {
        final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'no_valid_scores');
        if (!completer.isCompleted) {
          completer.complete(CropResult(
            bestCrop: fallbackCrop,
            allScores: [],
            processingTime: Duration.zero,
            fromCache: false,
          ));
        }
        return;
      }
      
      final bestCrop = _selectBestCrop(scores, settings);
      
      if (!completer.isCompleted) {
        completer.complete(CropResult(
          bestCrop: bestCrop,
          allScores: scores,
          processingTime: Duration.zero,
          fromCache: false,
        ));
      }
    } catch (e) {
      if (!completer.isCompleted) {
        final fallbackCrop = _getFallbackCrop(image, targetSize, fallbackReason: 'optimized_analysis_error');
        completer.complete(CropResult(
          bestCrop: fallbackCrop,
          allScores: [],
          processingTime: Duration.zero,
          fromCache: false,
        ));
      }
    }
  }
  
  /// Runs an analyzer safely with error handling
  static Future<CropScore?> _runAnalyzerSafely(
    CropAnalyzer analyzer,
    ui.Image image,
    ui.Size targetSize,
  ) async {
    try {
      final score = await analyzer.analyze(image, targetSize);
      if (score.isValid && score.score >= analyzer.minConfidenceThreshold) {
        return score;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
  
  /// Performs efficient memory cleanup for temporary image data
  static void _cleanupTemporaryImages(List<ui.Image> images) {
    for (final image in images) {
      try {
        image.dispose();
      } catch (e) {
        // Ignore disposal errors
      }
    }
  }
  
  /// Monitors performance during processing
  static Future<T> _withPerformanceMonitoring<T>(
    String operationName,
    Future<T> Function() operation,
  ) async {
    final stopwatch = Stopwatch()..start();
    
    try {
      final result = await operation();
      stopwatch.stop();
      
      return result;
    } catch (e) {
      stopwatch.stop();
      rethrow;
    }
  }
  
  /// Records performance metrics
  static void _recordPerformanceMetric(
    String operation,
    Duration duration,
    bool success, [
    Map<String, dynamic>? metadata,
  ]) {
    if (success) {
      _performanceMonitor.recordSuccess(operation, duration, metadata: metadata);
    } else {
      _performanceMonitor.recordFailure(
        operation, 
        duration, 
        metadata?['error']?.toString() ?? 'Unknown error',
        metadata: metadata,
      );
    }
  }
  

  
  /// Gets performance statistics for monitoring (legacy method)
  static Map<String, dynamic> getPerformanceStats() {
    // Use the new performance monitor for consistency
    final analytics = _performanceMonitor.exportAnalyticsData();
    final overallStats = analytics['overall_stats'] as Map<String, dynamic>;
    
    return {
      'total_operations': overallStats['total_operations'],
      'average_duration_ms': overallStats['average_duration_ms'],
      'success_rate': overallStats['success_rate'],
      'operations': analytics['operation_stats'] ?? {},
    };
  }
  
  /// Clears performance metrics (legacy method)
  static void clearPerformanceStats() {
    _performanceMonitor.clear();
  }
  
  /// Benchmarks crop processing performance
  static Future<Map<String, dynamic>> benchmarkPerformance(
    ui.Image testImage,
    ui.Size targetSize, {
    int iterations = 5,
    CropSettings? settings,
  }) async {
    final benchmarkSettings = settings ?? CropSettings.defaultSettings;
    final results = <Duration>[];
    final errors = <String>[];
    
    for (int i = 0; i < iterations; i++) {
      try {
        final stopwatch = Stopwatch()..start();
        
        await analyzeCrop(
          'benchmark_$i',
          testImage,
          targetSize,
          benchmarkSettings,
        );
        
        stopwatch.stop();
        results.add(stopwatch.elapsed);
      } catch (e) {
        errors.add(e.toString());
      }
    }
    
    if (results.isEmpty) {
      return {
        'success': false,
        'error': 'All benchmark iterations failed',
        'errors': errors,
      };
    }
    
    final totalMs = results.map((d) => d.inMilliseconds).reduce((a, b) => a + b);
    final averageMs = totalMs / results.length;
    final minMs = results.map((d) => d.inMilliseconds).reduce(math.min);
    final maxMs = results.map((d) => d.inMilliseconds).reduce(math.max);
    
    return {
      'success': true,
      'iterations': iterations,
      'successful_iterations': results.length,
      'failed_iterations': errors.length,
      'average_duration_ms': averageMs,
      'min_duration_ms': minMs,
      'max_duration_ms': maxMs,
      'total_duration_ms': totalMs,
      'errors': errors,
      'memory_usage_estimate_mb': estimateMemoryUsage(testImage, targetSize) / (1024 * 1024),
    };
  }
  
  /// Checks if image processing should be performed based on memory constraints
  static bool shouldProcessImage(ui.Image image, ui.Size targetSize, {int maxMemoryMB = 100}) {
    final estimatedMemory = estimateMemoryUsage(image, targetSize);
    final maxMemoryBytes = maxMemoryMB * 1024 * 1024;
    
    return estimatedMemory <= maxMemoryBytes;
  }
  
  /// Gets performance analytics data
  static Map<String, dynamic> getPerformanceAnalytics() {
    return _performanceMonitor.exportAnalyticsData();
  }
  
  /// Gets current device capability information
  static Future<Map<String, dynamic>> getDeviceCapabilityInfo() async {
    final capability = await _getDeviceCapability();
    final batteryStrategy = await BatteryOptimizer.getOptimizationStrategy();
    
    return {
      'device_capability': {
        'platform': capability.platform.toString(),
        'overall_tier': capability.overallTier.toString(),
        'memory_tier': capability.memoryTier.toString(),
        'processing_tier': capability.processingTier.toString(),
        'battery_optimized': capability.batteryOptimized,
        'max_concurrent_analyzers': capability.maxConcurrentAnalyzers,
        'max_image_dimension': capability.maxImageDimension,
        'timeout_multiplier': capability.timeoutMultiplier,
      },
      'battery_optimization': {
        'strategy': batteryStrategy.toString(),
        'throttle_background': batteryStrategy.throttleBackgroundProcessing,
        'processing_delay_ms': batteryStrategy.processingDelay.inMilliseconds,
        'defer_processing': batteryStrategy.deferProcessing,
      },
      'performance_constants': {
        'max_analysis_dimension': _maxAnalysisDimension,
        'min_image_size_for_isolate': _minImageSizeForIsolate,
        'max_concurrent_analyzers': _maxConcurrentAnalyzers,
      },
    };
  }
  
  /// Clears performance monitoring data
  static void clearPerformanceData() {
    _performanceMonitor.clear();
  }
  
  /// Clears device capability cache (useful for testing)
  static void clearDeviceCapabilityCache() {
    _deviceCapability = null;
    DeviceCapabilityDetector.clearCache();
    BatteryOptimizer.clearCache();
  }
  
  /// Closes the cache manager and cleans up resources
  static Future<void> close() async {
    await _cacheManager?.close();
    _cacheManager = null;
    _imageCache.clear();
    _performanceMonitor.clear();
    clearDeviceCapabilityCache();
  }
}

/// Result of a complete image processing operation
class ProcessedImageResult {
  /// The processed (cropped and resized) image
  final ui.Image image;
  
  /// The crop analysis result
  final CropResult cropResult;
  
  /// Whether the processing was successful
  final bool success;
  
  /// Error message if processing failed
  final String? error;
  
  const ProcessedImageResult({
    required this.image,
    required this.cropResult,
    required this.success,
    this.error,
  });
  
  @override
  String toString() {
    return 'ProcessedImageResult(success: $success, error: $error, cropResult: $cropResult)';
  }
}