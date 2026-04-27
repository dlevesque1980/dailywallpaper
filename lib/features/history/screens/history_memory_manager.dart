import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';

/// Memory manager for the history screen to optimize performance
/// and prevent memory leaks when switching between dates
class HistoryMemoryManager {
  static final HistoryMemoryManager _instance =
      HistoryMemoryManager._internal();
  factory HistoryMemoryManager() => _instance;
  HistoryMemoryManager._internal();

  // Track memory usage and cleanup
  final Map<String, Timer> _cleanupTimers = {};
  final Map<String, DateTime> _lastAccessed = {};
  final Set<String> _activeImages = {};

  // Memory thresholds
  static const int maxCachedImages = 50;
  static const Duration cleanupDelay = Duration(minutes: 2);
  static const Duration accessTimeout = Duration(minutes: 5);

  /// Register an image as active (currently being displayed)
  void registerActiveImage(String imageKey) {
    _activeImages.add(imageKey);
    _lastAccessed[imageKey] = DateTime.now();

    // Cancel any pending cleanup for this image
    _cleanupTimers[imageKey]?.cancel();
    _cleanupTimers.remove(imageKey);

    debugPrint('Registered active image: $imageKey');
  }

  /// Unregister an image as active (no longer being displayed)
  void unregisterActiveImage(String imageKey) {
    _activeImages.remove(imageKey);

    // Schedule cleanup after delay
    _scheduleCleanup(imageKey);

    debugPrint('Unregistered active image: $imageKey');
  }

  /// Schedule cleanup for an inactive image
  void _scheduleCleanup(String imageKey) {
    _cleanupTimers[imageKey]?.cancel();

    _cleanupTimers[imageKey] = Timer(cleanupDelay, () {
      _performCleanup(imageKey);
    });
  }

  /// Perform actual cleanup for an image
  void _performCleanup(String imageKey) {
    if (_activeImages.contains(imageKey)) {
      // Image became active again, don't clean up
      return;
    }

    final lastAccess = _lastAccessed[imageKey];
    if (lastAccess != null) {
      final timeSinceAccess = DateTime.now().difference(lastAccess);
      if (timeSinceAccess < accessTimeout) {
        // Still recently accessed, reschedule
        _scheduleCleanup(imageKey);
        return;
      }
    }

    // Clean up the image
    _lastAccessed.remove(imageKey);
    _cleanupTimers.remove(imageKey);

    debugPrint('Cleaned up inactive image: $imageKey');
  }

  /// Force cleanup of all inactive images
  void forceCleanupInactive() {
    final inactiveKeys = _lastAccessed.keys
        .where((key) => !_activeImages.contains(key))
        .toList();

    for (final key in inactiveKeys) {
      _performCleanup(key);
    }

    debugPrint('Force cleaned up ${inactiveKeys.length} inactive images');
  }

  /// Clean up old images when memory pressure is detected
  void cleanupOnMemoryPressure() {
    final now = DateTime.now();
    final keysToCleanup = <String>[];

    // Find images that haven't been accessed recently
    for (final entry in _lastAccessed.entries) {
      if (!_activeImages.contains(entry.key)) {
        final timeSinceAccess = now.difference(entry.value);
        if (timeSinceAccess > Duration(minutes: 1)) {
          keysToCleanup.add(entry.key);
        }
      }
    }

    // Clean up oldest images first if we have too many cached
    if (_lastAccessed.length > maxCachedImages) {
      final sortedEntries = _lastAccessed.entries.toList()
        ..sort((a, b) => a.value.compareTo(b.value));

      final excessCount = _lastAccessed.length - maxCachedImages;
      for (int i = 0; i < excessCount && i < sortedEntries.length; i++) {
        final key = sortedEntries[i].key;
        if (!_activeImages.contains(key)) {
          keysToCleanup.add(key);
        }
      }
    }

    // Perform cleanup
    for (final key in keysToCleanup) {
      _performCleanup(key);
    }

    if (keysToCleanup.isNotEmpty) {
      debugPrint(
          'Memory pressure cleanup: removed ${keysToCleanup.length} images');
    }
  }

  /// Get memory usage statistics
  Map<String, dynamic> getMemoryStats() {
    return {
      'active_images': _activeImages.length,
      'cached_images': _lastAccessed.length,
      'pending_cleanups': _cleanupTimers.length,
      'memory_pressure': _lastAccessed.length > maxCachedImages,
    };
  }

  /// Clear all memory and cancel all timers
  void dispose() {
    for (final timer in _cleanupTimers.values) {
      timer.cancel();
    }

    _cleanupTimers.clear();
    _lastAccessed.clear();
    _activeImages.clear();

    debugPrint('HistoryMemoryManager disposed');
  }

  /// Estimate memory usage of an image
  static int estimateImageMemoryUsage(ui.Image image) {
    // Rough estimate: width * height * 4 bytes per pixel (RGBA)
    return image.width * image.height * 4;
  }

  /// Check if system is under memory pressure
  static bool isMemoryPressureHigh() {
    // This is a simplified check - in a real app you might use
    // platform-specific APIs to check actual memory usage
    return false; // Placeholder implementation
  }

  /// Optimize image for memory usage
  static Future<ui.Image?> optimizeImageForMemory(
    ui.Image sourceImage, {
    int maxDimension = 1920,
  }) async {
    if (sourceImage.width <= maxDimension &&
        sourceImage.height <= maxDimension) {
      return sourceImage; // No optimization needed
    }

    try {
      // Calculate new dimensions maintaining aspect ratio
      final aspectRatio = sourceImage.width / sourceImage.height;
      int newWidth, newHeight;

      if (sourceImage.width > sourceImage.height) {
        newWidth = maxDimension;
        newHeight = (maxDimension / aspectRatio).round();
      } else {
        newHeight = maxDimension;
        newWidth = (maxDimension * aspectRatio).round();
      }

      // Create a new image with reduced dimensions
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      canvas.drawImageRect(
        sourceImage,
        ui.Rect.fromLTWH(
            0, 0, sourceImage.width.toDouble(), sourceImage.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        ui.Paint(),
      );

      final picture = recorder.endRecording();
      final optimizedImage = await picture.toImage(newWidth, newHeight);
      picture.dispose();

      debugPrint(
          'Optimized image from ${sourceImage.width}x${sourceImage.height} to ${newWidth}x${newHeight}');
      return optimizedImage;
    } catch (e) {
      debugPrint('Error optimizing image: $e');
      return sourceImage; // Return original on error
    }
  }
}
