import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Enhanced composition analyzer for smart cropping
///
/// This analyzer evaluates crop areas based on multiple composition rules:
/// - Rule of thirds
/// - Golden ratio (phi)
/// - Dynamic symmetry
/// - Leading lines
/// - Visual weight distribution
/// - Diagonal composition
class EnhancedCompositionCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'enhanced_composition';
  static const int _analyzerPriority = 750; // High priority for composition
  static const double _analyzerWeight = 0.8; // High weight for composition

  // Golden ratio constant
  static const double _goldenRatio = 0.618033988749; // 1/phi

  EnhancedCompositionCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 500),
          metadata: const AnalyzerMetadata(
            description:
                'Enhanced composition analyzer with rule of thirds, golden ratio, and other composition rules',
            version: '2.0.0',
            supportedImageTypes: ['jpeg', 'png', 'webp'],
            minImageWidth: 100,
            minImageHeight: 100,
            maxImageWidth: 2048,
            maxImageHeight: 2048,
            isCpuIntensive: false,
            isMemoryIntensive: false,
            supportsParallelExecution: true,
            dependencies: [],
            conflicts: [],
            configurationOptions: {
              'enableRuleOfThirds': true,
              'enableGoldenRatio': true,
              'enableDynamicSymmetry': true,
              'compositionWeight': 0.8,
            },
            performanceMetrics: {
              'baseProcessingTimeMs': 100,
              'pixelFactor': 0.00005,
            },
          ),
        );

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      // Get image data for visual weight analysis
      final imageData = await _getImageData(image);

      // Generate crop candidates using multiple composition rules
      final candidates =
          _generateCompositionCandidates(imageSize, targetAspectRatio);

      CropCoordinates? bestCrop;
      double bestScore = 0.0;
      Map<String, double> bestMetrics = {};

      // Score each candidate
      for (final candidate in candidates) {
        final score = await _scoreComposition(candidate, imageSize, imageData);
        final metrics =
            await _calculateCompositionMetrics(candidate, imageSize, imageData);

        if (score > bestScore) {
          bestScore = score;
          bestCrop = candidate;
          bestMetrics = metrics;
        }
      }

      // Fallback to center crop if no good candidates
      bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
      bestMetrics =
          await _calculateCompositionMetrics(bestCrop, imageSize, imageData);

      return CropScore(
        coordinates: bestCrop,
        score: bestScore,
        strategy: strategyName,
        metrics: bestMetrics,
      );
    } catch (e) {
      // Fallback to center crop on error
      final centerCrop = _getCenterCrop(imageSize, targetAspectRatio);
      return CropScore(
        coordinates: centerCrop,
        score: 0.3,
        strategy: strategyName,
        metrics: {
          'composition_score': 0.3,
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

  /// Generates crop candidates using multiple composition rules
  List<CropCoordinates> _generateCompositionCandidates(
      ui.Size imageSize, double targetAspectRatio) {
    final candidates = <CropCoordinates>[];

    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Rule of thirds candidates
    candidates.addAll(_generateRuleOfThirdsCandidates(cropWidth, cropHeight));

    // Golden ratio candidates
    candidates.addAll(_generateGoldenRatioCandidates(cropWidth, cropHeight));

    // Dynamic symmetry candidates
    candidates
        .addAll(_generateDynamicSymmetryCandidates(cropWidth, cropHeight));

    // Diagonal composition candidates
    candidates.addAll(_generateDiagonalCandidates(cropWidth, cropHeight));

    return candidates;
  }

  /// Generates rule of thirds composition candidates
  List<CropCoordinates> _generateRuleOfThirdsCandidates(
      double cropWidth, double cropHeight) {
    final candidates = <CropCoordinates>[];

    // Rule of thirds intersection points
    final intersectionPoints = [
      const ui.Offset(1 / 3, 1 / 3), // Top-left intersection
      const ui.Offset(2 / 3, 1 / 3), // Top-right intersection
      const ui.Offset(1 / 3, 2 / 3), // Bottom-left intersection
      const ui.Offset(2 / 3, 2 / 3), // Bottom-right intersection
    ];

    for (final point in intersectionPoints) {
      final cropX =
          math.max(0.0, math.min(1.0 - cropWidth, point.dx - cropWidth / 2));
      final cropY =
          math.max(0.0, math.min(1.0 - cropHeight, point.dy - cropHeight / 2));

      candidates.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.6,
        strategy: '${strategyName}_rule_of_thirds',
      ));
    }

    return candidates;
  }

  /// Generates golden ratio composition candidates
  List<CropCoordinates> _generateGoldenRatioCandidates(
      double cropWidth, double cropHeight) {
    final candidates = <CropCoordinates>[];

    // Golden ratio intersection points
    final goldenPoints = [
      ui.Offset(_goldenRatio, _goldenRatio), // Primary golden point
      ui.Offset(1 - _goldenRatio, _goldenRatio), // Secondary golden point
      ui.Offset(_goldenRatio, 1 - _goldenRatio), // Tertiary golden point
      ui.Offset(1 - _goldenRatio, 1 - _goldenRatio), // Quaternary golden point
    ];

    for (final point in goldenPoints) {
      final cropX =
          math.max(0.0, math.min(1.0 - cropWidth, point.dx - cropWidth / 2));
      final cropY =
          math.max(0.0, math.min(1.0 - cropHeight, point.dy - cropHeight / 2));

      candidates.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.7,
        strategy: '${strategyName}_golden_ratio',
      ));
    }

    return candidates;
  }

  /// Generates dynamic symmetry composition candidates
  List<CropCoordinates> _generateDynamicSymmetryCandidates(
      double cropWidth, double cropHeight) {
    final candidates = <CropCoordinates>[];

    // Dynamic symmetry points based on diagonal intersections
    final symmetryPoints = [
      const ui.Offset(0.25, 0.25), // Quarter points
      const ui.Offset(0.75, 0.25),
      const ui.Offset(0.25, 0.75),
      const ui.Offset(0.75, 0.75),
      const ui.Offset(0.5, 0.3), // Slightly off-center
      const ui.Offset(0.5, 0.7),
    ];

    for (final point in symmetryPoints) {
      final cropX =
          math.max(0.0, math.min(1.0 - cropWidth, point.dx - cropWidth / 2));
      final cropY =
          math.max(0.0, math.min(1.0 - cropHeight, point.dy - cropHeight / 2));

      candidates.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.5,
        strategy: '${strategyName}_dynamic_symmetry',
      ));
    }

    return candidates;
  }

  /// Generates diagonal composition candidates
  List<CropCoordinates> _generateDiagonalCandidates(
      double cropWidth, double cropHeight) {
    final candidates = <CropCoordinates>[];

    // Points along diagonal lines for dynamic composition
    final diagonalPoints = [
      const ui.Offset(0.2, 0.8), // Lower diagonal
      const ui.Offset(0.8, 0.2), // Upper diagonal
      const ui.Offset(0.3, 0.7), // Moderate diagonal
      const ui.Offset(0.7, 0.3),
    ];

    for (final point in diagonalPoints) {
      final cropX =
          math.max(0.0, math.min(1.0 - cropWidth, point.dx - cropWidth / 2));
      final cropY =
          math.max(0.0, math.min(1.0 - cropHeight, point.dy - cropHeight / 2));

      candidates.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.4,
        strategy: '${strategyName}_diagonal',
      ));
    }

    return candidates;
  }

  /// Scores a crop based on multiple composition rules
  Future<double> _scoreComposition(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) async {
    double score = 0.0;

    // Rule of thirds score (25%)
    score += _scoreRuleOfThirds(crop) * 0.25;

    // Golden ratio score (25%)
    score += _scoreGoldenRatio(crop) * 0.25;

    // Visual weight distribution (20%)
    score += _scoreVisualWeight(crop, imageSize, imageData) * 0.20;

    // Dynamic symmetry score (15%)
    score += _scoreDynamicSymmetry(crop) * 0.15;

    // Edge avoidance and balance (15%)
    score += _scoreBalance(crop) * 0.15;

    return math.min(1.0, score);
  }

  /// Scores rule of thirds compliance
  double _scoreRuleOfThirds(CropCoordinates crop) {
    final cropCenterX = crop.x + crop.width / 2;
    final cropCenterY = crop.y + crop.height / 2;

    // Rule of thirds intersection points
    final intersections = [
      const ui.Offset(1 / 3, 1 / 3),
      const ui.Offset(2 / 3, 1 / 3),
      const ui.Offset(1 / 3, 2 / 3),
      const ui.Offset(2 / 3, 2 / 3),
    ];

    double bestAlignment = 0.0;

    for (final intersection in intersections) {
      final distance = math.sqrt(math.pow(cropCenterX - intersection.dx, 2) +
          math.pow(cropCenterY - intersection.dy, 2));

      final alignment = math.max(
          0.0, 1.0 - distance * 3); // Stricter than basic rule of thirds
      bestAlignment = math.max(bestAlignment, alignment);
    }

    return bestAlignment;
  }

  /// Scores golden ratio compliance
  double _scoreGoldenRatio(CropCoordinates crop) {
    final cropCenterX = crop.x + crop.width / 2;
    final cropCenterY = crop.y + crop.height / 2;

    // Golden ratio points
    final goldenPoints = [
      ui.Offset(_goldenRatio, _goldenRatio),
      ui.Offset(1 - _goldenRatio, _goldenRatio),
      ui.Offset(_goldenRatio, 1 - _goldenRatio),
      ui.Offset(1 - _goldenRatio, 1 - _goldenRatio),
    ];

    double bestAlignment = 0.0;

    for (final point in goldenPoints) {
      final distance = math.sqrt(math.pow(cropCenterX - point.dx, 2) +
          math.pow(cropCenterY - point.dy, 2));

      final alignment = math.max(0.0, 1.0 - distance * 2.5);
      bestAlignment = math.max(bestAlignment, alignment);
    }

    return bestAlignment;
  }

  /// Scores visual weight distribution within the crop
  double _scoreVisualWeight(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    // Calculate visual weight in different regions of the crop
    final cropLeft = (crop.x * width).round();
    final cropTop = (crop.y * height).round();
    final cropRight = ((crop.x + crop.width) * width).round();
    final cropBottom = ((crop.y + crop.height) * height).round();

    // Divide crop into quadrants and calculate visual weight
    final quadrantWeights = <double>[];

    final midX = (cropLeft + cropRight) ~/ 2;
    final midY = (cropTop + cropBottom) ~/ 2;

    // Top-left quadrant
    quadrantWeights.add(_calculateVisualWeight(
        imageData, width, height, cropLeft, midX, cropTop, midY));

    // Top-right quadrant
    quadrantWeights.add(_calculateVisualWeight(
        imageData, width, height, midX, cropRight, cropTop, midY));

    // Bottom-left quadrant
    quadrantWeights.add(_calculateVisualWeight(
        imageData, width, height, cropLeft, midX, midY, cropBottom));

    // Bottom-right quadrant
    quadrantWeights.add(_calculateVisualWeight(
        imageData, width, height, midX, cropRight, midY, cropBottom));

    // Calculate balance - prefer some asymmetry but not extreme imbalance
    final totalWeight = quadrantWeights.reduce((a, b) => a + b);
    if (totalWeight == 0) return 0.5; // Neutral score for uniform images

    final normalizedWeights =
        quadrantWeights.map((w) => w / totalWeight).toList();

    // Prefer slight imbalance (more interesting) but not extreme
    final variance = _calculateVariance(normalizedWeights);
    final idealVariance = 0.15; // Some variation is good
    final balanceScore = 1.0 - (variance - idealVariance).abs() * 5;

    return math.max(0.0, math.min(1.0, balanceScore));
  }

  /// Calculates visual weight in a region based on contrast and brightness
  double _calculateVisualWeight(Uint8List imageData, int width, int height,
      int startX, int endX, int startY, int endY) {
    double totalWeight = 0.0;
    int pixelCount = 0;

    for (int y = startY; y < endY; y += 3) {
      for (int x = startX; x < endX; x += 3) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        // Calculate visual weight based on brightness and saturation
        final brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        final saturation = _calculateSaturation(r, g, b);

        // Higher contrast and saturation = higher visual weight
        final weight = (brightness * 0.7) + (saturation * 0.3);
        totalWeight += weight;
        pixelCount++;
      }
    }

    return pixelCount > 0 ? totalWeight / pixelCount : 0.0;
  }

  /// Calculates color saturation
  double _calculateSaturation(int r, int g, int b) {
    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));

    if (max == 0) return 0.0;

    return (max - min) / max;
  }

  /// Calculates variance of a list of values
  double _calculateVariance(List<double> values) {
    if (values.isEmpty) return 0.0;

    final mean = values.reduce((a, b) => a + b) / values.length;
    final squaredDiffs = values.map((v) => math.pow(v - mean, 2));

    return squaredDiffs.reduce((a, b) => a + b) / values.length;
  }

  /// Scores dynamic symmetry
  double _scoreDynamicSymmetry(CropCoordinates crop) {
    final cropCenterX = crop.x + crop.width / 2;
    final cropCenterY = crop.y + crop.height / 2;

    // Check alignment with dynamic symmetry diagonals
    final diagonalScore1 =
        1.0 - (cropCenterX + cropCenterY - 1.0).abs(); // Main diagonal
    final diagonalScore2 =
        1.0 - (cropCenterX - cropCenterY).abs(); // Anti-diagonal

    return math.max(diagonalScore1, diagonalScore2) * 0.5; // Moderate influence
  }

  /// Scores overall balance and edge avoidance
  double _scoreBalance(CropCoordinates crop) {
    double score = 1.0;

    // Penalize crops too close to edges
    if (crop.x < 0.05) score -= 0.2;
    if (crop.y < 0.05) score -= 0.2;
    if (crop.x + crop.width > 0.95) score -= 0.2;
    if (crop.y + crop.height > 0.95) score -= 0.2;

    // Prefer crops with some offset from center
    final centerX = crop.x + crop.width / 2;
    final centerY = crop.y + crop.height / 2;
    final distanceFromCenter =
        math.sqrt(math.pow(centerX - 0.5, 2) + math.pow(centerY - 0.5, 2));

    // Ideal distance is slightly off-center
    final idealDistance = 0.1;
    final centerScore = 1.0 - (distanceFromCenter - idealDistance).abs() * 3;
    score += math.max(0.0, centerScore) * 0.3;

    return math.max(0.0, score);
  }

  /// Calculates detailed composition metrics
  Future<Map<String, double>> _calculateCompositionMetrics(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) async {
    return {
      'rule_of_thirds_score': _scoreRuleOfThirds(crop),
      'golden_ratio_score': _scoreGoldenRatio(crop),
      'visual_weight_score': _scoreVisualWeight(crop, imageSize, imageData),
      'dynamic_symmetry_score': _scoreDynamicSymmetry(crop),
      'balance_score': _scoreBalance(crop),
      'composition_score': await _scoreComposition(crop, imageSize, imageData),
      'crop_area_ratio': crop.width * crop.height,
      'center_offset': math.sqrt(math.pow((crop.x + crop.width / 2) - 0.5, 2) +
          math.pow((crop.y + crop.height / 2) - 0.5, 2)),
    };
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
      confidence: 0.4,
      strategy: strategyName,
    );
  }
}
