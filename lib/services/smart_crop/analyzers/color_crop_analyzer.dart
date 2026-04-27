import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../interfaces/analyzer_metadata.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Color-based crop analyzer for smart cropping
///
/// This analyzer evaluates crop areas based on color characteristics:
/// - Color distribution and harmony
/// - Vibrant area identification
/// - Color contrast analysis
/// - Dominant color preservation
/// - Color temperature balance
class ColorCropAnalyzer extends BaseCropAnalyzer {
  static const String _analyzerName = 'color_analysis';
  static const int _analyzerPriority = 700; // Medium-high priority for color
  static const double _analyzerWeight = 0.75; // High weight for color

  ColorCropAnalyzer()
      : super(
          name: _analyzerName,
          priority: _analyzerPriority,
          weight: _analyzerWeight,
          maxProcessingTime: const Duration(milliseconds: 400),
          metadata: const AnalyzerMetadata(
            description:
                'Analyzes color distribution, harmony, and vibrant areas for optimal cropping',
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
              'vibrancyThreshold': 0.4,
              'contrastThreshold': 0.3,
              'harmonyWeight': 0.3,
              'vibrancyWeight': 0.4,
              'distributionWeight': 0.3,
            },
            performanceMetrics: {
              'baseProcessingTimeMs': 80,
              'pixelFactor': 0.00006,
            },
          ),
        );

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    try {
      // Get image data for color analysis
      final imageData = await _getImageData(image);

      // Analyze color characteristics of the entire image
      final colorAnalysis = _analyzeImageColors(imageSize, imageData);

      // Generate crop candidates based on color distribution
      final candidates = _generateColorBasedCandidates(
          imageSize, targetAspectRatio, colorAnalysis);

      CropCoordinates? bestCrop;
      double bestScore = 0.0;
      Map<String, double> bestMetrics = {};

      // Score each candidate based on color characteristics
      for (final candidate in candidates) {
        final score =
            _scoreColorCrop(candidate, imageSize, imageData, colorAnalysis);
        final metrics = _calculateColorMetrics(
            candidate, imageSize, imageData, colorAnalysis);

        if (score > bestScore) {
          bestScore = score;
          bestCrop = candidate;
          bestMetrics = metrics;
        }
      }

      // Fallback to center crop if no good candidates
      bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
      bestMetrics =
          _calculateColorMetrics(bestCrop, imageSize, imageData, colorAnalysis);

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
          'color_score': 0.3,
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

  /// Analyzes color characteristics of the entire image
  ImageColorAnalysis _analyzeImageColors(
      ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    final colorCounts = <int, int>{};
    final vibrantRegions = <VibrantRegion>[];
    double totalSaturation = 0.0;
    double totalBrightness = 0.0;
    int pixelCount = 0;

    // Sample pixels for color analysis
    for (int y = 0; y < height; y += 4) {
      for (int x = 0; x < width; x += 4) {
        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        // Quantize color for counting
        final quantizedColor = _quantizeColor(r, g, b);
        colorCounts[quantizedColor] = (colorCounts[quantizedColor] ?? 0) + 1;

        // Calculate color properties
        final hsv = _rgbToHsv(r, g, b);
        totalSaturation += hsv.saturation;
        totalBrightness += hsv.value;
        pixelCount++;

        // Check for vibrant colors
        if (hsv.saturation > 0.5 && hsv.value > 0.4) {
          vibrantRegions.add(VibrantRegion(
            center: ui.Offset(x / width, y / height),
            color: ui.Color.fromARGB(255, r, g, b),
            saturation: hsv.saturation,
            brightness: hsv.value,
          ));
        }
      }
    }

    // Find dominant colors
    final sortedColors = colorCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final dominantColors = sortedColors
        .take(5)
        .map((entry) => _unquantizeColor(entry.key))
        .toList();

    return ImageColorAnalysis(
      dominantColors: dominantColors,
      vibrantRegions: vibrantRegions,
      averageSaturation: pixelCount > 0 ? totalSaturation / pixelCount : 0.0,
      averageBrightness: pixelCount > 0 ? totalBrightness / pixelCount : 0.0,
      colorVariety: colorCounts.length /
          math.max(1, pixelCount ~/ 100), // Normalized variety
    );
  }

  /// Generates crop candidates based on color distribution
  List<CropCoordinates> _generateColorBasedCandidates(ui.Size imageSize,
      double targetAspectRatio, ImageColorAnalysis colorAnalysis) {
    final candidates = <CropCoordinates>[];
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Generate candidates based on vibrant regions
    for (final vibrantRegion in colorAnalysis.vibrantRegions.take(5)) {
      final cropX = math.max(0.0,
          math.min(1.0 - cropWidth, vibrantRegion.center.dx - cropWidth / 2));
      final cropY = math.max(0.0,
          math.min(1.0 - cropHeight, vibrantRegion.center.dy - cropHeight / 2));

      candidates.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: vibrantRegion.saturation * vibrantRegion.brightness,
        strategy: '${strategyName}_vibrant',
      ));
    }

    // Generate candidates based on color harmony points
    candidates.addAll(_generateHarmonyCandidates(cropWidth, cropHeight));

    // Add center crop as fallback
    candidates.add(_getCenterCrop(imageSize, targetAspectRatio));

    return candidates;
  }

  /// Generates candidates based on color harmony principles
  List<CropCoordinates> _generateHarmonyCandidates(
      double cropWidth, double cropHeight) {
    final candidates = <CropCoordinates>[];

    // Golden ratio points often create good color balance
    final harmonyPoints = [
      const ui.Offset(0.618, 0.382), // Golden ratio point
      const ui.Offset(0.382, 0.618), // Inverse golden ratio
      const ui.Offset(0.3, 0.3), // Upper left third
      const ui.Offset(0.7, 0.7), // Lower right third
    ];

    for (final point in harmonyPoints) {
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
        strategy: '${strategyName}_harmony',
      ));
    }

    return candidates;
  }

  /// Scores a crop based on color characteristics
  double _scoreColorCrop(CropCoordinates crop, ui.Size imageSize,
      Uint8List imageData, ImageColorAnalysis colorAnalysis) {
    double score = 0.0;

    // Color vibrancy score (40%)
    score += _scoreColorVibrancy(crop, imageSize, imageData) * 0.4;

    // Color harmony score (30%)
    score +=
        _scoreColorHarmony(crop, imageSize, imageData, colorAnalysis) * 0.3;

    // Color distribution score (20%)
    score += _scoreColorDistribution(crop, imageSize, imageData) * 0.2;

    // Color contrast score (10%)
    score += _scoreColorContrast(crop, imageSize, imageData) * 0.1;

    return math.min(1.0, score);
  }

  /// Scores color vibrancy within the crop area
  double _scoreColorVibrancy(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    final cropLeft = (crop.x * width).round();
    final cropTop = (crop.y * height).round();
    final cropRight = ((crop.x + crop.width) * width).round();
    final cropBottom = ((crop.y + crop.height) * height).round();

    double totalVibrancy = 0.0;
    int pixelCount = 0;

    // Sample pixels within crop area
    for (int y = cropTop; y < cropBottom; y += 3) {
      for (int x = cropLeft; x < cropRight; x += 3) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        final hsv = _rgbToHsv(r, g, b);
        final vibrancy =
            hsv.saturation * hsv.value; // Vibrancy = saturation * brightness
        totalVibrancy += vibrancy;
        pixelCount++;
      }
    }

    return pixelCount > 0 ? totalVibrancy / pixelCount : 0.0;
  }

  /// Scores color harmony within the crop area
  double _scoreColorHarmony(CropCoordinates crop, ui.Size imageSize,
      Uint8List imageData, ImageColorAnalysis colorAnalysis) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    final cropLeft = (crop.x * width).round();
    final cropTop = (crop.y * height).round();
    final cropRight = ((crop.x + crop.width) * width).round();
    final cropBottom = ((crop.y + crop.height) * height).round();

    final cropColors = <HSV>[];

    // Sample colors within crop area
    for (int y = cropTop; y < cropBottom; y += 5) {
      for (int x = cropLeft; x < cropRight; x += 5) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        cropColors.add(_rgbToHsv(r, g, b));
      }
    }

    if (cropColors.isEmpty) return 0.0;

    // Calculate color harmony based on hue relationships
    double harmonyScore = 0.0;
    int comparisons = 0;

    for (int i = 0; i < cropColors.length; i += 10) {
      // Sample every 10th color for performance
      for (int j = i + 10; j < cropColors.length; j += 10) {
        final hue1 = cropColors[i].hue;
        final hue2 = cropColors[j].hue;

        // Calculate hue difference (0-180 degrees)
        final hueDiff =
            math.min((hue1 - hue2).abs(), 360 - (hue1 - hue2).abs());

        // Score based on harmonic relationships
        if (hueDiff < 30) {
          harmonyScore += 1.0; // Analogous colors (very harmonious)
        } else if (hueDiff > 150 && hueDiff < 210) {
          harmonyScore += 0.8; // Complementary colors (harmonious)
        } else if (hueDiff > 110 && hueDiff < 130) {
          harmonyScore += 0.6; // Triadic colors (moderately harmonious)
        } else {
          harmonyScore += 0.2; // Other relationships
        }

        comparisons++;
        if (comparisons > 50) break; // Limit comparisons for performance
      }
      if (comparisons > 50) break;
    }

    return comparisons > 0 ? harmonyScore / comparisons : 0.5;
  }

  /// Scores color distribution within the crop area
  double _scoreColorDistribution(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    final cropLeft = (crop.x * width).round();
    final cropTop = (crop.y * height).round();
    final cropRight = ((crop.x + crop.width) * width).round();
    final cropBottom = ((crop.y + crop.height) * height).round();

    final colorCounts = <int, int>{};
    int totalPixels = 0;

    // Count colors within crop area
    for (int y = cropTop; y < cropBottom; y += 4) {
      for (int x = cropLeft; x < cropRight; x += 4) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        final quantizedColor = _quantizeColor(r, g, b);
        colorCounts[quantizedColor] = (colorCounts[quantizedColor] ?? 0) + 1;
        totalPixels++;
      }
    }

    if (colorCounts.isEmpty) return 0.0;

    // Calculate color distribution entropy (higher = more diverse)
    double entropy = 0.0;
    for (final count in colorCounts.values) {
      final probability = count / totalPixels;
      if (probability > 0) {
        entropy -= probability * math.log(probability) / math.ln2;
      }
    }

    // Normalize entropy (prefer moderate diversity, not too uniform or too chaotic)
    final maxEntropy = math.log(colorCounts.length) / math.ln2;
    final normalizedEntropy = maxEntropy > 0 ? entropy / maxEntropy : 0.0;

    // Prefer moderate diversity (around 0.7)
    final idealEntropy = 0.7;
    return 1.0 - (normalizedEntropy - idealEntropy).abs();
  }

  /// Scores color contrast within the crop area
  double _scoreColorContrast(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    final cropLeft = (crop.x * width).round();
    final cropTop = (crop.y * height).round();
    final cropRight = ((crop.x + crop.width) * width).round();
    final cropBottom = ((crop.y + crop.height) * height).round();

    final brightnesses = <double>[];

    // Sample brightness values within crop area
    for (int y = cropTop; y < cropBottom; y += 5) {
      for (int x = cropLeft; x < cropRight; x += 5) {
        if (x >= width || y >= height) continue;

        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 >= imageData.length) continue;

        final r = imageData[pixelIndex];
        final g = imageData[pixelIndex + 1];
        final b = imageData[pixelIndex + 2];

        final brightness = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0;
        brightnesses.add(brightness);
      }
    }

    if (brightnesses.length < 4) return 0.0;

    brightnesses.sort();
    final q1 = brightnesses[brightnesses.length ~/ 4];
    final q3 = brightnesses[(brightnesses.length * 3) ~/ 4];

    return math.min(1.0, (q3 - q1) * 2); // Scale contrast to 0-1 range
  }

  /// Calculates detailed color metrics
  Map<String, double> _calculateColorMetrics(
      CropCoordinates crop,
      ui.Size imageSize,
      Uint8List imageData,
      ImageColorAnalysis colorAnalysis) {
    return {
      'color_vibrancy_score': _scoreColorVibrancy(crop, imageSize, imageData),
      'color_harmony_score':
          _scoreColorHarmony(crop, imageSize, imageData, colorAnalysis),
      'color_distribution_score':
          _scoreColorDistribution(crop, imageSize, imageData),
      'color_contrast_score': _scoreColorContrast(crop, imageSize, imageData),
      'color_score': _scoreColorCrop(crop, imageSize, imageData, colorAnalysis),
      'crop_area_ratio': crop.width * crop.height,
      'average_saturation': colorAnalysis.averageSaturation,
      'average_brightness': colorAnalysis.averageBrightness,
      'color_variety': colorAnalysis.colorVariety,
      'vibrant_regions_count': colorAnalysis.vibrantRegions.length.toDouble(),
    };
  }

  /// Quantizes RGB color to reduce color space
  int _quantizeColor(int r, int g, int b) {
    final qR = (r ~/ 32) * 32;
    final qG = (g ~/ 32) * 32;
    final qB = (b ~/ 32) * 32;
    return (qR << 16) | (qG << 8) | qB;
  }

  /// Unquantizes color back to RGB
  ui.Color _unquantizeColor(int quantized) {
    final r = (quantized >> 16) & 0xFF;
    final g = (quantized >> 8) & 0xFF;
    final b = quantized & 0xFF;
    return ui.Color.fromARGB(255, r, g, b);
  }

  /// Converts RGB to HSV color space
  HSV _rgbToHsv(int r, int g, int b) {
    final rNorm = r / 255.0;
    final gNorm = g / 255.0;
    final bNorm = b / 255.0;

    final max = math.max(rNorm, math.max(gNorm, bNorm));
    final min = math.min(rNorm, math.min(gNorm, bNorm));
    final delta = max - min;

    double hue = 0.0;
    if (delta != 0) {
      if (max == rNorm) {
        hue = 60 * (((gNorm - bNorm) / delta) % 6);
      } else if (max == gNorm) {
        hue = 60 * (((bNorm - rNorm) / delta) + 2);
      } else {
        hue = 60 * (((rNorm - gNorm) / delta) + 4);
      }
    }

    final saturation = max == 0 ? 0.0 : delta / max;
    final value = max;

    return HSV(hue: hue, saturation: saturation, value: value);
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

/// Represents the color analysis of an entire image
class ImageColorAnalysis {
  final List<ui.Color> dominantColors;
  final List<VibrantRegion> vibrantRegions;
  final double averageSaturation;
  final double averageBrightness;
  final double colorVariety;

  ImageColorAnalysis({
    required this.dominantColors,
    required this.vibrantRegions,
    required this.averageSaturation,
    required this.averageBrightness,
    required this.colorVariety,
  });
}

/// Represents a vibrant color region in the image
class VibrantRegion {
  final ui.Offset center;
  final ui.Color color;
  final double saturation;
  final double brightness;

  VibrantRegion({
    required this.center,
    required this.color,
    required this.saturation,
    required this.brightness,
  });
}

/// HSV color representation
class HSV {
  final double hue; // 0-360 degrees
  final double saturation; // 0-1
  final double value; // 0-1 (brightness)

  HSV({
    required this.hue,
    required this.saturation,
    required this.value,
  });
}
