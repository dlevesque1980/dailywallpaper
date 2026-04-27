import 'dart:async';
import 'dart:collection';
import 'dart:ui' as ui;

import '../models/crop_coordinates.dart';
import '../models/crop_settings.dart';
import '../models/crop_score.dart';
import '../interfaces/crop_analyzer.dart';

/// Optimized image processing pipeline with multi-resolution analysis and parallel execution
class ImageProcessingPipeline {
  static const int _maxConcurrentAnalyzers = 3;

  final Map<String, ui.Image> _resolutionCache = {};
  final Set<String> _processingImages = {};

  /// Processes image with multiple analyzers in parallel
  Future<List<CropAnalysisResult>> processImage(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
    List<CropAnalyzer> analyzers,
  ) async {
    final imageKey = '${image.width}x${image.height}';

    if (_processingImages.contains(imageKey)) {
      await _waitForProcessing(imageKey);
    }

    _processingImages.add(imageKey);

    try {
      final analysisImage = await _getOptimalResolutionImage(image, settings);
      final analyzerGroups = _groupAnalyzersByStrategy(analyzers, settings);

      final results = <CropAnalysisResult>[];

      if (analyzerGroups.highPriority.isNotEmpty) {
        final highPriorityResults = await _executeAnalyzersParallel(
          analysisImage,
          targetSize,
          settings,
          analyzerGroups.highPriority,
        );
        results.addAll(highPriorityResults);

        // Check if we should continue based on time budget
        if (_shouldTerminateEarly(settings, results)) {
          return results;
        }
      }

      if (analyzerGroups.mediumPriority.isNotEmpty) {
        final mediumPriorityResults = await _executeAnalyzersParallel(
          analysisImage,
          targetSize,
          settings,
          analyzerGroups.mediumPriority,
        );
        results.addAll(mediumPriorityResults);

        if (_shouldTerminateEarly(settings, results)) {
          return results;
        }
      }

      if (analyzerGroups.lowPriority.isNotEmpty) {
        final lowPriorityResults = await _executeAnalyzersParallel(
          analysisImage,
          targetSize,
          settings,
          analyzerGroups.lowPriority,
        );
        results.addAll(lowPriorityResults);
      }

      return results;
    } finally {
      _processingImages.remove(imageKey);
    }
  }

  Future<ui.Image> _getOptimalResolutionImage(
      ui.Image image, CropSettings settings) async {
    final originalSize =
        ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetResolution =
        _calculateOptimalResolution(originalSize, settings);

    if (targetResolution == originalSize) {
      return image;
    }

    final cacheKey =
        '${image.width}x${image.height}_${targetResolution.width}x${targetResolution.height}';

    if (_resolutionCache.containsKey(cacheKey)) {
      return _resolutionCache[cacheKey]!;
    }

    final resizedImage = await _resizeImage(image, targetResolution);
    _resolutionCache[cacheKey] = resizedImage;

    if (_resolutionCache.length > 10) {
      final oldestKey = _resolutionCache.keys.first;
      _resolutionCache.remove(oldestKey);
    }

    return resizedImage;
  }

  ui.Size _calculateOptimalResolution(
      ui.Size originalSize, CropSettings settings) {
    final maxDimension = _getMaxAnalysisDimension(settings);

    if (originalSize.width <= maxDimension &&
        originalSize.height <= maxDimension) {
      return originalSize;
    }

    final aspectRatio = originalSize.width / originalSize.height;

    if (originalSize.width > originalSize.height) {
      return ui.Size(maxDimension, maxDimension / aspectRatio);
    } else {
      return ui.Size(maxDimension * aspectRatio, maxDimension);
    }
  }

  double _getMaxAnalysisDimension(CropSettings settings) {
    switch (settings.aggressiveness) {
      case CropAggressiveness.conservative:
        return 800.0;
      case CropAggressiveness.balanced:
        return 1200.0;
      case CropAggressiveness.aggressive:
        return 1920.0;
    }
  }

  Future<ui.Image> _resizeImage(ui.Image image, ui.Size targetSize) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, targetSize.width, targetSize.height),
      paint,
    );

    final picture = recorder.endRecording();
    return await picture.toImage(
        targetSize.width.toInt(), targetSize.height.toInt());
  }

  AnalyzerGroups _groupAnalyzersByStrategy(
      List<CropAnalyzer> analyzers, CropSettings settings) {
    final highPriority = <CropAnalyzer>[];
    final mediumPriority = <CropAnalyzer>[];
    final lowPriority = <CropAnalyzer>[];

    for (final analyzer in analyzers) {
      switch (analyzer.priority) {
        case AnalyzerPriority.high:
          highPriority.add(analyzer);
          break;
        case AnalyzerPriority.medium:
          mediumPriority.add(analyzer);
          break;
        case AnalyzerPriority.low:
          lowPriority.add(analyzer);
          break;
      }
    }

    return AnalyzerGroups(
      highPriority: highPriority,
      mediumPriority: mediumPriority,
      lowPriority: lowPriority,
    );
  }

  Future<List<CropAnalysisResult>> _executeAnalyzersParallel(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
    List<CropAnalyzer> analyzers,
  ) async {
    final results = <CropAnalysisResult>[];
    final semaphore = Semaphore(_maxConcurrentAnalyzers);

    final futures = analyzers.map((analyzer) async {
      await semaphore.acquire();
      try {
        final stopwatch = Stopwatch()..start();

        final coordinates = await analyzer
            .analyze(image, targetSize)
            .timeout(settings.maxProcessingTime);

        stopwatch.stop();

        return CropAnalysisResult(
          analyzerName: analyzer.strategyName,
          coordinates: _convertScoreToCoordinates(coordinates, targetSize),
          processingTime: stopwatch.elapsed,
          confidence: coordinates.score,
        );
      } catch (e) {
        return CropAnalysisResult(
          analyzerName: analyzer.strategyName,
          coordinates: _getFallbackCoordinates(targetSize),
          processingTime: Duration.zero,
          confidence: 0.0,
          error: e.toString(),
        );
      } finally {
        semaphore.release();
      }
    });

    final completedResults = await Future.wait(futures);
    results.addAll(completedResults.where((result) => result.error == null));

    return results;
  }

  CropCoordinates _convertScoreToCoordinates(
      CropScore score, ui.Size targetSize) {
    return CropCoordinates(
      x: score.coordinates.x,
      y: score.coordinates.y,
      width: score.coordinates.width,
      height: score.coordinates.height,
      confidence: score.score,
      strategy: score.strategy,
    );
  }

  CropCoordinates _getFallbackCoordinates(ui.Size targetSize) {
    return CropCoordinates(
      x: 0.0,
      y: 0.0,
      width: targetSize.width,
      height: targetSize.height,
      confidence: 0.1,
      strategy: 'fallback',
    );
  }

  Future<void> _waitForProcessing(String imageKey) async {
    while (_processingImages.contains(imageKey)) {
      await Future.delayed(const Duration(milliseconds: 100));
    }
  }

  /// Checks if processing should terminate early based on time budget
  bool _shouldTerminateEarly(
      CropSettings settings, List<CropAnalysisResult> results) {
    final totalTime = results.fold<Duration>(
      Duration.zero,
      (sum, result) => sum + result.processingTime,
    );

    return totalTime >= settings.maxProcessingTime;
  }

  /// Preprocesses image for optimal analysis
  Future<ui.Image> preprocessImage(
      ui.Image image, CropSettings settings) async {
    // Always enhance for better analysis in aggressive mode
    if (settings.aggressiveness == CropAggressiveness.aggressive) {
      return await _enhanceImageForAnalysis(image, settings);
    }

    return image;
  }

  /// Enhances image for better analysis results
  Future<ui.Image> _enhanceImageForAnalysis(
      ui.Image image, CropSettings settings) async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);

    // Apply color matrix for better contrast
    final paint = ui.Paint()
      ..colorFilter = const ui.ColorFilter.matrix([
        1.2, 0, 0, 0, 0, // Red channel (slight boost)
        0, 1.2, 0, 0, 0, // Green channel (slight boost)
        0, 0, 1.2, 0, 0, // Blue channel (slight boost)
        0, 0, 0, 1, 0, // Alpha channel (unchanged)
      ]);

    canvas.drawImage(image, ui.Offset.zero, paint);

    final picture = recorder.endRecording();
    return await picture.toImage(image.width, image.height);
  }

  void clearCache() {
    _resolutionCache.clear();
  }

  CacheStats getCacheStats() {
    return CacheStats(
      cachedImages: _resolutionCache.length,
      processingImages: _processingImages.length,
    );
  }
}

class Semaphore {
  final int maxCount;
  int _currentCount;
  final Queue<Completer<void>> _waitQueue = Queue<Completer<void>>();

  Semaphore(this.maxCount) : _currentCount = maxCount;

  Future<void> acquire() async {
    if (_currentCount > 0) {
      _currentCount--;
      return;
    }

    final completer = Completer<void>();
    _waitQueue.add(completer);
    return completer.future;
  }

  void release() {
    if (_waitQueue.isNotEmpty) {
      final completer = _waitQueue.removeFirst();
      completer.complete();
    } else {
      _currentCount++;
    }
  }
}

class AnalyzerGroups {
  final List<CropAnalyzer> highPriority;
  final List<CropAnalyzer> mediumPriority;
  final List<CropAnalyzer> lowPriority;

  const AnalyzerGroups({
    required this.highPriority,
    required this.mediumPriority,
    required this.lowPriority,
  });
}

class CropAnalysisResult {
  final String analyzerName;
  final CropCoordinates coordinates;
  final Duration processingTime;
  final double confidence;
  final String? error;

  const CropAnalysisResult({
    required this.analyzerName,
    required this.coordinates,
    required this.processingTime,
    required this.confidence,
    this.error,
  });

  bool get isSuccessful => error == null;

  @override
  String toString() {
    return 'CropAnalysisResult($analyzerName: confidence=${confidence.toStringAsFixed(2)}, '
        'time=${processingTime.inMilliseconds}ms, success=$isSuccessful)';
  }
}

class CacheStats {
  final int cachedImages;
  final int processingImages;

  const CacheStats({
    required this.cachedImages,
    required this.processingImages,
  });

  @override
  String toString() {
    return 'CacheStats(cached: $cachedImages, processing: $processingImages)';
  }
}

enum CropQuality {
  fast,
  balanced,
  highQuality,
}

enum AnalyzerPriority {
  high,
  medium,
  low,
}

extension CropAnalyzerPriority on CropAnalyzer {
  AnalyzerPriority get priority {
    switch (strategyName.toLowerCase()) {
      case 'face_detection':
      case 'object_detection':
        return AnalyzerPriority.high;
      case 'composition':
      case 'rule_of_thirds':
        return AnalyzerPriority.medium;
      default:
        return AnalyzerPriority.low;
    }
  }
}
