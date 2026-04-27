import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Crop analyzer that uses image entropy to detect content density
/// 
/// This analyzer calculates the information content (entropy) of different
/// image regions and prefers crops that contain areas with high visual
/// complexity and information density.
class EntropyBasedCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'entropy_based';

  @override
  double get weight => 0.7; // High weight for content-aware cropping

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.15;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    
    // Calculate the target aspect ratio
    final targetAspectRatio = targetSize.width / targetSize.height;
    
    CropCoordinates? bestCrop;
    double bestScore = 0.0;
    Map<String, double> bestMetrics = {};
    
    // Get image data for entropy calculation
    final imageData = await _getImageData(image);
    
    // Generate crop candidates based on entropy analysis
    final candidates = _generateEntropyCandidates(imageSize, targetAspectRatio, imageData);
    
    for (final candidate in candidates) {
      final score = await _scoreEntropy(candidate, imageSize, imageData);
      final metrics = await _calculateMetrics(candidate, imageSize, imageData);
      
      if (score > bestScore) {
        bestScore = score;
        bestCrop = candidate;
        bestMetrics = metrics;
      }
    }
    
    // Fallback to center crop if no good candidates
    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    bestMetrics = await _calculateMetrics(bestCrop, imageSize, imageData);
    
    return CropScore(
      coordinates: bestCrop,
      score: bestScore,
      strategy: strategyName,
      metrics: bestMetrics,
    );
  }

  /// Gets image pixel data for entropy calculations
  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Generates crop candidates based on entropy hotspots
  List<CropCoordinates> _generateEntropyCandidates(
    ui.Size imageSize, 
    double targetAspectRatio,
    Uint8List imageData
  ) {
    final candidates = <CropCoordinates>[];
    
    // Calculate crop dimensions
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);
    
    // Create a grid for entropy sampling
    final gridSize = 8; // 8x8 grid for performance
    final stepX = 1.0 / gridSize;
    final stepY = 1.0 / gridSize;
    
    // Sample entropy at grid points and generate crops around high-entropy areas
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final centerX = (i + 0.5) * stepX;
        final centerY = (j + 0.5) * stepY;
        
        // Calculate entropy at this point
        final entropy = _calculateLocalEntropy(
          centerX, centerY, imageSize, imageData, 0.1 // 10% sample radius
        );
        
        // Only generate crops for areas with reasonable entropy
        if (entropy > 0.3) {
          final cropX = math.max(0.0, math.min(1.0 - cropWidth, centerX - cropWidth / 2));
          final cropY = math.max(0.0, math.min(1.0 - cropHeight, centerY - cropHeight / 2));
          
          candidates.add(CropCoordinates(
            x: cropX,
            y: cropY,
            width: cropWidth,
            height: cropHeight,
            confidence: entropy, // Use entropy as initial confidence
            strategy: strategyName,
          ));
        }
      }
    }
    
    // Add some strategic positions if we don't have enough candidates
    if (candidates.length < 5) {
      candidates.addAll(_generateFallbackCandidates(cropWidth, cropHeight));
    }
    
    // Sort by initial confidence (entropy) and take top candidates
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.take(12).toList(); // Limit to top 12 for performance
  }

  /// Generates fallback candidates when entropy analysis doesn't find enough areas
  List<CropCoordinates> _generateFallbackCandidates(double cropWidth, double cropHeight) {
    final fallbacks = <CropCoordinates>[];
    
    // Standard positions: center, rule of thirds intersections
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
        confidence: 0.3, // Lower confidence for fallbacks
        strategy: strategyName,
      ));
    }
    
    return fallbacks;
  }

  /// Calculates local entropy around a point
  double _calculateLocalEntropy(
    double centerX, 
    double centerY, 
    ui.Size imageSize, 
    Uint8List imageData,
    double radius
  ) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    
    // Convert normalized coordinates to pixel coordinates
    final pixelX = (centerX * width).round();
    final pixelY = (centerY * height).round();
    final pixelRadius = (radius * math.min(width, height)).round();
    
    // Sample pixels in the radius
    final samples = <int>[];
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
          final pixelIndex = (y * width + x) * 4; // RGBA format
          if (pixelIndex + 2 < imageData.length) {
            // Convert RGB to grayscale for entropy calculation
            final r = imageData[pixelIndex];
            final g = imageData[pixelIndex + 1];
            final b = imageData[pixelIndex + 2];
            final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
            samples.add(gray);
          }
        }
      }
    }
    
    return _calculateEntropy(samples);
  }

  /// Calculates Shannon entropy for a list of values
  double _calculateEntropy(List<int> values) {
    if (values.isEmpty) return 0.0;
    
    // Count frequency of each value
    final frequencies = <int, int>{};
    for (final value in values) {
      frequencies[value] = (frequencies[value] ?? 0) + 1;
    }
    
    // Calculate entropy
    double entropy = 0.0;
    final total = values.length;
    
    for (final count in frequencies.values) {
      final probability = count / total;
      if (probability > 0) {
        entropy -= probability * math.log(probability) / math.ln2;
      }
    }
    
    // Normalize to 0-1 range (max entropy for 8-bit grayscale is log2(256) = 8)
    return math.min(1.0, entropy / 8.0);
  }

  /// Scores a crop based on entropy content
  Future<double> _scoreEntropy(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List imageData
  ) async {
    double score = 0.0;
    
    // Average entropy within crop area (60% of score)
    score += _scoreAverageEntropy(crop, imageSize, imageData) * 0.6;
    
    // Entropy variance (prefer areas with varied content) (25% of score)
    score += _scoreEntropyVariance(crop, imageSize, imageData) * 0.25;
    
    // Content density (avoid mostly empty areas) (15% of score)
    score += _scoreContentDensity(crop, imageSize, imageData) * 0.15;
    
    return math.min(1.0, score);
  }

  /// Scores the average entropy within the crop area
  double _scoreAverageEntropy(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List imageData
  ) {
    final sampleCount = 16; // 4x4 grid within crop
    double totalEntropy = 0.0;
    int validSamples = 0;
    
    for (int i = 0; i < sampleCount; i++) {
      for (int j = 0; j < sampleCount; j++) {
        final relativeX = (i + 0.5) / sampleCount;
        final relativeY = (j + 0.5) / sampleCount;
        
        final absoluteX = crop.x + relativeX * crop.width;
        final absoluteY = crop.y + relativeY * crop.height;
        
        final entropy = _calculateLocalEntropy(
          absoluteX, absoluteY, imageSize, imageData, 0.02 // 2% sample radius
        );
        
        totalEntropy += entropy;
        validSamples++;
      }
    }
    
    return validSamples > 0 ? totalEntropy / validSamples : 0.0;
  }

  /// Scores entropy variance within the crop (higher variance = more interesting)
  double _scoreEntropyVariance(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List imageData
  ) {
    final sampleCount = 9; // 3x3 grid for variance calculation
    final entropies = <double>[];
    
    for (int i = 0; i < sampleCount; i++) {
      for (int j = 0; j < sampleCount; j++) {
        final relativeX = (i + 0.5) / sampleCount;
        final relativeY = (j + 0.5) / sampleCount;
        
        final absoluteX = crop.x + relativeX * crop.width;
        final absoluteY = crop.y + relativeY * crop.height;
        
        final entropy = _calculateLocalEntropy(
          absoluteX, absoluteY, imageSize, imageData, 0.03 // 3% sample radius
        );
        
        entropies.add(entropy);
      }
    }
    
    if (entropies.isEmpty) return 0.0;
    
    // Calculate variance
    final mean = entropies.reduce((a, b) => a + b) / entropies.length;
    final variance = entropies
        .map((e) => math.pow(e - mean, 2))
        .reduce((a, b) => a + b) / entropies.length;
    
    // Normalize variance to 0-1 range
    return math.min(1.0, variance * 4); // Scale factor for reasonable range
  }

  /// Scores content density (avoid areas that are mostly uniform)
  double _scoreContentDensity(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List imageData
  ) {
    // Sample a few points and check for significant variation
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    
    final cropPixelX = (crop.x * width).round();
    final cropPixelY = (crop.y * height).round();
    final cropPixelWidth = (crop.width * width).round();
    final cropPixelHeight = (crop.height * height).round();
    
    final samples = <int>[];
    final sampleStep = math.max(1, math.min(cropPixelWidth, cropPixelHeight) ~/ 8);
    
    for (int y = cropPixelY; y < cropPixelY + cropPixelHeight; y += sampleStep) {
      for (int x = cropPixelX; x < cropPixelX + cropPixelWidth; x += sampleStep) {
        if (x < width && y < height) {
          final pixelIndex = (y * width + x) * 4;
          if (pixelIndex + 2 < imageData.length) {
            final r = imageData[pixelIndex];
            final g = imageData[pixelIndex + 1];
            final b = imageData[pixelIndex + 2];
            final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
            samples.add(gray);
          }
        }
      }
    }
    
    if (samples.isEmpty) return 0.0;
    
    // Calculate standard deviation as a measure of content density
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples
        .map((s) => math.pow(s - mean, 2))
        .reduce((a, b) => a + b) / samples.length;
    final stdDev = math.sqrt(variance);
    
    // Normalize to 0-1 range (max std dev for 8-bit is ~128)
    return math.min(1.0, stdDev / 128.0);
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
      confidence: 0.4, // Moderate confidence for fallback
      strategy: strategyName,
    );
  }

  /// Calculates detailed metrics for the crop
  Future<Map<String, double>> _calculateMetrics(
    CropCoordinates crop, 
    ui.Size imageSize, 
    Uint8List imageData
  ) async {
    return {
      'average_entropy': _scoreAverageEntropy(crop, imageSize, imageData),
      'entropy_variance': _scoreEntropyVariance(crop, imageSize, imageData),
      'content_density': _scoreContentDensity(crop, imageSize, imageData),
      'crop_area_ratio': crop.width * crop.height,
      'center_distance': math.sqrt(
        math.pow((crop.x + crop.width / 2) - 0.5, 2) + 
        math.pow((crop.y + crop.height / 2) - 0.5, 2)
      ),
    };
  }
}