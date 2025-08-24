import 'dart:ui' as ui;
import 'dart:math' as math;
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Crop analyzer that uses center-weighted scoring with distance falloff
/// 
/// This analyzer prefers crops that keep content near the center of the image,
/// with scoring that falls off with distance from center. It provides a
/// conservative cropping approach that minimizes the risk of cutting off
/// important content.
class CenterWeightedCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'center_weighted';

  @override
  double get weight => 0.6; // Moderate weight for conservative approach

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.2;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    
    // Calculate the target aspect ratio
    final targetAspectRatio = targetSize.width / targetSize.height;
    
    CropCoordinates? bestCrop;
    double bestScore = 0.0;
    Map<String, double> bestMetrics = {};
    
    // Generate crop candidates with center bias
    final candidates = _generateCenterBiasedCandidates(imageSize, targetAspectRatio);
    
    for (final candidate in candidates) {
      final score = _scoreCenterWeighted(candidate, imageSize);
      final metrics = _calculateMetrics(candidate, imageSize);
      
      if (score > bestScore) {
        bestScore = score;
        bestCrop = candidate;
        bestMetrics = metrics;
      }
    }
    
    // Fallback to center crop if no good candidates
    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    bestMetrics = _calculateMetrics(bestCrop, imageSize);
    
    return CropScore(
      coordinates: bestCrop,
      score: bestScore,
      strategy: strategyName,
      metrics: bestMetrics,
    );
  }

  /// Generates crop candidates with center bias
  List<CropCoordinates> _generateCenterBiasedCandidates(ui.Size imageSize, double targetAspectRatio) {
    final candidates = <CropCoordinates>[];
    
    // Calculate crop dimensions
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);
    
    // Center crop (highest priority)
    candidates.add(_getCenterCrop(imageSize, targetAspectRatio));
    
    // Generate crops in concentric rings around center
    final ringCount = 3;
    final maxOffset = math.min(
      (1.0 - cropWidth) / 2,
      (1.0 - cropHeight) / 2,
    );
    
    for (int ring = 1; ring <= ringCount; ring++) {
      final ringRadius = (ring / ringCount) * maxOffset;
      final pointsInRing = ring * 8; // More points in outer rings
      
      for (int i = 0; i < pointsInRing; i++) {
        final angle = (i / pointsInRing) * 2 * math.pi;
        final offsetX = math.cos(angle) * ringRadius;
        final offsetY = math.sin(angle) * ringRadius;
        
        final centerX = 0.5 + offsetX;
        final centerY = 0.5 + offsetY;
        
        final cropX = math.max(0.0, math.min(1.0 - cropWidth, centerX - cropWidth / 2));
        final cropY = math.max(0.0, math.min(1.0 - cropHeight, centerY - cropHeight / 2));
        
        candidates.add(CropCoordinates(
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
          confidence: 0.5,
          strategy: strategyName,
        ));
      }
    }
    
    // Add edge-safe crops (slightly inset from edges)
    candidates.addAll(_generateEdgeSafeCrops(cropWidth, cropHeight));
    
    return candidates;
  }

  /// Generates crops that are safely inset from image edges
  List<CropCoordinates> _generateEdgeSafeCrops(double cropWidth, double cropHeight) {
    final crops = <CropCoordinates>[];
    final safeMargin = 0.05; // 5% margin from edges
    
    // Calculate safe bounds
    final minX = safeMargin;
    final maxX = math.max(minX, 1.0 - cropWidth - safeMargin);
    final minY = safeMargin;
    final maxY = math.max(minY, 1.0 - cropHeight - safeMargin);
    
    if (maxX >= minX && maxY >= minY) {
      // Corner positions with safe margins
      final positions = [
        ui.Offset(minX, minY),                    // Top-left
        ui.Offset(maxX, minY),                    // Top-right
        ui.Offset(minX, maxY),                    // Bottom-left
        ui.Offset(maxX, maxY),                    // Bottom-right
        ui.Offset((minX + maxX) / 2, minY),       // Top-center
        ui.Offset((minX + maxX) / 2, maxY),       // Bottom-center
        ui.Offset(minX, (minY + maxY) / 2),       // Left-center
        ui.Offset(maxX, (minY + maxY) / 2),       // Right-center
      ];
      
      for (final position in positions) {
        crops.add(CropCoordinates(
          x: position.dx,
          y: position.dy,
          width: cropWidth,
          height: cropHeight,
          confidence: 0.3, // Lower confidence for edge positions
          strategy: strategyName,
        ));
      }
    }
    
    return crops;
  }

  /// Scores a crop using center-weighted algorithm with distance falloff
  double _scoreCenterWeighted(CropCoordinates crop, ui.Size imageSize) {
    double score = 0.0;
    
    // Center distance scoring (40% of total score)
    score += _scoreCenterDistance(crop) * 0.4;
    
    // Content preservation scoring (30% of total score)
    score += _scoreContentPreservation(crop) * 0.3;
    
    // Edge safety scoring (20% of total score)
    score += _scoreEdgeSafety(crop) * 0.2;
    
    // Aspect ratio preservation (10% of total score)
    score += _scoreAspectRatioPreservation(crop, imageSize) * 0.1;
    
    return math.min(1.0, score);
  }

  /// Scores based on distance from image center (closer = higher score)
  double _scoreCenterDistance(CropCoordinates crop) {
    final cropCenterX = crop.x + crop.width / 2;
    final cropCenterY = crop.y + crop.height / 2;
    
    // Calculate distance from image center (0.5, 0.5)
    final distanceFromCenter = math.sqrt(
      math.pow(cropCenterX - 0.5, 2) + math.pow(cropCenterY - 0.5, 2)
    );
    
    // Maximum possible distance is from center to corner
    final maxDistance = math.sqrt(0.5);
    
    // Convert distance to score with exponential falloff
    final normalizedDistance = distanceFromCenter / maxDistance;
    final falloffFactor = 2.0; // Controls how quickly score falls off
    
    return math.exp(-falloffFactor * normalizedDistance);
  }

  /// Scores content preservation (how much of original image is kept)
  double _scoreContentPreservation(CropCoordinates crop) {
    // Higher score for crops that preserve more content
    final contentRatio = crop.width * crop.height;
    
    // Bonus for preserving significant content while still cropping
    if (contentRatio >= 0.8) {
      return 1.0; // Excellent preservation
    } else if (contentRatio >= 0.6) {
      return 0.8 + (contentRatio - 0.6) * 1.0; // Good preservation
    } else if (contentRatio >= 0.4) {
      return 0.5 + (contentRatio - 0.4) * 1.5; // Moderate preservation
    } else {
      return contentRatio * 1.25; // Lower preservation
    }
  }

  /// Scores edge safety (avoiding cuts too close to edges)
  double _scoreEdgeSafety(CropCoordinates crop) {
    // Calculate margins from each edge
    final leftMargin = crop.x;
    final rightMargin = 1.0 - (crop.x + crop.width);
    final topMargin = crop.y;
    final bottomMargin = 1.0 - (crop.y + crop.height);
    
    // Find minimum margin (most constrained edge)
    final minMargin = math.min(
      math.min(leftMargin, rightMargin),
      math.min(topMargin, bottomMargin)
    );
    
    // Score based on minimum margin with safety threshold
    final safetyThreshold = 0.05; // 5% minimum safe margin
    
    if (minMargin >= safetyThreshold) {
      return 1.0; // Safe
    } else if (minMargin >= 0.0) {
      return minMargin / safetyThreshold; // Proportional to safety
    } else {
      return 0.0; // Invalid crop
    }
  }

  /// Scores aspect ratio preservation
  double _scoreAspectRatioPreservation(CropCoordinates crop, ui.Size imageSize) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    final cropAspectRatio = crop.width / crop.height;
    
    // Calculate how much the crop changes the aspect ratio
    final aspectRatioChange = (cropAspectRatio - imageAspectRatio).abs() / imageAspectRatio;
    
    // Score inversely proportional to aspect ratio change
    return math.max(0.0, 1.0 - aspectRatioChange);
  }

  /// Calculates crop width based on target aspect ratio
  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    
    if (targetAspectRatio > imageAspectRatio) {
      // Target is wider than image, use full width
      return 1.0;
    } else {
      // Target is taller than image, calculate width to maintain aspect ratio
      return targetAspectRatio / imageAspectRatio;
    }
  }

  /// Calculates crop height based on target aspect ratio
  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    
    if (targetAspectRatio < imageAspectRatio) {
      // Target is taller than image, use full height
      return 1.0;
    } else {
      // Target is wider than image, calculate height to maintain aspect ratio
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
      confidence: 0.8, // High confidence for center crop
      strategy: strategyName,
    );
  }

  /// Calculates detailed metrics for the crop
  Map<String, double> _calculateMetrics(CropCoordinates crop, ui.Size imageSize) {
    return {
      'center_distance_score': _scoreCenterDistance(crop),
      'content_preservation_score': _scoreContentPreservation(crop),
      'edge_safety_score': _scoreEdgeSafety(crop),
      'aspect_ratio_preservation_score': _scoreAspectRatioPreservation(crop, imageSize),
      'crop_area_ratio': crop.width * crop.height,
      'distance_from_center': math.sqrt(
        math.pow((crop.x + crop.width / 2) - 0.5, 2) + 
        math.pow((crop.y + crop.height / 2) - 0.5, 2)
      ),
      'min_edge_margin': math.min(
        math.min(crop.x, 1.0 - (crop.x + crop.width)),
        math.min(crop.y, 1.0 - (crop.y + crop.height))
      ),
    };
  }
}