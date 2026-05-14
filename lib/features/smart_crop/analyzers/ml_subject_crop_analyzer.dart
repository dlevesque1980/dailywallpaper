import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:dailywallpaper/services/ml/ml_segmentation_service.dart';
import 'package:google_mlkit_subject_segmentation/google_mlkit_subject_segmentation.dart' show InputImage, SubjectBounds;

import '../cache/ml_subject_cache.dart';
import '../interfaces/analysis_context.dart';
import '../interfaces/analyzer_metadata.dart';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_coordinates.dart';
import '../models/crop_score.dart';
import '../models/crop_settings.dart';
import '../utils/device_capability_detector.dart';
import 'ml/ml_subject_coordinate_calculator.dart';
import 'ml/ml_subject_detector.dart';

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
  final MlSegmentationService _segmentationService;

  MlSubjectCropAnalyzer({MlSubjectCache? cache, MlSegmentationService? segmentationService})
      : _cache = cache ?? MlSubjectCache(),
        _segmentationService = segmentationService ?? MlSegmentationServiceImpl(),
        super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 5000),
          metadata: const AnalyzerMetadata(
            description: 'ML Kit subject segmentation for precise crop detection',
            version: '1.0.0',
            isCpuIntensive: true,
            isMemoryIntensive: true,
            supportsParallelExecution: false,
          ),
        );

  @override
  bool canAnalyze(ui.Image image, CropSettings settings) => settings.enableMlSubjectDetection && image.width > 0 && image.height > 0;

  @override
  Future<CropScore> analyzeWithContext(ui.Image image, ui.Size targetSize, AnalysisContext context) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      return await Future.any([
        _runAnalysis(image, imageSize, targetAspectRatio, context.imageId),
        Future.delayed(maxProcessingTime, () => _timeoutScore(imageSize, targetAspectRatio)),
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
        Future.delayed(maxProcessingTime, () => _timeoutScore(imageSize, targetAspectRatio)),
      ]);
    } catch (e) {
      return _errorScore(imageSize, targetAspectRatio, e);
    }
  }

  Future<CropScore> _runAnalysis(ui.Image image, ui.Size imageSize, double targetAspectRatio, String? imageUrl) async {
    if (imageUrl != null) {
      final cached = await _cache.getSubjectBounds(imageUrl);
      if (cached != null) return _scoreFromBounds(cached, imageSize, targetAspectRatio);
    }

    final capabilities = await DeviceCapabilityDetector.getDeviceCapability();
    if (capabilities.isEmulator) return _runSimulation(imageSize, targetAspectRatio, imageUrl);

    final resized = await _resizeImage(image);
    final resizedSize = ui.Size(resized.width.toDouble(), resized.height.toDouble());

    try {
      final inputImage = await _toInputImage(resized);
      final result = await _segmentationService.processImage(io.File(inputImage.filePath!));

      final detectionResult = await compute(MlSubjectDetector.detectFromMask, {
        'mask': result.foregroundConfidenceMask,
        'width': resizedSize.width.toInt(),
        'height': resizedSize.height.toInt(),
      });

      if (detectionResult == null) return _noDetectionScore(imageSize, targetAspectRatio);

      if (imageUrl != null) await _cache.saveSubjectBounds(imageUrl, detectionResult.bounds);

      return _scoreFromBounds(detectionResult.bounds, imageSize, targetAspectRatio, detectionResult.confidence);
    } catch (e) {
      return _errorScore(imageSize, targetAspectRatio, e);
    }
  }

  Future<CropScore> _runSimulation(ui.Size imageSize, double targetAspectRatio, String? imageUrl) async {
    await Future.delayed(const Duration(milliseconds: 150));
    final bounds = SubjectBounds(x: 0.0, y: 0.0, width: 1.0, height: 1.0);
    final coords = MlSubjectCoordinateCalculator.calculateCrop(bounds: bounds, imageSize: imageSize, targetAspectRatio: targetAspectRatio, strategyName: 'ml_subject_simulation');
    return CropScore(coordinates: coords, score: 0.1, strategy: 'ml_subject_simulation', metrics: {'simulated': true});
  }

  Future<ui.Image> _resizeImage(ui.Image image) async {
    final maxDim = math.max(image.width, image.height);
    if (maxDim <= _maxImageDimension) return image;
    final scale = _maxImageDimension / maxDim;
    final newWidth = (image.width * scale).round();
    final newHeight = (image.height * scale).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(image, ui.Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()), ui.Rect.fromLTWH(0, 0, newWidth.toDouble(), newHeight.toDouble()), ui.Paint()..filterQuality = ui.FilterQuality.medium);
    return (recorder.endRecording()).toImage(newWidth, newHeight);
  }

  Future<InputImage> _toInputImage(ui.Image image) async {
    await Future.delayed(Duration.zero);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) throw StateError('Failed to encode image');
    final tempFile = io.File('${io.Directory.systemTemp.path}/ml_input_${DateTime.now().microsecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(byteData.buffer.asUint8List());
    return InputImage.fromFile(tempFile);
  }

  CropScore _scoreFromBounds(SubjectBounds bounds, ui.Size imageSize, double targetAspectRatio, [double confidence = 0.75]) {
    final coords = MlSubjectCoordinateCalculator.calculateCrop(bounds: bounds, imageSize: imageSize, targetAspectRatio: targetAspectRatio, strategyName: _analyzerName);
    return CropScore(coordinates: coords, score: confidence, strategy: _analyzerName, metrics: {'subject_x': bounds.x, 'subject_y': bounds.y, 'subject_width': bounds.width, 'subject_height': bounds.height});
  }

  CropScore _noDetectionScore(ui.Size imageSize, double targetAspectRatio) => _fallbackScore(imageSize, targetAspectRatio, 'ml_subject_no_detection');
  CropScore _timeoutScore(ui.Size imageSize, double targetAspectRatio) => _fallbackScore(imageSize, targetAspectRatio, 'ml_subject_timeout');
  CropScore _errorScore(ui.Size imageSize, double targetAspectRatio, Object error) => _fallbackScore(imageSize, targetAspectRatio, 'ml_subject_error', {'error': error.toString()});

  CropScore _fallbackScore(ui.Size imageSize, double targetAspectRatio, String strategy, [Map<String, dynamic>? metrics]) {
    final coords = MlSubjectCoordinateCalculator.calculateCrop(bounds: SubjectBounds(x: 0, y: 0, width: 1, height: 1), imageSize: imageSize, targetAspectRatio: targetAspectRatio, strategyName: strategy);
    return CropScore(coordinates: coords, score: 0.0, strategy: strategy, metrics: metrics ?? const {});
  }
}
