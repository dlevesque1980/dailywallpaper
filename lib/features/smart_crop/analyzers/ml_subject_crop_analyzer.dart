import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io' as io;

import 'package:flutter/foundation.dart';

import '../cache/ml_subject_cache.dart';
import '../interfaces/analysis_context.dart';
import '../interfaces/analyzer_metadata.dart';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_settings.dart';
import '../utils/device_capability_detector.dart';
import 'ml/ml_isolate_runner.dart';
import 'ml/ml_subject_coordinate_calculator.dart';

class MlSubjectCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'ml_subject_detection';
  static const int _analyzerPriority = 180;
  static const double _analyzerWeight = 0.85;
  static const int _maxImageDimension = 256;

  static bool _isAnalyzing = false;
  static bool _isMlKitHealthy = true;

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

  @override
  bool canAnalyze(ui.Image image, CropSettings settings) =>
      _isMlKitHealthy &&
      settings.enableMlSubjectDetection &&
      image.width > 0 &&
      image.height > 0;

  @override
  Future<CropScore> analyzeWithContext(
      ui.Image image, ui.Size targetSize, AnalysisContext context) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      return await Future.any([
        _runAnalysis(image, imageSize, targetAspectRatio, context.imageId),
        Future.delayed(maxProcessingTime,
            () => _timeoutScore(imageSize, targetAspectRatio)),
      ]);
    } catch (e) {
      return _errorScore(imageSize, targetAspectRatio, e);
    }
  }

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

  Future<CropScore> _runAnalysis(ui.Image image, ui.Size imageSize,
      double targetAspectRatio, String? imageUrl) async {
    if (!_isMlKitHealthy) {
      return _fallbackScore(
          imageSize, targetAspectRatio, 'ml_subject_unhealthy_skip');
    }

    if (_isAnalyzing) {
      debugPrint(
          'MlSubjectCropAnalyzer: Skipping analysis because another is in progress (preventing concurrency SIGSEGV).');
      return _fallbackScore(
          imageSize, targetAspectRatio, 'ml_subject_concurrency_skip');
    }

    if (imageUrl != null) {
      final cached = await _cache.getSubjectBounds(imageUrl);
      if (cached != null)
        return _scoreFromBounds(cached, imageSize, targetAspectRatio);
    }

    final capabilities = await DeviceCapabilityDetector.getDeviceCapability();
    if (capabilities.isEmulator)
      return _runSimulation(imageSize, targetAspectRatio, imageUrl);

    _isAnalyzing = true;
    final resized = await _resizeImage(image);
    final resizedSize =
        ui.Size(resized.width.toDouble(), resized.height.toDouble());

    try {
      final byteData = await resized.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw StateError('Failed to encode image');

      final payload = MlIsolatePayload(
        pngBytes: byteData.buffer.asUint8List(),
        originalWidth: resizedSize.width.toInt(),
        originalHeight: resizedSize.height.toInt(),
        tempDirPath: io.Directory.systemTemp.path,
      );

      final result =
          await Isolate.run(() => runMlSegmentationInIsolate(payload))
              .timeout(const Duration(seconds: 4));

      if (result.error != null) {
        throw Exception(result.error);
      }

      if (result.subjectX == null) {
        return _noDetectionScore(imageSize, targetAspectRatio);
      }

      final bounds = SubjectBounds(
        x: result.subjectX!,
        y: result.subjectY!,
        width: result.subjectWidth!,
        height: result.subjectHeight!,
      );

      if (imageUrl != null) await _cache.saveSubjectBounds(imageUrl, bounds);

      return _scoreFromBounds(
          bounds, imageSize, targetAspectRatio, result.confidence);
    } catch (e) {
      // This catches TimeoutException, PlatformException, and any Dart-level error.
      // Native SIGSEGV crashes CANNOT be caught here — they will kill the process.
      debugPrint(
          'MlSubjectCropAnalyzer: analysis failed, using fallback. Error: $e');
      if (e is TimeoutException || e.toString().contains('TimeoutException')) {
        debugPrint(
            'MlSubjectCropAnalyzer: Timeout detected. Marking ML Kit as unhealthy for the rest of the session.');
        _isMlKitHealthy = false;
      }
      return _errorScore(imageSize, targetAspectRatio, e);
    } finally {
      _isAnalyzing = false;
    }
  }

  Future<CropScore> _runSimulation(
      ui.Size imageSize, double targetAspectRatio, String? imageUrl) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final bounds = SubjectBounds(x: 0.0, y: 0.0, width: 1.0, height: 1.0);
    final coords = MlSubjectCoordinateCalculator.calculateCrop(
        bounds: bounds,
        imageSize: imageSize,
        targetAspectRatio: targetAspectRatio,
        strategyName: 'ml_subject_simulation');
    return CropScore(
        coordinates: coords,
        score: 0.1,
        strategy: 'ml_subject_simulation',
        metrics: {'simulated': true});
  }

  Future<ui.Image> _resizeImage(ui.Image image) async {
    final maxDim = math.max(image.width, image.height);
    if (maxDim <= _maxImageDimension) return image;
    final scale = _maxImageDimension / maxDim;
    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
        image,
        ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        ui.Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()),
        ui.Paint()..filterQuality = ui.FilterQuality.medium);
    await Future.delayed(Duration.zero); // Yield to event loop
    return (recorder.endRecording()).toImage(newWidth, newHeight);
  }

  CropScore _scoreFromBounds(
      SubjectBounds bounds, ui.Size imageSize, double targetAspectRatio,
      [double confidence = 0.75]) {
    final coords = MlSubjectCoordinateCalculator.calculateCrop(
        bounds: bounds,
        imageSize: imageSize,
        targetAspectRatio: targetAspectRatio,
        strategyName: _analyzerName);
    return CropScore(
        coordinates: coords,
        score: confidence,
        strategy: _analyzerName,
        metrics: {
          'subject_x': bounds.x,
          'subject_y': bounds.y,
          'subject_width': bounds.width,
          'subject_height': bounds.height
        });
  }

  CropScore _noDetectionScore(ui.Size imageSize, double targetAspectRatio) =>
      _fallbackScore(imageSize, targetAspectRatio, 'ml_subject_no_detection');
  CropScore _timeoutScore(ui.Size imageSize, double targetAspectRatio) =>
      _fallbackScore(imageSize, targetAspectRatio, 'ml_subject_timeout');
  CropScore _errorScore(
          ui.Size imageSize, double targetAspectRatio, Object error) =>
      _fallbackScore(imageSize, targetAspectRatio, 'ml_subject_error',
          {'error': error.toString()});

  CropScore _fallbackScore(
      ui.Size imageSize, double targetAspectRatio, String strategy,
      [Map<String, dynamic>? metrics]) {
    final coords = MlSubjectCoordinateCalculator.calculateCrop(
        bounds: SubjectBounds(x: 0, y: 0, width: 1, height: 1),
        imageSize: imageSize,
        targetAspectRatio: targetAspectRatio,
        strategyName: strategy);
    return CropScore(
        coordinates: coords,
        score: 0.0,
        strategy: strategy,
        metrics: metrics ?? const {});
  }
}
