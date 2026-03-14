import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Object detection analyzer for smart cropping
///
/// This analyzer detects important objects and subjects in images using
/// edge detection, contrast analysis, and shape recognition to identify
/// prominent subjects that should be preserved in crops.
class ObjectDetectionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'object_detection';
  static const int _analyzerPriority = 800; // High priority for objects
  static const double _analyzerWeight = 0.85; // High weight for objects

  ObjectDetectionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 600),
          metadata: const AnalyzerMetadata(
            description:
                'Detects and preserves important objects and subjects in crop areas',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            minImageWidth: 100,
            minImageHeight: 100,
            maxImageWidth: 2048,
            maxImageHeight: 2048,
            isCpuIntensive: true,
            isMemoryIntensive: false,
            supportsParallelExecution: true,
            dependencies: [],
            conflicts: [],
            configurationOptions: {
              'minObjectSize': 0.03,
              'maxObjectSize': 0.9,
              'contrastThreshold': 0.3,
              'edgeThreshold': 0.4,
            },
            performanceMetrics: {
              'baseProcessingTimeMs': 150,
              'pixelFactor': 0.00008,
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

      // Detect objects using multiple methods
      final objects = _detectObjects(imageSize, imageData);

      if (objects.isEmpty) {
        // No objects detected, return low score with center crop
        final centerCrop = _getCenterCrop(imageSize, targetAspectRatio);
        return CropScore(
          coordinates: centerCrop,
          score: 0.2,
          strategy: strategyName,
          metrics: {
            'objects_detected': 0.0,
            'object_count': 0.0,
            'detection_confidence': 0.0,
            'crop_area_ratio': centerCrop.width * centerCrop.height,
          },
        );
      }

      // Generate crop for the most important detected object
      final primaryObject = objects.first;
      final cropCoordinates =
          _createObjectCrop(primaryObject, imageSize, targetAspectRatio);
      final score = _scoreObjectCrop(cropCoordinates, objects);

      return CropScore(
        coordinates: cropCoordinates,
        score: score,
        strategy: strategyName,
        metrics: {
          'objects_detected': objects.length.toDouble(),
          'object_count': objects.length.toDouble(),
          'detection_confidence': primaryObject.confidence,
          'primary_object_confidence': primaryObject.confidence,
          'primary_object_importance': primaryObject.importance,
          'crop_area_ratio': cropCoordinates.width * cropCoordinates.height,
        },
      );
    } catch (e) {
      // Fallback to center crop on error
      final centerCrop = _getCenterCrop(imageSize, targetAspectRatio);
      return CropScore(
        coordinates: centerCrop,
        score: 0.2,
        strategy: strategyName,
        metrics: {
          'objects_detected': 0.0,
          'error': e.toString(),
          'crop_area_ratio': centerCrop.width * centerCrop.height,
        },
      );
    }
  }

  /// Gets image pixel data for analysis
  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Detects objects using multiple detection methods
  List<DetectedObject> _detectObjects(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final objects = <DetectedObject>[];

    // Method 1: High contrast regions (likely objects)
    objects.addAll(_detectByContrast(width, height, imageData));

    // Method 2: Edge density (object boundaries)
    objects.addAll(_detectByEdges(width, height, imageData));

    // Method 3: Color distinctiveness (prominent objects)
    objects.addAll(_detectByColorDistinctiveness(width, height, imageData));

    // Merge nearby detections and remove duplicates
    final mergedObjects = _mergeNearbyObjects(objects);

    // Filter by confidence and size
    final filteredObjects = mergedObjects
        .where(
            (obj) => obj.confidence > 0.25 && obj.size > 0.03 && obj.size < 0.9)
        .toList();

    // Sort by importance and return top candidates
    filteredObjects.sort((a, b) => b.importance.compareTo(a.importance));
    return filteredObjects
        .take(3)
        .toList(); // Limit to 3 objects for performance
  }

  /// Detects objects by high contrast regions
  List<DetectedObject> _detectByContrast(
      int width, int height, Uint8List imageData) {
    final objects = <DetectedObject>[];
    const gridSize = 8; // Analysis grid
    final cellWidth = width / gridSize;
    final cellHeight = height / gridSize;

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final startX = (gx * cellWidth).round();
        final endX = math.min(((gx + 1) * cellWidth).round(), width);
        final startY = (gy * cellHeight).round();
        final endY = math.min(((gy + 1) * cellHeight).round(), height);

        if (startX >= endX || startY >= endY) continue;

        final contrast = _calculateContrast(
            imageData, width, height, startX, endX, startY, endY);

        if (contrast > 0.4) {
          // High contrast threshold
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          final size = math.sqrt((cellWidth * cellHeight) / (width * height));

          objects.add(DetectedObject(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height,
                (endX - startX) / width, (endY - startY) / height),
            confidence: contrast,
            size: size,
            type: ObjectType.highContrast,
            importance: contrast * _getPositionWeight(centerX, centerY) * size,
          ));
        }
      }
    }

    return objects;
  }

  /// Detects objects by edge density
  List<DetectedObject> _detectByEdges(
      int width, int height, Uint8List imageData) {
    final objects = <DetectedObject>[];
    const gridSize = 6; // Smaller grid for edge detection
    final cellWidth = width / gridSize;
    final cellHeight = height / gridSize;

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final startX = (gx * cellWidth).round();
        final endX = math.min(((gx + 1) * cellWidth).round(), width);
        final startY = (gy * cellHeight).round();
        final endY = math.min(((gy + 1) * cellHeight).round(), height);

        if (startX >= endX || startY >= endY) continue;

        final edgeDensity = _calculateEdgeDensity(
            imageData, width, height, startX, endX, startY, endY);

        if (edgeDensity > 0.3) {
          // Edge density threshold
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          final size = math.sqrt((cellWidth * cellHeight) / (width * height));

          objects.add(DetectedObject(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height,
                (endX - startX) / width, (endY - startY) / height),
            confidence: edgeDensity,
            size: size,
            type: ObjectType.edgeDense,
            importance:
                edgeDensity * _getPositionWeight(centerX, centerY) * size * 0.8,
          ));
        }
      }
    }

    return objects;
  }

  /// Detects objects by color distinctiveness
  List<DetectedObject> _detectByColorDistinctiveness(
      int width, int height, Uint8List imageData) {
    final objects = <DetectedObject>[];
    const gridSize = 6;
    final cellWidth = width / gridSize;
    final cellHeight = height / gridSize;

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final startX = (gx * cellWidth).round();
        final endX = math.min(((gx + 1) * cellWidth).round(), width);
        final startY = (gy * cellHeight).round();
        final endY = math.min(((gy + 1) * cellHeight).round(), height);

        if (startX >= endX || startY >= endY) continue;

        final distinctiveness = _calculateColorDistinctiveness(
            imageData, width, height, startX, endX, startY, endY);

        if (distinctiveness > 0.35) {
          // Color distinctiveness threshold
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          final size = math.sqrt((cellWidth * cellHeight) / (width * height));

          objects.add(DetectedObject(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height,
                (endX - startX) / width, (endY - startY) / height),
            confidence: distinctiveness,
            size: size,
            type: ObjectType.colorDistinct,
            importance: distinctiveness *
                _getPositionWeight(centerX, centerY) *
                size *
                0.9,
          ));
        }
      }
    }

    return objects;
  }

  /// Calculates contrast in a region
  double _calculateContrast(Uint8List imageData, int width, int height,
      int startX, int endX, int startY, int endY) {
    final brightnesses = <int>[];

    // Sample pixels in the region
    for (int y = startY; y < endY; y += 3) {
      for (int x = startX; x < endX; x += 3) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b).round();
        brightnesses.add(brightness);
      }
    }

    if (brightnesses.length < 4) return 0.0;

    brightnesses.sort();
    final q1 = brightnesses[brightnesses.length ~/ 4];
    final q3 = brightnesses[(brightnesses.length * 3) ~/ 4];
    return math.min(1.0, (q3 - q1) / 255.0);
  }

  /// Calculates edge density in a region
  double _calculateEdgeDensity(Uint8List imageData, int width, int height,
      int startX, int endX, int startY, int endY) {
    int edgePixels = 0;
    int totalPixels = 0;

    // Simple edge detection using brightness differences
    for (int y = startY; y < endY - 1; y += 2) {
      for (int x = startX; x < endX - 1; x += 2) {
        if (x + 1 >= width || y + 1 >= height) continue;

        final currentBrightness = _getPixelBrightness(imageData, width, x, y);
        final rightBrightness = _getPixelBrightness(imageData, width, x + 1, y);
        final downBrightness = _getPixelBrightness(imageData, width, x, y + 1);

        if (currentBrightness >= 0 &&
            rightBrightness >= 0 &&
            downBrightness >= 0) {
          final horizontalDiff = (currentBrightness - rightBrightness).abs();
          final verticalDiff = (currentBrightness - downBrightness).abs();

          if (horizontalDiff > 30 || verticalDiff > 30) {
            // Edge threshold
            edgePixels++;
          }
          totalPixels++;
        }
      }
    }

    return totalPixels > 0 ? edgePixels / totalPixels : 0.0;
  }

  /// Calculates color distinctiveness in a region
  double _calculateColorDistinctiveness(Uint8List imageData, int width,
      int height, int startX, int endX, int startY, int endY) {
    final colors = <int>[];

    // Sample colors in the region
    for (int y = startY; y < endY; y += 4) {
      for (int x = startX; x < endX; x += 4) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        // Quantize color to reduce noise
        final quantizedColor = ((r ~/ 32) << 10) | ((g ~/ 32) << 5) | (b ~/ 32);
        colors.add(quantizedColor);
      }
    }

    if (colors.isEmpty) return 0.0;

    // Calculate color variance as distinctiveness measure
    final uniqueColors = colors.toSet().length;
    final colorVariance = uniqueColors / colors.length;

    return math.min(1.0, colorVariance * 2); // Scale up variance
  }

  /// Gets pixel brightness at coordinates
  int _getPixelBrightness(Uint8List imageData, int width, int x, int y) {
    final pixelIndex = (y * width + x) * 4;
    if (pixelIndex + 2 >= imageData.length) return -1;

    final r = imageData[pixelIndex];
    final g = imageData[pixelIndex + 1];
    final b = imageData[pixelIndex + 2];

    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }

  /// Merges nearby object detections to avoid duplicates
  List<DetectedObject> _mergeNearbyObjects(List<DetectedObject> objects) {
    final merged = <DetectedObject>[];
    final processed = List.filled(objects.length, false);

    for (int i = 0; i < objects.length; i++) {
      if (processed[i]) continue;

      final current = objects[i];
      final nearby = <DetectedObject>[current];
      processed[i] = true;

      // Find nearby objects
      for (int j = i + 1; j < objects.length; j++) {
        if (processed[j]) continue;

        final distance = math.sqrt(
            math.pow(current.center.dx - objects[j].center.dx, 2) +
                math.pow(current.center.dy - objects[j].center.dy, 2));

        if (distance < 0.15) {
          // Merge threshold
          nearby.add(objects[j]);
          processed[j] = true;
        }
      }

      // Create merged object
      if (nearby.length == 1) {
        merged.add(current);
      } else {
        merged.add(_createMergedObject(nearby));
      }
    }

    return merged;
  }

  /// Creates a merged object from multiple detections
  DetectedObject _createMergedObject(List<DetectedObject> objects) {
    double totalImportance = 0;
    double weightedX = 0, weightedY = 0;
    double minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    double maxConfidence = 0.0;
    double totalSize = 0;
    ObjectType bestType = objects.first.type;

    for (final obj in objects) {
      totalImportance += obj.importance;
      weightedX += obj.center.dx * obj.importance;
      weightedY += obj.center.dy * obj.importance;
      totalSize += obj.size;

      minX = math.min(minX, obj.bounds.left);
      minY = math.min(minY, obj.bounds.top);
      maxX = math.max(maxX, obj.bounds.right);
      maxY = math.max(maxY, obj.bounds.bottom);

      if (obj.confidence > maxConfidence) {
        maxConfidence = obj.confidence;
        bestType = obj.type;
      }
    }

    return DetectedObject(
      center:
          ui.Offset(weightedX / totalImportance, weightedY / totalImportance),
      bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY),
      confidence: maxConfidence,
      size: totalSize / objects.length,
      type: bestType,
      importance: totalImportance,
    );
  }

  /// Calculates position weight (center is more important)
  double _getPositionWeight(double x, double y) {
    final distanceFromCenter =
        math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2));
    return math.max(0.3, 1.0 - distanceFromCenter);
  }

  /// Creates a crop focused on a detected object
  CropCoordinates _createObjectCrop(
    DetectedObject object,
    ui.Size imageSize,
    double targetAspectRatio,
  ) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Position crop to include object with some context
    final targetX = object.center.dx;
    final targetY = object.center.dy;

    final cropX =
        math.max(0.0, math.min(1.0 - cropWidth, targetX - cropWidth / 2));
    final cropY =
        math.max(0.0, math.min(1.0 - cropHeight, targetY - cropHeight / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: object.confidence,
      strategy: '${strategyName}_object_focused',
    );
  }

  /// Scores an object-aware crop
  double _scoreObjectCrop(CropCoordinates crop, List<DetectedObject> objects) {
    if (objects.isEmpty) return 0.2;

    double score = 0.0;

    // Object inclusion score (50%)
    score += _scoreObjectInclusion(crop, objects) * 0.5;

    // Object confidence (30%)
    final avgConfidence =
        objects.map((o) => o.confidence).reduce((a, b) => a + b) /
            objects.length;
    score += avgConfidence * 0.3;

    // Crop quality (20%)
    score += _scoreCropQuality(crop) * 0.2;

    return math.min(1.0, score);
  }

  /// Scores how well objects are included in the crop
  double _scoreObjectInclusion(
      CropCoordinates crop, List<DetectedObject> objects) {
    final cropRect = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height);
    double totalInclusion = 0.0;
    double totalImportance = 0.0;

    for (final obj in objects) {
      final intersection = cropRect.intersect(obj.bounds);
      final inclusionRatio = intersection.isEmpty
          ? 0.0
          : (intersection.width * intersection.height) /
              (obj.bounds.width * obj.bounds.height);

      totalInclusion += inclusionRatio * obj.importance;
      totalImportance += obj.importance;
    }

    return totalImportance > 0 ? totalInclusion / totalImportance : 0.0;
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

/// Represents a detected object in the image
class DetectedObject {
  final ui.Offset center;
  final ui.Rect bounds;
  final double confidence;
  final double size;
  final ObjectType type;
  final double importance;

  DetectedObject({
    required this.center,
    required this.bounds,
    required this.confidence,
    required this.size,
    required this.type,
    required this.importance,
  });
}

/// Types of object detection methods
enum ObjectType {
  highContrast,
  edgeDense,
  colorDistinct,
}
