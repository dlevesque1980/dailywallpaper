import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
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
  bool get isEnabledByDefault => false; // More CPU intensive, disabled by default

  @override
  double get minConfidenceThreshold => 0.1;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    
    // Calculate the target aspect ratio
    final targetAspectRatio = targetSize.width / targetSize.height;
    
    CropCoordinates? bestCrop;
    double bestScore = 0.0;
    Map<String, double> bestMetrics = {};
    
    // Get image data for edge detection
    final imageData = await _getImageData(image);
    final grayscaleData = _convertToGrayscale(imageData, image.width, image.height);
    
    // Apply edge detection
    final edgeData = _applySobelEdgeDetection(grayscaleData, image.width, image.height);
    
    // Generate crop candidates based on edge density
    final candidates = _generateEdgeBasedCandidates(imageSize, targetAspectRatio, edgeData);
    
    for (final candidate in candidates) {
      final score = _scoreEdgeContent(candidate, imageSize, edgeData);
      final metrics = _calculateMetrics(candidate, imageSize, edgeData);
      
      if (score > bestScore) {
        bestScore = score;
        bestCrop = candidate;
        bestMetrics = metrics;
      }
    }
    
    // Fallback to center crop if no good candidates
    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    bestMetrics = _calculateMetrics(bestCrop, imageSize, edgeData);
    
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

  /// Converts RGBA image data to grayscale
  Uint8List _convertToGrayscale(Uint8List rgbaData, int width, int height) {
    final grayscale = Uint8List(width * height);
    
    for (int i = 0; i < width * height; i++) {
      final rgbaIndex = i * 4;
      final r = rgbaData[rgbaIndex];
      final g = rgbaData[rgbaIndex + 1];
      final b = rgbaData[rgbaIndex + 2];
      
      // Convert to grayscale using luminance formula
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
      grayscale[i] = gray.clamp(0, 255);
    }
    
    return grayscale;
  }

  /// Applies Sobel edge detection to grayscale image data
  Uint8List _applySobelEdgeDetection(Uint8List grayscaleData, int width, int height) {
    final edgeData = Uint8List(width * height);
    
    // Sobel kernels
    final sobelX = [
      [-1, 0, 1],
      [-2, 0, 2],
      [-1, 0, 1],
    ];
    
    final sobelY = [
      [-1, -2, -1],
      [0, 0, 0],
      [1, 2, 1],
    ];
    
    // Apply Sobel operator (skip border pixels)
    for (int y = 1; y < height - 1; y++) {
      for (int x = 1; x < width - 1; x++) {
        double gx = 0.0;
        double gy = 0.0;
        
        // Apply kernels
        for (int ky = -1; ky <= 1; ky++) {
          for (int kx = -1; kx <= 1; kx++) {
            final pixelIndex = (y + ky) * width + (x + kx);
            final pixelValue = grayscaleData[pixelIndex];
            
            gx += pixelValue * sobelX[ky + 1][kx + 1];
            gy += pixelValue * sobelY[ky + 1][kx + 1];
          }
        }
        
        // Calculate edge magnitude
        final magnitude = math.sqrt(gx * gx + gy * gy);
        final normalizedMagnitude = (magnitude / 4).clamp(0, 255).round();
        
        edgeData[y * width + x] = normalizedMagnitude;
      }
    }
    
    return edgeData;
  }

  /// Generates crop candidates based on edge density hotspots
  List<CropCoordinates> _generateEdgeBasedCandidates(
    ui.Size imageSize, 
    double targetAspectRatio,
    Uint8List edgeData
  ) {
    final candidates = <CropCoordinates>[];
    
    // Calculate crop dimensions
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);
    
    // Create a grid for edge density sampling
    final gridSize = 6; // 6x6 grid for performance balance
    final stepX = 1.0 / gridSize;
    final stepY = 1.0 / gridSize;
    
    // Sample edge density at grid points
    final edgeDensities = <_EdgeDensityPoint>[];
    
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final centerX = (i + 0.5) * stepX;
        final centerY = (j + 0.5) * stepY;
        
        final density = _calculateEdgeDensity(
          centerX, centerY, imageSize, edgeData, 0.15 // 15% sample radius
        );
        
        edgeDensities.add(_EdgeDensityPoint(centerX, centerY, density));
      }
    }
    
    // Sort by edge density and take top candidates
    edgeDensities.sort((a, b) => b.density.compareTo(a.density));
    
    // Generate crops around high-edge-density areas
    for (final point in edgeDensities.take(8)) {
      if (point.density > 0.1) { // Minimum edge density threshold
        final cropX = math.max(0.0, math.min(1.0 - cropWidth, point.x - cropWidth / 2));
        final cropY = math.max(0.0, math.min(1.0 - cropHeight, point.y - cropHeight / 2));
        
        candidates.add(CropCoordinates(
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
          confidence: point.density, // Use edge density as initial confidence
          strategy: strategyName,
        ));
      }
    }
    
    // Add fallback candidates if not enough edge-based ones
    if (candidates.length < 3) {
      candidates.addAll(_generateFallbackCandidates(cropWidth, cropHeight));
    }
    
    return candidates;
  }

  /// Generates fallback candidates when edge detection doesn't find enough areas
  List<CropCoordinates> _generateFallbackCandidates(double cropWidth, double cropHeight) {
    final fallbacks = <CropCoordinates>[];
    
    // Standard positions
    final positions = [
      const ui.Offset(0.5, 0.5),     // Center
      const ui.Offset(1/3, 1/3),     // Top-left third
      const ui.Offset(2/3, 1/3),     // Top-right third
      const ui.Offset(1/3, 2/3),     // Bottom-left third
      const ui.Offset(2/3, 2/3),     // Bottom-right third
    ];
    
    for (final position in positions) {
      final cropX = math.max(0.0, math.min(1.0 - cropWidth, position.dx - cropWidth / 2));
      final cropY = math.max(0.0, math.min(1.0 - cropHeight, position.dy - cropHeight / 2));
      
      fallbacks.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.2, // Lower confidence for fallbacks
        strategy: strategyName,
      ));
    }
    
    return fallbacks;
  }

  /// Calculates edge density around a point
  double _calculateEdgeDensity(
    double centerX, 
    double centerY, 
    ui.Size imageSize, 
    Uint8List edgeData,
    double radius
  ) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    
    // Convert normalized coordinates to pixel coordinates
    final pixelX = (centerX * width).round();
    final pixelY = (centerY * height).round();
    final pixelRadius = (radius * math.min(width, height)).round();
    
    double totalEdgeStrength = 0.0;
    int sampleCount = 0;
    
    final startX = math.max(0, pixelX - pixelRadius);
    final endX = math.min(width - 1, pixelX + pixelRadius);
    final startY = math.max(0, pixelY - pixelRadius);
    final endY = math.min(height - 1, pixelY + pixelRadius);
    
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        // Check if pixel is within circular radius
        final dx = x - pixelX;
        final dy = y - pixelY;
        if (dx * dx + dy * dy <= pixelRadius * pixelRadius) {
          final pixelIndex = y * width + x;
          if (pixelIndex < edgeData.length) {
            totalEdgeStrength += edgeData[pixelIndex];
            sampleCount++;
          }
        }
      }
    }
    
    if (sampleCount == 0) return 0.0;
    
    // Normalize to 0-1 range
    final averageEdgeStrength = totalEdgeStrength / sampleCount;
    return averageEdgeStrength / 255.0;
  }

  /// Scores a crop based on edge content
  double _scoreEdgeContent(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List edgeData
  ) {
    double score = 0.0;
    
    // Average edge strength within crop (50% of score)
    score += _scoreAverageEdgeStrength(crop, imageSize, edgeData) * 0.5;
    
    // Edge distribution (prefer well-distributed edges) (30% of score)
    score += _scoreEdgeDistribution(crop, imageSize, edgeData) * 0.3;
    
    // Strong edge count (prefer areas with many strong edges) (20% of score)
    score += _scoreStrongEdgeCount(crop, imageSize, edgeData) * 0.2;
    
    return math.min(1.0, score);
  }

  /// Scores the average edge strength within the crop area
  double _scoreAverageEdgeStrength(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List edgeData
  ) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    
    final cropPixelX = (crop.x * width).round();
    final cropPixelY = (crop.y * height).round();
    final cropPixelWidth = (crop.width * width).round();
    final cropPixelHeight = (crop.height * height).round();
    
    double totalEdgeStrength = 0.0;
    int sampleCount = 0;
    
    // Sample every few pixels for performance
    final sampleStep = math.max(1, math.min(cropPixelWidth, cropPixelHeight) ~/ 16);
    
    for (int y = cropPixelY; y < cropPixelY + cropPixelHeight; y += sampleStep) {
      for (int x = cropPixelX; x < cropPixelX + cropPixelWidth; x += sampleStep) {
        if (x < width && y < height) {
          final pixelIndex = y * width + x;
          if (pixelIndex < edgeData.length) {
            totalEdgeStrength += edgeData[pixelIndex];
            sampleCount++;
          }
        }
      }
    }
    
    if (sampleCount == 0) return 0.0;
    
    // Normalize to 0-1 range
    return (totalEdgeStrength / sampleCount) / 255.0;
  }

  /// Scores edge distribution within the crop (prefer well-distributed edges)
  double _scoreEdgeDistribution(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List edgeData
  ) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    
    // Divide crop into quadrants and check edge distribution
    final quadrantScores = <double>[];
    
    for (int qy = 0; qy < 2; qy++) {
      for (int qx = 0; qx < 2; qx++) {
        final quadrantX = crop.x + (qx * crop.width / 2);
        final quadrantY = crop.y + (qy * crop.height / 2);
        final quadrantWidth = crop.width / 2;
        final quadrantHeight = crop.height / 2;
        
        final quadrantCrop = CropCoordinates(
          x: quadrantX,
          y: quadrantY,
          width: quadrantWidth,
          height: quadrantHeight,
          confidence: 0.0,
          strategy: strategyName,
        );
        
        final quadrantScore = _scoreAverageEdgeStrength(quadrantCrop, imageSize, edgeData);
        quadrantScores.add(quadrantScore);
      }
    }
    
    if (quadrantScores.isEmpty) return 0.0;
    
    // Calculate distribution score (prefer balanced distribution)
    final mean = quadrantScores.reduce((a, b) => a + b) / quadrantScores.length;
    final variance = quadrantScores
        .map((score) => math.pow(score - mean, 2))
        .reduce((a, b) => a + b) / quadrantScores.length;
    
    // Lower variance = better distribution, but we also want some minimum edge content
    final distributionScore = mean > 0.05 ? math.max(0.0, 1.0 - variance * 10) : 0.0;
    
    return distributionScore;
  }

  /// Scores the count of strong edges within the crop
  double _scoreStrongEdgeCount(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List edgeData
  ) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    
    final cropPixelX = (crop.x * width).round();
    final cropPixelY = (crop.y * height).round();
    final cropPixelWidth = (crop.width * width).round();
    final cropPixelHeight = (crop.height * height).round();
    
    int strongEdgeCount = 0;
    int totalSamples = 0;
    final strongEdgeThreshold = 128; // Threshold for "strong" edge
    
    // Sample every few pixels
    final sampleStep = math.max(1, math.min(cropPixelWidth, cropPixelHeight) ~/ 12);
    
    for (int y = cropPixelY; y < cropPixelY + cropPixelHeight; y += sampleStep) {
      for (int x = cropPixelX; x < cropPixelX + cropPixelWidth; x += sampleStep) {
        if (x < width && y < height) {
          final pixelIndex = y * width + x;
          if (pixelIndex < edgeData.length) {
            if (edgeData[pixelIndex] > strongEdgeThreshold) {
              strongEdgeCount++;
            }
            totalSamples++;
          }
        }
      }
    }
    
    if (totalSamples == 0) return 0.0;
    
    // Return ratio of strong edges to total samples
    return strongEdgeCount / totalSamples;
  }

  /// Calculates crop width based on target aspect ratio
  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    
    if (targetAspectRatio > imageAspectRatio) {
      return 1.0;
    } else {
      return targetAspectRatio / imageAspectRatio;
    }
  }

  /// Calculates crop height based on target aspect ratio
  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    
    if (targetAspectRatio < imageAspectRatio) {
      return 1.0;
    } else {
      return imageAspectRatio / targetAspectRatio;
    }
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
      confidence: 0.3, // Lower confidence for fallback
      strategy: strategyName,
    );
  }

  /// Calculates detailed metrics for the crop
  Map<String, double> _calculateMetrics(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List edgeData
  ) {
    return {
      'average_edge_strength': _scoreAverageEdgeStrength(crop, imageSize, edgeData),
      'edge_distribution': _scoreEdgeDistribution(crop, imageSize, edgeData),
      'strong_edge_ratio': _scoreStrongEdgeCount(crop, imageSize, edgeData),
      'crop_area_ratio': crop.width * crop.height,
      'center_distance': math.sqrt(
        math.pow((crop.x + crop.width / 2) - 0.5, 2) + 
        math.pow((crop.y + crop.height / 2) - 0.5, 2)
      ),
    };
  }
}

/// Helper class for edge density points
class _EdgeDensityPoint {
  final double x;
  final double y;
  final double density;
  
  _EdgeDensityPoint(this.x, this.y, this.density);
}