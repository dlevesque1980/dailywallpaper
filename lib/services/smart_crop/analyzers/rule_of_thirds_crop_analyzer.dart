import 'dart:ui' as ui;
import 'dart:math' as math;
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Crop analyzer that uses the rule of thirds photography principle
/// 
/// This analyzer evaluates crop areas based on how well they align with
/// the rule of thirds grid, scoring higher when important content falls
/// on intersection points or grid lines.
class RuleOfThirdsCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'rule_of_thirds';

  @override
  double get weight => 0.8; // High weight as rule of thirds is fundamental

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.1;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    
    // Calculate the target aspect ratio
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;
    
    CropCoordinates? bestCrop;
    double bestScore = 0.0;
    Map<String, double> bestMetrics = {};
    
    // Generate multiple crop candidates and score them
    final candidates = _generateCropCandidates(imageSize, targetAspectRatio);
    
    for (final candidate in candidates) {
      final score = _scoreRuleOfThirds(candidate, imageSize);
      final metrics = _calculateMetrics(candidate, imageSize);
      
      if (score > bestScore) {
        bestScore = score;
        bestCrop = candidate;
        bestMetrics = metrics;
      }
    }
    
    // If no good candidates found, use center crop as fallback
    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    bestMetrics = _calculateMetrics(bestCrop, imageSize);
    
    return CropScore(
      coordinates: bestCrop,
      score: bestScore,
      strategy: strategyName,
      metrics: bestMetrics,
    );
  }

  /// Generates crop candidates based on rule of thirds intersections
  List<CropCoordinates> _generateCropCandidates(ui.Size imageSize, double targetAspectRatio) {
    final candidates = <CropCoordinates>[];
    
    // Calculate crop dimensions
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);
    
    // Rule of thirds intersection points (normalized coordinates)
    final intersectionPoints = [
      const ui.Offset(1/3, 1/3),   // Top-left intersection
      const ui.Offset(2/3, 1/3),   // Top-right intersection
      const ui.Offset(1/3, 2/3),   // Bottom-left intersection
      const ui.Offset(2/3, 2/3),   // Bottom-right intersection
      const ui.Offset(0.5, 0.5),   // Center (not rule of thirds but good fallback)
    ];
    
    // Generate crops centered on intersection points
    for (final point in intersectionPoints) {
      final cropX = math.max(0.0, math.min(1.0 - cropWidth, point.dx - cropWidth / 2));
      final cropY = math.max(0.0, math.min(1.0 - cropHeight, point.dy - cropHeight / 2));
      
      candidates.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.5, // Will be updated by scoring
        strategy: strategyName,
      ));
    }
    
    // Add edge-aligned crops (content along grid lines)
    candidates.addAll(_generateEdgeAlignedCrops(cropWidth, cropHeight));
    
    return candidates;
  }

  /// Generates crops aligned with rule of thirds grid lines
  List<CropCoordinates> _generateEdgeAlignedCrops(double cropWidth, double cropHeight) {
    final crops = <CropCoordinates>[];
    
    // Vertical third lines
    final verticalLines = [1/3 - cropWidth/2, 2/3 - cropWidth/2];
    // Horizontal third lines  
    final horizontalLines = [1/3 - cropHeight/2, 2/3 - cropHeight/2];
    
    // Crops aligned with vertical lines
    for (final x in verticalLines) {
      if (x >= 0.0 && x + cropWidth <= 1.0) {
        crops.add(CropCoordinates(
          x: x,
          y: math.max(0.0, (1.0 - cropHeight) / 2), // Center vertically
          width: cropWidth,
          height: cropHeight,
          confidence: 0.4,
          strategy: strategyName,
        ));
      }
    }
    
    // Crops aligned with horizontal lines
    for (final y in horizontalLines) {
      if (y >= 0.0 && y + cropHeight <= 1.0) {
        crops.add(CropCoordinates(
          x: math.max(0.0, (1.0 - cropWidth) / 2), // Center horizontally
          y: y,
          width: cropWidth,
          height: cropHeight,
          confidence: 0.4,
          strategy: strategyName,
        ));
      }
    }
    
    return crops;
  }

  /// Scores a crop based on rule of thirds compliance
  double _scoreRuleOfThirds(CropCoordinates crop, ui.Size imageSize) {
    double score = 0.0;
    
    // Score based on intersection point alignment
    score += _scoreIntersectionAlignment(crop) * 0.4;
    
    // Score based on grid line alignment
    score += _scoreGridLineAlignment(crop) * 0.3;
    
    // Score based on content distribution
    score += _scoreContentDistribution(crop) * 0.2;
    
    // Bonus for avoiding extreme edges
    score += _scoreEdgeAvoidance(crop) * 0.1;
    
    return math.min(1.0, score);
  }

  /// Scores how well the crop aligns with rule of thirds intersection points
  double _scoreIntersectionAlignment(CropCoordinates crop) {
    final cropCenterX = crop.x + crop.width / 2;
    final cropCenterY = crop.y + crop.height / 2;
    
    // Rule of thirds intersection points
    final intersections = [
      const ui.Offset(1/3, 1/3),
      const ui.Offset(2/3, 1/3),
      const ui.Offset(1/3, 2/3),
      const ui.Offset(2/3, 2/3),
    ];
    
    double bestAlignment = 0.0;
    
    for (final intersection in intersections) {
      final distance = math.sqrt(
        math.pow(cropCenterX - intersection.dx, 2) + 
        math.pow(cropCenterY - intersection.dy, 2)
      );
      
      // Convert distance to alignment score (closer = higher score)
      final alignment = math.max(0.0, 1.0 - distance * 2); // Scale factor of 2
      bestAlignment = math.max(bestAlignment, alignment);
    }
    
    return bestAlignment;
  }

  /// Scores how well the crop edges align with rule of thirds grid lines
  double _scoreGridLineAlignment(CropCoordinates crop) {
    final gridLines = [1/3, 2/3];
    double alignmentScore = 0.0;
    int alignmentCount = 0;
    
    // Check vertical alignment
    for (final line in gridLines) {
      final leftDistance = (crop.x - line).abs();
      final rightDistance = ((crop.x + crop.width) - line).abs();
      
      if (leftDistance < 0.05) { // Within 5% tolerance
        alignmentScore += 1.0 - leftDistance * 20; // Scale to 0-1
        alignmentCount++;
      }
      if (rightDistance < 0.05) {
        alignmentScore += 1.0 - rightDistance * 20;
        alignmentCount++;
      }
    }
    
    // Check horizontal alignment
    for (final line in gridLines) {
      final topDistance = (crop.y - line).abs();
      final bottomDistance = ((crop.y + crop.height) - line).abs();
      
      if (topDistance < 0.05) {
        alignmentScore += 1.0 - topDistance * 20;
        alignmentCount++;
      }
      if (bottomDistance < 0.05) {
        alignmentScore += 1.0 - bottomDistance * 20;
        alignmentCount++;
      }
    }
    
    return alignmentCount > 0 ? alignmentScore / alignmentCount : 0.0;
  }

  /// Scores the content distribution within the crop area
  double _scoreContentDistribution(CropCoordinates crop) {
    // This is a simplified content distribution score
    // In a real implementation, this would analyze actual image content
    
    // Prefer crops that don't cut off too much from any side
    final marginLeft = crop.x;
    final marginRight = 1.0 - (crop.x + crop.width);
    final marginTop = crop.y;
    final marginBottom = 1.0 - (crop.y + crop.height);
    
    // Penalize crops that are too close to edges
    final edgePenalty = math.min(marginLeft, marginRight) + math.min(marginTop, marginBottom);
    
    // Prefer balanced crops
    final balance = 1.0 - (marginLeft - marginRight).abs() - (marginTop - marginBottom).abs();
    
    return math.max(0.0, (edgePenalty + balance) / 2);
  }

  /// Scores edge avoidance (prefer crops not at extreme edges)
  double _scoreEdgeAvoidance(CropCoordinates crop) {
    final centerX = crop.x + crop.width / 2;
    final centerY = crop.y + crop.height / 2;
    
    // Distance from image center (0.5, 0.5)
    final distanceFromCenter = math.sqrt(
      math.pow(centerX - 0.5, 2) + math.pow(centerY - 0.5, 2)
    );
    
    // Prefer crops not too far from center, but not exactly centered
    final idealDistance = 0.15; // Slightly off-center is ideal
    final distanceScore = 1.0 - (distanceFromCenter - idealDistance).abs() * 2;
    
    return math.max(0.0, distanceScore);
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
      confidence: 0.3, // Lower confidence for fallback
      strategy: strategyName,
    );
  }

  /// Calculates detailed metrics for the crop
  Map<String, double> _calculateMetrics(CropCoordinates crop, ui.Size imageSize) {
    return {
      'intersection_alignment': _scoreIntersectionAlignment(crop),
      'grid_line_alignment': _scoreGridLineAlignment(crop),
      'content_distribution': _scoreContentDistribution(crop),
      'edge_avoidance': _scoreEdgeAvoidance(crop),
      'crop_area_ratio': crop.width * crop.height,
      'center_distance': math.sqrt(
        math.pow((crop.x + crop.width / 2) - 0.5, 2) + 
        math.pow((crop.y + crop.height / 2) - 0.5, 2)
      ),
    };
  }
}