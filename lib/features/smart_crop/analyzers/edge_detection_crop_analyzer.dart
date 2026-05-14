import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Crop analyzer that uses edge detection to identify important image features
///
/// This analyzer applies Sobel edge detection to find areas with strong edges
/// and boundaries, preferring crops that contain significant edge content
/// which typically indicates important visual features.
class EdgeDetectionCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'edge_detection';

  @override
  double get weight => 0.65; // Moderate-high weight for feature detection

  @override
  bool get isEnabledByDefault =>
      false; // More CPU intensive, disabled by default

  @override
  double get minConfidenceThreshold => 0.1;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    // Get image data for edge detection
    final imageData = await _getImageData(image);
    
    // Offload heavy Sobel edge detection and candidate scoring to worker isolate
    final result = await compute(_performEdgeAnalysisIsolate, {
      'imageSize': imageSize,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
      'width': image.width,
      'height': image.height,
    });

    final bestCrop = result['bestCrop'] as CropCoordinates? ?? _getCenterCrop(imageSize, targetAspectRatio);
    final bestScore = result['bestScore'] as double;
    final bestMetrics = Map<String, double>.from(result['bestMetrics'] as Map);

    return CropScore(
      coordinates: bestCrop,
      score: bestScore,
      strategy: strategyName,
      metrics: bestMetrics,
    );
  }

  /// Gets image pixel data for edge detection
  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Creates a center crop as fallback (Main thread)
  CropCoordinates _getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
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
      confidence: 0.3,
      strategy: strategyName,
    );
  }
}

/// --- Top-level functions for Isolate support ---

Map<String, dynamic> _performEdgeAnalysisIsolate(Map<String, dynamic> params) {
  final ui.Size imageSize = params['imageSize'];
  final double targetAspectRatio = params['targetAspectRatio'];
  final Uint8List imageData = params['imageData'];
  final String strategyName = params['strategyName'];
  final int width = params['width'];
  final int height = params['height'];

  final core = _EdgeAnalyzerCore(strategyName);
  
  // 1. Grayscale
  final grayscale = core.convertToGrayscale(imageData, width, height);
  
  // 2. Sobel
  final edgeData = core.applySobelEdgeDetection(grayscale, width, height);
  
  // 3. Generate Candidates
  final candidates = core.generateEdgeBasedCandidates(imageSize, targetAspectRatio, edgeData);
  
  CropCoordinates? bestCrop;
  double bestScore = 0.0;
  Map<String, double> bestMetrics = {};

  for (final candidate in candidates) {
    final score = core.scoreEdgeContent(candidate, imageSize, edgeData);
    final metrics = core.calculateMetricsSync(candidate, imageSize, edgeData);

    if (score > bestScore) {
      bestScore = score;
      bestCrop = candidate;
      bestMetrics = metrics;
    }
  }

  return {
    'bestCrop': bestCrop,
    'bestScore': bestScore,
    'bestMetrics': bestMetrics,
  };
}

class _EdgeAnalyzerCore {
  final String strategyName;
  _EdgeAnalyzerCore(this.strategyName);

  Uint8List convertToGrayscale(Uint8List rgbaData, int width, int height) {
    final grayscale = Uint8List(width * height);
    for (int i = 0; i < width * height; i++) {
      final rgbaIndex = i * 4;
      final gray = (0.299 * rgbaData[rgbaIndex] + 0.587 * rgbaData[rgbaIndex + 1] + 0.114 * rgbaData[rgbaIndex + 2]).round();
      grayscale[i] = gray.clamp(0, 255);
    }
    return grayscale;
  }

  Uint8List applySobelEdgeDetection(Uint8List grayscaleData, int width, int height) {
    final edgeData = Uint8List(width * height);
    final sobelX = [[-1, 0, 1], [-2, 0, 2], [-1, 0, 1]];
    final sobelY = [[-1, -2, -1], [0, 0, 0], [1, 2, 1]];

    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0.0;
        double gy = 0.0;
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixelValue = grayscaleData[(y + ky) * width + (x + kx)];
            gx += pixelValue * sobelX[ky + 1][kx + 1];
            gy += pixelValue * sobelY[ky + 1][kx + 1];
          }
        }
        edgeData[y * width + x] = (math.sqrt(gx * gx + gy * gy) / 4).clamp(0, 255).round();
      }
    }
    return edgeData;
  }

  List<CropCoordinates> generateEdgeBasedCandidates(ui.Size imageSize, double targetAspectRatio, Uint8List edgeData) {
    final candidates = <CropCoordinates>[];
    final imageAspectRatio = imageSize.width / imageSize.height;
    double cropWidth, cropHeight;
    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }

    final gridSize = 6;
    final stepX = 1.0 / gridSize;
    final stepY = 1.0 / gridSize;
    final densities = <_EdgeDensityPoint>[];

    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final centerX = (i + 0.5) * stepX;
        final centerY = (j + 0.5) * stepY;
        final density = calculateEdgeDensity(centerX, centerY, imageSize, edgeData, 0.15);
        densities.add(_EdgeDensityPoint(centerX, centerY, density));
      }
    }

    densities.sort((a, b) => b.density.compareTo(a.density));
    for (final point in densities.take(8)) {
      if (point.density > 0.1) {
        final cropX = math.max(0.0, math.min(1.0 - cropWidth, point.x - cropWidth / 2));
        final cropY = math.max(0.0, math.min(1.0 - cropHeight, point.y - cropHeight / 2));
        candidates.add(CropCoordinates(x: cropX, y: cropY, width: cropWidth, height: cropHeight, confidence: point.density, strategy: strategyName));
      }
    }

    if (candidates.length < 3) {
      candidates.addAll(generateFallbackCandidates(cropWidth, cropHeight));
    }
    return candidates;
  }

  List<CropCoordinates> generateFallbackCandidates(double cropWidth, double cropHeight) {
    final fallbacks = <CropCoordinates>[];
    final positions = [const ui.Offset(0.5, 0.5), const ui.Offset(1/3, 1/3), const ui.Offset(2/3, 1/3), const ui.Offset(1/3, 2/3), const ui.Offset(2/3, 2/3)];
    for (final position in positions) {
      fallbacks.add(CropCoordinates(
        x: math.max(0.0, math.min(1.0 - cropWidth, position.dx - cropWidth / 2)),
        y: math.max(0.0, math.min(1.0 - cropHeight, position.dy - cropHeight / 2)),
        width: cropWidth, height: cropHeight, confidence: 0.2, strategy: strategyName));
    }
    return fallbacks;
  }

  double calculateEdgeDensity(double centerX, double centerY, ui.Size imageSize, Uint8List edgeData, double radius) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final pixelX = (centerX * width).round();
    final pixelY = (centerY * height).round();
    final pixelRadius = (radius * math.min(width, height)).round();
    double totalEdgeStrength = 0.0;
    int sampleCount = 0;
    for (int y = math.max(0, pixelY - pixelRadius); y <= math.min(height - 1, pixelY + pixelRadius); y++) {
      for (int x = math.max(0, pixelX - pixelRadius); x <= math.min(width - 1, pixelX + pixelRadius); x++) {
        if (math.pow(x - pixelX, 2) + math.pow(y - pixelY, 2) <= pixelRadius * pixelRadius) {
          totalEdgeStrength += edgeData[y * width + x];
          sampleCount++;
        }
      }
    }
    return sampleCount == 0 ? 0.0 : (totalEdgeStrength / sampleCount) / 255.0;
  }

  double scoreEdgeContent(CropCoordinates crop, ui.Size imageSize, Uint8List edgeData) {
    double score = 0.0;
    score += scoreAverageEdgeStrength(crop, imageSize, edgeData) * 0.5;
    score += scoreEdgeDistribution(crop, imageSize, edgeData) * 0.3;
    score += scoreStrongEdgeCount(crop, imageSize, edgeData) * 0.2;
    return math.min(1.0, score);
  }

  double scoreAverageEdgeStrength(CropCoordinates crop, ui.Size imageSize, Uint8List edgeData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final cropPixelX = (crop.x * width).round();
    final cropPixelY = (crop.y * height).round();
    final cropPixelWidth = (crop.width * width).round();
    final cropPixelHeight = (crop.height * height).round();
    double totalEdgeStrength = 0.0;
    int sampleCount = 0;
    final sampleStep = math.max(1, math.min(cropPixelWidth, cropPixelHeight) ~/ 16);
    for (int y = cropPixelY; y < cropPixelY + cropPixelHeight; y += sampleStep) {
      for (int x = cropPixelX; x < cropPixelX + cropPixelWidth; x += sampleStep) {
        if (x < width && y < height) {
          totalEdgeStrength += edgeData[y * width + x];
          sampleCount++;
        }
      }
    }
    return sampleCount == 0 ? 0.0 : (totalEdgeStrength / sampleCount) / 255.0;
  }

  double scoreEdgeDistribution(CropCoordinates crop, ui.Size imageSize, Uint8List edgeData) {
    final quadrantScores = <double>[];
    for (int qy = 0; qy < 2; qy++) {
      for (int qx = 0; qx < 2; qx++) {
        final quadrantCrop = CropCoordinates(x: crop.x + (qx * crop.width / 2), y: crop.y + (qy * crop.height / 2), width: crop.width / 2, height: crop.height / 2, confidence: 0.0, strategy: strategyName);
        quadrantScores.add(scoreAverageEdgeStrength(quadrantCrop, imageSize, edgeData));
      }
    }
    if (quadrantScores.isEmpty) return 0.0;
    final mean = quadrantScores.reduce((a, b) => a + b) / quadrantScores.length;
    final variance = quadrantScores.map((score) => math.pow(score - mean, 2)).reduce((a, b) => a + b) / quadrantScores.length;
    return mean > 0.05 ? math.max(0.0, 1.0 - variance * 10) : 0.0;
  }

  double scoreStrongEdgeCount(CropCoordinates crop, ui.Size imageSize, Uint8List edgeData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final cropPixelX = (crop.x * width).round();
    final cropPixelY = (crop.y * height).round();
    final cropPixelWidth = (crop.width * width).round();
    final cropPixelHeight = (crop.height * height).round();
    int strongEdgeCount = 0;
    int totalSamples = 0;
    final sampleStep = math.max(1, math.min(cropPixelWidth, cropPixelHeight) ~/ 12);
    for (int y = cropPixelY; y < cropPixelY + cropPixelHeight; y += sampleStep) {
      for (int x = cropPixelX; x < cropPixelX + cropPixelWidth; x += sampleStep) {
        if (x < width && y < height) {
          if (edgeData[y * width + x] > 128) strongEdgeCount++;
          totalSamples++;
        }
      }
    }
    return totalSamples == 0 ? 0.0 : strongEdgeCount / totalSamples;
  }

  Map<String, double> calculateMetricsSync(CropCoordinates crop, ui.Size imageSize, Uint8List edgeData) {
    return {
      'average_edge_strength': scoreAverageEdgeStrength(crop, imageSize, edgeData),
      'edge_distribution': scoreEdgeDistribution(crop, imageSize, edgeData),
      'strong_edge_ratio': scoreStrongEdgeCount(crop, imageSize, edgeData),
      'crop_area_ratio': crop.width * crop.height,
      'center_distance': math.sqrt(math.pow((crop.x + crop.width / 2) - 0.5, 2) + math.pow((crop.y + crop.height / 2) - 0.5, 2)),
    };
  }
}

class _EdgeDensityPoint {
  final double x;
  final double y;
  final double density;
  _EdgeDensityPoint(this.x, this.y, this.density);
}
