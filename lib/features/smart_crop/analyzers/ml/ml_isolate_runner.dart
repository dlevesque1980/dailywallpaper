import 'dart:io';
import 'dart:typed_data';

import 'package:dailywallpaper/services/ml/ml_segmentation_service.dart';

import 'ml_subject_detector.dart';

// Types transmissibles entre isolates (pas de ui.Image, pas de File object)
class MlIsolatePayload {
  final Uint8List pngBytes;
  final int originalWidth;
  final int originalHeight;
  final String tempDirPath;

  MlIsolatePayload({
    required this.pngBytes,
    required this.originalWidth,
    required this.originalHeight,
    required this.tempDirPath,
  });
}

class MlIsolateResult {
  final double? subjectX, subjectY, subjectWidth, subjectHeight;
  final double confidence;
  final String? error;

  MlIsolateResult({
    this.subjectX,
    this.subjectY,
    this.subjectWidth,
    this.subjectHeight,
    required this.confidence,
    this.error,
  });
}

// Fonction TOP-LEVEL (exigence dart:isolate)
Future<MlIsolateResult> runMlSegmentationInIsolate(
    MlIsolatePayload payload) async {
  File? tempFile;
  try {
    tempFile = File(
        '${payload.tempDirPath}/ml_input_${DateTime.now().microsecondsSinceEpoch}.png');
    await tempFile.writeAsBytes(payload.pngBytes);

    final segmentationService = MlSegmentationServiceImpl();
    final result = await segmentationService
        .processImage(tempFile)
        .timeout(const Duration(seconds: 4));

    final detectionResult = MlSubjectDetector.detectFromMask({
      'mask': result.foregroundConfidenceMask,
      'width': payload.originalWidth,
      'height': payload.originalHeight,
    });

    if (detectionResult == null) {
      return MlIsolateResult(confidence: 0.0);
    }

    return MlIsolateResult(
      subjectX: detectionResult.bounds.x,
      subjectY: detectionResult.bounds.y,
      subjectWidth: detectionResult.bounds.width,
      subjectHeight: detectionResult.bounds.height,
      confidence: detectionResult.confidence,
    );
  } catch (e) {
    return MlIsolateResult(confidence: 0.0, error: e.toString());
  } finally {
    if (tempFile != null && tempFile.existsSync()) {
      try {
        tempFile.deleteSync();
      } catch (_) {}
    }
  }
}
