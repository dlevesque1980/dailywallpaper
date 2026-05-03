import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart';

import '../cache/ml_subject_cache.dart';
import '../interfaces/analysis_context.dart';
import '../interfaces/analyzer_metadata.dart';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_coordinates.dart';
import '../models/crop_score.dart';
import '../models/crop_settings.dart';
import '../utils/device_capability_detector.dart';

/// ML Kit-based subject detection analyzer for smart cropping.
///
/// Uses [SubjectSegmenter] from `google_mlkit_subject_segmentation` to detect
/// the primary subject in an image and generate [CropCoordinates] centred on
/// that subject.
///
/// Key behaviours:
/// - Checks [MlSubjectCache] before calling ML Kit (cache-first).
/// - Resizes the image to at most 512 px on the longest side before inference.
/// - Returns coordinates relative to the *original* image, not the resized one.
/// - Exposes subject bounds in [CropScore.metrics] under `subject_x/y/width/height`.
/// - Always releases ML Kit resources via `try/finally`.
/// - Returns `score=0.0` on error, timeout, or no-detection — never throws.
class MlSubjectCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'ml_subject_detection';
  static const int _analyzerPriority = 180;
  static const double _analyzerWeight = 0.85;
  static const int _maxImageDimension = 256;

  @override
  double get minConfidenceThreshold => 0.4;

  @override
  bool get isEnabledByDefault => true;

  final MlSubjectCache _cache;

  MlSubjectCropAnalyzer({MlSubjectCache? cache})
      : _cache = cache ?? MlSubjectCache(),
        super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 5000),
          metadata: const AnalyzerMetadata(
            description:
                'ML Kit subject segmentation for precise crop detection',
            version: '1.0.0',
            isCpuIntensive: true,
            isMemoryIntensive: true,
            supportsParallelExecution: false,
          ),
        );

  // ---------------------------------------------------------------------------
  // CropAnalyzerV2 overrides
  // ---------------------------------------------------------------------------

  @override
  bool canAnalyze(ui.Image image, CropSettings settings) {
    final enabled = settings.enableMlSubjectDetection;
    if (enabled) {
      print('[ML] canAnalyze: YES (image: ${image.width}x${image.height})');
    }
    return enabled && image.width > 0 && image.height > 0;
  }

  /// Entry point used by [SmartCropEngine] — context carries the [imageId]
  /// used as cache key.
  @override
  Future<CropScore> analyzeWithContext(
    ui.Image image,
    ui.Size targetSize,
    AnalysisContext context,
  ) async {
    print('[ML] analyzeWithContext called for ${context.imageId}');
    final imageUrl = context.imageId;
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      return await Future.any([
        _runAnalysis(image, imageSize, targetAspectRatio, imageUrl),
        Future.delayed(maxProcessingTime,
            () => _timeoutScore(imageSize, targetAspectRatio)),
      ]);
    } catch (e) {
      return _errorScore(imageSize, targetAspectRatio, e);
    }
  }

  /// Fallback used when no [AnalysisContext] is available.
  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      return await Future.any([
        _runAnalysis(image, imageSize, targetAspectRatio, null),
        Future.delayed(maxProcessingTime,
            () => _timeoutScore(imageSize, targetAspectRatio)),
      ]);
    } catch (e) {
      return _errorScore(imageSize, targetAspectRatio, e);
    }
  }

  // ---------------------------------------------------------------------------
  // Core analysis logic
  // ---------------------------------------------------------------------------

  Future<CropScore> _runAnalysis(
    ui.Image image,
    ui.Size imageSize,
    double targetAspectRatio,
    String? imageUrl,
  ) async {
    // 1. Cache look-up (skip when no URL is available).
    if (imageUrl != null) {
      final cached = await _cache.getSubjectBounds(imageUrl);
      if (cached != null) {
        return _scoreFromBounds(cached, imageSize, targetAspectRatio);
      }
    }

    // 1.5. Emulator/Simulator check for graceful fallback.
    final capabilities = await DeviceCapabilityDetector.getDeviceCapability();
    if (capabilities.isEmulator) {
      print('[ML] Emulator detected - using simulation to avoid GPU crash');
      return _runSimulation(imageSize, targetAspectRatio, imageUrl);
    }

    // 2. Resize image to at most 512 px on the longest side.
    final resized = await _resizeImage(image);
    final resizedSize =
        ui.Size(resized.width.toDouble(), resized.height.toDouble());

    // 3. Run ML Kit segmentation.
    final segmenter = SubjectSegmenter(
      options: SubjectSegmenterOptions(
        enableForegroundBitmap: false,
        enableForegroundConfidenceMask: true,
        enableMultipleSubjects: SubjectResultOptions(
          enableConfidenceMask: false,
          enableSubjectBitmap: false,
        ),
      ),
    );

    try {
      final inputImage = await _toInputImage(resized);
      print('[ML] Starting segmentation for $imageUrl...');
      final result = await segmenter.processImage(inputImage);

      // 4. Compute subject bounds and confidence from the foreground confidence mask.
      // Use compute() to offload the heavy double loop over 65k+ pixels to a worker isolate.
      final detectionResult = await compute(_computeSubjectDetectionIsolate, {
        'mask': result.foregroundConfidenceMask,
        'width': resizedSize.width.toInt(),
        'height': resizedSize.height.toInt(),
      });

      if (detectionResult == null) {
        print('[ML] No subject detected for $imageUrl');
        return _noDetectionScore(imageSize, targetAspectRatio);
      }

      final bounds = detectionResult.bounds;
      final confidence = detectionResult.confidence;

      print('[ML] Subject found at ${bounds.x}, ${bounds.y}');

      // 5. Persist to cache.
      if (imageUrl != null) {
        await _cache.saveSubjectBounds(imageUrl, bounds);
      }

      return _scoreFromBounds(bounds, imageSize, targetAspectRatio, confidence);
    } on PlatformException catch (e) {
      // ML Kit not available on this platform.
      print('[ML] PlatformException: ${e.message}');
      return _errorScore(imageSize, targetAspectRatio, e);
    } on MissingPluginException catch (e) {
      // Plugin not registered (e.g. running in flutter test without native channels)
      print('[ML] MissingPluginException: ${e.message}');
      return _errorScore(imageSize, targetAspectRatio, e);
    } finally {
      try {
        await segmenter.close();
      } catch (_) {
        // Ignored when running in test environment
      }
    }
  }

  /// Simulation fallback for emulators where MediaPipe GPU delegate crashes.
  /// Returns a subject centered on the image with 40% width/height.
  Future<CropScore> _runSimulation(
    ui.Size imageSize,
    double targetAspectRatio,
    String? imageUrl,
  ) async {
    // Artificial delay to simulate processing
    await Future.delayed(const Duration(milliseconds: 150));

    // Simulation fallback: return a full-frame box (standard center crop)
    // with a near-zero score so it only acts as an ultimate fallback
    // and never overrides real CPU-based analyzers.
    final bounds = SubjectBounds(
      x: 0.0,
      y: 0.0,
      width: 1.0,
      height: 1.0,
    );

    final coords =
        _cropCoordinatesFromBounds(bounds, imageSize, targetAspectRatio);
    return CropScore(
      coordinates: coords,
      score: 0.1, // Very low score for simulation so real analyzers win
      strategy: 'ml_subject_simulation',
      metrics: {
        'subject_x': bounds.x,
        'subject_y': bounds.y,
        'subject_width': bounds.width,
        'subject_height': bounds.height,
        'simulated': true,
      },
    );
  }

  // ---------------------------------------------------------------------------
  // Image helpers
  // ---------------------------------------------------------------------------

  /// Resizes [image] so that `max(width, height) <= 512`.
  /// Returns the original image unchanged if it already fits.
  Future<ui.Image> _resizeImage(ui.Image image) async {
    final maxDim = math.max(image.width, image.height);
    if (maxDim <= _maxImageDimension) return image;

    final scale = _maxImageDimension / maxDim;
    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();

    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..filterQuality = ui.FilterQuality.medium;

    canvas.drawImageRect(
      image,
      ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
      paint,
    );

    final picture = recorder.endRecording();
    return picture.toImage(newWidth, newHeight);
  }

  /// Converts a [ui.Image] to an [InputImage] suitable for ML Kit.
  Future<InputImage> _toInputImage(ui.Image image) async {
    // Yield to UI thread before heavy encoding
    await Future.delayed(Duration.zero);
    
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    
    // Yield again after encoding
    await Future.delayed(Duration.zero);
    
    if (byteData == null) {
      throw StateError('Failed to encode image to PNG');
    }

    final tempDir = io.Directory.systemTemp;
    final tempFile = io.File(
        '${tempDir.path}/ml_input_${DateTime.now().microsecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());

    return InputImage.fromFile(tempFile);
  }

  // ---------------------------------------------------------------------------
  // CropScore builders
  // ---------------------------------------------------------------------------

  CropScore _scoreFromBounds(
    SubjectBounds bounds,
    ui.Size imageSize,
    double targetAspectRatio, [
    double confidence = 0.75, // Default base score for ML
  ]) {
    final coords =
        _cropCoordinatesFromBounds(bounds, imageSize, targetAspectRatio);
    return CropScore(
      coordinates: coords,
      score: confidence,
      strategy: _analyzerName,
      metrics: {
        'subject_x': bounds.x,
        'subject_y': bounds.y,
        'subject_width': bounds.width,
        'subject_height': bounds.height,
      },
    );
  }

  CropScore _noDetectionScore(ui.Size imageSize, double targetAspectRatio) {
    return CropScore(
      coordinates: _centerCrop(imageSize, targetAspectRatio),
      score: 0.0,
      strategy: 'ml_subject_no_detection',
      metrics: const {},
    );
  }

  CropScore _timeoutScore(ui.Size imageSize, double targetAspectRatio) {
    return CropScore(
      coordinates: _centerCrop(imageSize, targetAspectRatio),
      score: 0.0,
      strategy: 'ml_subject_timeout',
      metrics: const {},
    );
  }

  CropScore _errorScore(
      ui.Size imageSize, double targetAspectRatio, Object error) {
    return CropScore(
      coordinates: _centerCrop(imageSize, targetAspectRatio),
      score: 0.0,
      strategy: 'ml_subject_error',
      metrics: {'error': error.toString()},
    );
  }

  // ---------------------------------------------------------------------------
  // Crop coordinate helpers
  // ---------------------------------------------------------------------------

  /// Generates [CropCoordinates] centred on [bounds] while respecting
  /// [targetAspectRatio].  All values are normalised to [0.0, 1.0].
  CropCoordinates _cropCoordinatesFromBounds(
    SubjectBounds bounds,
    ui.Size imageSize,
    double targetAspectRatio,
  ) {
    final cropWidth = _calcCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calcCropHeight(imageSize, targetAspectRatio);

    // Centre of the subject bounds.
    final subjectCenterX = bounds.x + bounds.width / 2;
    final subjectCenterY = bounds.y + bounds.height / 2;

    // Position the crop so its centre aligns with the subject centre.
    final cropX = (subjectCenterX - cropWidth / 2).clamp(0.0, 1.0 - cropWidth);
    final cropY =
        (subjectCenterY - cropHeight / 2).clamp(0.0, 1.0 - cropHeight);

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.9,
      strategy: _analyzerName,
      subjectBounds: ui.Rect.fromLTWH(
        bounds.x,
        bounds.y,
        bounds.width,
        bounds.height,
      ),
    );
  }

  CropCoordinates _centerCrop(ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calcCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calcCropHeight(imageSize, targetAspectRatio);
    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.0,
      strategy: _analyzerName,
    );
  }

  double _calcCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspectRatio
        ? 1.0
        : targetAspectRatio / imageAspectRatio;
  }

  double _calcCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspectRatio
        ? 1.0
        : imageAspectRatio / targetAspectRatio;
  }
}

/// Result of a subject detection pass
class _DetectionResult {
  final SubjectBounds bounds;
  final double confidence;
  _DetectionResult(this.bounds, this.confidence);
}

/// Top-level function for [compute] support.
/// Computes the bounding box and a confidence score for the detected subject.
_DetectionResult? _computeSubjectDetectionIsolate(Map<String, dynamic> params) {
  final List<double>? mask = params['mask'];
  final int width = params['width'];
  final int height = params['height'];

  if (mask == null || mask.isEmpty) return null;
  if (mask.length != width * height) return null;

  // --- Pass 1: global foreground bounding box ---
  int minX = width, minY = height, maxX = 0, maxY = 0;
  bool found = false;

  // --- Density weighted centroid accumulators ---
  double weightedSumX = 0.0;
  double weightedSumY = 0.0;
  double totalWeight = 0.0;
  double sumConfidence = 0.0;
  int foregroundPixels = 0;

  for (int y = 0; y < height; y++) {
    for (int x = 0; x < width; x++) {
      final confidence = mask[y * width + x];
      if (confidence > 0.5) {
        if (x < minX) minX = x;
        if (y < minY) minY = y;
        if (x > maxX) maxX = x;
        if (y > maxY) maxY = y;
        found = true;

        // Accumulate weighted centroid (weight = confidence^2 to emphasise peaks)
        final w = confidence * confidence;
        weightedSumX += x * w;
        weightedSumY += y * w;
        totalWeight += w;
        sumConfidence += confidence;
        foregroundPixels++;
      }
    }
  }

  if (!found) return null;

  // Normalised full bounds
  final normMinX = minX / width;
  final normMinY = minY / height;
  final normMaxX = (maxX + 1) / width;
  final normMaxY = (maxY + 1) / height;
  final normBoundsW = normMaxX - normMinX;
  final normBoundsH = normMaxY - normMinY;

  // Density-weighted centroid (normalised)
  final centroidX = totalWeight > 0
      ? (weightedSumX / totalWeight) / width
      : normMinX + normBoundsW / 2;
  final centroidY = totalWeight > 0
      ? (weightedSumY / totalWeight) / height
      : normMinY + normBoundsH / 2;

  // --- Pass 2: build a tighter bounds centred on the density peak ---
  final halfW = math.min(normBoundsW / 2, normBoundsW * 0.60);
  final halfH = math.min(normBoundsH / 2, normBoundsH * 0.60);

  final tightMinX = math.max(normMinX, centroidX - halfW);
  final tightMinY = math.max(normMinY, centroidY - halfH);
  final tightMaxX = math.min(normMaxX, centroidX + halfW);
  final tightMaxY = math.min(normMaxY, centroidY + halfH);

  final bounds = SubjectBounds(
    x: tightMinX,
    y: tightMinY,
    width: tightMaxX - tightMinX,
    height: tightMaxY - tightMinY,
  );

  // --- Confidence Calculation ---
  // 1. Average confidence of foreground pixels (base reliability)
  final avgConfidence = sumConfidence / foregroundPixels;

  // 2. Size score: prefer subjects between 5% and 50% of the image.
  final area = normBoundsW * normBoundsH;
  double sizeMultiplier = 1.0;
  if (area < 0.01) {
    sizeMultiplier = 0.3;
  } else if (area < 0.04) {
    sizeMultiplier = 0.7;
  } else if (area > 0.85) {
    sizeMultiplier = 0.6;
  }

  // 3. Centrality bias
  double edgePenalty = 1.0;
  bool touchesEdge =
      normMinX < 0.01 || normMaxX > 0.99 || normMinY < 0.01 || normMaxY > 0.99;
  if (touchesEdge) {
    edgePenalty = area < 0.1 ? 0.7 : 0.9;
  }

  final finalConfidence =
      (avgConfidence * sizeMultiplier * edgePenalty).clamp(0.0, 1.0);

  return _DetectionResult(bounds, finalConfidence);
}
