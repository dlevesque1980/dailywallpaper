import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Face detection analyzer for smart cropping
///
/// This analyzer detects face-like features in images and optimizes crops
/// to preserve faces while maintaining good composition. It uses simplified
/// image processing techniques optimized for mobile performance.
class FaceDetectionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'face_detection';
  static const int _analyzerPriority = 900; // High priority for faces
  static const double _analyzerWeight = 0.95; // Very high weight for faces

  FaceDetectionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 800),
          metadata: const AnalyzerMetadata(
            description: 'Detects and preserves human faces in crop areas',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            minImageWidth: 100,
            minImageHeight: 100,
            maxImageWidth: 2048,
            maxImageHeight: 2048,
            isCpuIntensive: true,
            isMemoryIntensive: false,
            supportsParallelExecution: false,
            dependencies: [],
            conflicts: [],
            configurationOptions: {
              'minFaceSize': 0.05,
              'maxFaceSize': 0.8,
              'skinToneThreshold': 0.3,
            },
            performanceMetrics: {
              'baseProcessingTimeMs': 200,
              'pixelFactor': 0.0001,
            },
          ),
        );

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      // Get image data for analysis
      final imageData = await _getImageData(image);

      // Simple face detection using basic heuristics
      final faces = _detectFacesSimple(imageSize, imageData);

      if (faces.isEmpty) {
        // No faces detected, return low score with center crop
        final centerCrop = _getCenterCrop(imageSize, targetAspectRatio);
        return CropScore(
          coordinates: centerCrop,
          score: 0.1,
          strategy: strategyName,
          metrics: {
            'faces_detected': 0.0,
            'face_count': 0.0,
            'detection_confidence': 0.0,
            'crop_area_ratio': centerCrop.width * centerCrop.height,
          },
        );
      }

      // Generate crop for the best detected face
      final bestFace = faces.first;
      final cropCoordinates =
          _createFaceCrop(bestFace, imageSize, targetAspectRatio);
      final score = _scoreFaceCrop(cropCoordinates, bestFace);

      return CropScore(
        coordinates: cropCoordinates,
        score: score,
        strategy: strategyName,
        metrics: {
          'faces_detected': faces.length.toDouble(),
          'face_count': faces.length.toDouble(),
          'detection_confidence': bestFace.confidence,
          'primary_face_confidence': bestFace.confidence,
          'crop_area_ratio': cropCoordinates.width * cropCoordinates.height,
        },
      );
    } catch (e) {
      // Fallback to center crop on error
      return CropScore(
        coordinates: _getCenterCrop(imageSize, targetAspectRatio),
        score: 0.1,
        strategy: strategyName,
        metrics: {
          'faces_detected': 0.0,
          'error': e.toString(),
        },
      );
    }
  }

  /// Gets image pixel data for analysis
  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Simple and fast face detection using basic heuristics
  List<DetectedFace> _detectFacesSimple(
      ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final faces = <DetectedFace>[];

    // Use a simple grid-based approach for performance
    const gridSize = 6; // Small grid for speed
    final cellWidth = width / gridSize;
    final cellHeight = height / gridSize;

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final startX = (gx * cellWidth).round();
        final endX = math.min(((gx + 1) * cellWidth).round(), width);
        final startY = (gy * cellHeight).round();
        final endY = math.min(((gy + 1) * cellHeight).round(), height);

        // Skip if invalid bounds
        if (startX >= endX ||
            startY >= endY ||
            startX >= width ||
            startY >= height) {
          continue;
        }

        // Quick skin tone check
        final skinScore = _quickSkinToneCheck(
            imageData, width, height, startX, endX, startY, endY);

        if (skinScore > 0.3) {
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          final size = math.sqrt((cellWidth * cellHeight) / (width * height));

          faces.add(DetectedFace(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height,
                (endX - startX) / width, (endY - startY) / height),
            confidence: skinScore,
            size: size,
            importance: skinScore * _getPositionWeight(centerX, centerY),
          ));
        }
      }
    }

    // Sort by importance and return top candidates
    faces.sort((a, b) => b.importance.compareTo(a.importance));
    return faces.take(2).toList(); // Limit to 2 faces for performance
  }

  /// Quick skin tone check for a region
  double _quickSkinToneCheck(Uint8List imageData, int width, int height,
      int startX, int endX, int startY, int endY) {
    int skinPixels = 0;
    int totalPixels = 0;

    // Sample every 4th pixel for speed
    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        if (_isSkinToneSimple(r, g, b)) {
          skinPixels++;
        }
        totalPixels++;
      }
    }

    return totalPixels > 0 ? skinPixels / totalPixels : 0.0;
  }

  /// Simple skin tone detection
  bool _isSkinToneSimple(int r, int g, int b) {
    // Very basic skin tone detection for speed
    return r > 95 &&
        g > 40 &&
        b > 20 &&
        r > g &&
        r > b &&
        (r - g) > 15 &&
        r < 250; // Avoid pure white
  }

  /// Calculates position weight (center is more important)
  double _getPositionWeight(double x, double y) {
    final distanceFromCenter =
        math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2));
    return math.max(0.4, 1.0 - distanceFromCenter);
  }

  /// Creates a crop focused on a detected face
  CropCoordinates _createFaceCrop(
    DetectedFace face,
    ui.Size imageSize,
    double targetAspectRatio,
  ) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Position crop to include face, slightly offset for better composition
    final offsetX = face.size > 0.2 ? 0.1 : 0.0; // Offset for larger faces
    final offsetY =
        face.size > 0.2 ? -0.1 : 0.0; // Move up slightly for portraits

    final targetX = face.center.dx + offsetX;
    final targetY = face.center.dy + offsetY;

    final cropX =
        math.max(0.0, math.min(1.0 - cropWidth, targetX - cropWidth / 2));
    final cropY =
        math.max(0.0, math.min(1.0 - cropHeight, targetY - cropHeight / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: face.confidence,
      strategy: '${strategyName}_face_focused',
    );
  }

  /// Scores a face-aware crop
  double _scoreFaceCrop(CropCoordinates crop, DetectedFace face) {
    double score = 0.0;

    // Face inclusion score (60%)
    final cropRect = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height);
    final intersection = cropRect.intersect(face.bounds);
    final inclusionRatio = intersection.isEmpty
        ? 0.0
        : (intersection.width * intersection.height) /
            (face.bounds.width * face.bounds.height);
    score += inclusionRatio * 0.6;

    // Face confidence (30%)
    score += face.confidence * 0.3;

    // Crop quality (10%)
    score += _scoreCropQuality(crop) * 0.1;

    return math.min(1.0, score);
  }

  /// Scores overall crop quality
  double _scoreCropQuality(CropCoordinates crop) {
    double score = 1.0;

    // Penalize crops that touch edges
    if (crop.x <= 0.01) score -= 0.1;
    if (crop.y <= 0.01) score -= 0.1;
    if (crop.x + crop.width >= 0.99) score -= 0.1;
    if (crop.y + crop.height >= 0.99) score -= 0.1;

    return math.max(0.0, score);
  }

  /// Calculates crop width based on aspect ratio
  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspectRatio
        ? 1.0
        : targetAspectRatio / imageAspectRatio;
  }

  /// Calculates crop height based on aspect ratio
  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspectRatio
        ? 1.0
        : imageAspectRatio / targetAspectRatio;
  }

  /// Creates a center crop as fallback
  CropCoordinates _getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.3,
      strategy: strategyName,
    );
  }
}

/// Represents a detected face in the image
class DetectedFace {
  final ui.Offset center;
  final ui.Rect bounds;
  final double confidence;
  final double size;
  final double importance;

  DetectedFace({
    required this.center,
    required this.bounds,
    required this.confidence,
    required this.size,
    required this.importance,
  });
}
