import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
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
    
    // Offload the heavy entropy calculation loops to a worker isolate
    final result = await compute(_performEntropyAnalysisIsolate, {
      'imageSize': imageSize,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
    });
    
    bestCrop = result['bestCrop'] as CropCoordinates?;
    bestScore = result['bestScore'] as double;
    bestMetrics = Map<String, double>.from(result['bestMetrics'] as Map);
    
    // Fallback to center crop if no good candidates
    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    
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

  /// Helper for center crop (must be available on main thread)
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
      confidence: 0.4,
      strategy: strategyName,
    );
  }
}

/// --- Top-level functions for Isolate support ---

/// Performs the heavy entropy analysis loop in an isolate
Map<String, dynamic> _performEntropyAnalysisIsolate(Map<String, dynamic> params) {
  final ui.Size imageSize = params['imageSize'];
  final double targetAspectRatio = params['targetAspectRatio'];
  final Uint8List imageData = params['imageData'];
  final String strategyName = params['strategyName'];

  CropCoordinates? bestCrop;
  double bestScore = 0.0;
  Map<String, double> bestMetrics = {};

  final analyzer = _EntropyAnalyzerCore(strategyName);
  
  // Generate candidates
  final candidates = analyzer.generateEntropyCandidates(imageSize, targetAspectRatio, imageData);
  
  for (final candidate in candidates) {
    final score = analyzer.scoreEntropy(candidate, imageSize, imageData);
    final metrics = analyzer.calculateMetricsSync(candidate, imageSize, imageData);
    
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

/// Core logic extracted for synchronous execution in isolates
class _EntropyAnalyzerCore {
  final String strategyName;
  _EntropyAnalyzerCore(this.strategyName);

  List<CropCoordinates> generateEntropyCandidates(
    ui.Size imageSize, 
    double targetAspectRatio,
    Uint8List imageData
  ) {
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
    
    final gridSize = 8;
    final stepX = 1.0 / gridSize;
    final stepY = 1.0 / gridSize;
    
    for (int i = 0; i < gridSize; i++) {
      for (int j = 0; j < gridSize; j++) {
        final centerX = (i + 0.5) * stepX;
        final centerY = (j + 0.5) * stepY;
        final entropy = calculateLocalEntropy(centerX, centerY, imageSize, imageData, 0.1);
        
        if (entropy > 0.3) {
          final cropX = math.max(0.0, math.min(1.0 - cropWidth, centerX - cropWidth / 2));
          final cropY = math.max(0.0, math.min(1.0 - cropHeight, centerY - cropHeight / 2));
          
          candidates.add(CropCoordinates(
            x: cropX,
            y: cropY,
            width: cropWidth,
            height: cropHeight,
            confidence: entropy,
            strategy: strategyName,
          ));
        }
      }
    }
    
    if (candidates.length < 5) {
      candidates.addAll(generateFallbackCandidates(cropWidth, cropHeight));
    }
    
    candidates.sort((a, b) => b.confidence.compareTo(a.confidence));
    return candidates.take(12).toList();
  }

  List<CropCoordinates> generateFallbackCandidates(double cropWidth, double cropHeight) {
    final fallbacks = <CropCoordinates>[];
    final positions = [
      const ui.Offset(0.5, 0.5),
      const ui.Offset(1/3, 1/3),
      const ui.Offset(2/3, 1/3),
      const ui.Offset(1/3, 2/3),
      const ui.Offset(2/3, 2/3),
    ];
    
    for (final position in positions) {
      final cropX = math.max(0.0, math.min(1.0 - cropWidth, position.dx - cropWidth / 2));
      final cropY = math.max(0.0, math.min(1.0 - cropHeight, position.dy - cropHeight / 2));
      
      fallbacks.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.3,
        strategy: strategyName,
      ));
    }
    return fallbacks;
  }

  double calculateLocalEntropy(double centerX, double centerY, ui.Size imageSize, Uint8List imageData, double radius) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final pixelX = (centerX * width).round();
    final pixelY = (centerY * height).round();
    final pixelRadius = (radius * math.min(width, height)).round();
    
    final samples = <int>[];
    final startX = math.max(0, pixelX - pixelRadius);
    final endX = math.min(width - 1, pixelX + pixelRadius);
    final startY = math.max(0, pixelY - pixelRadius);
    final endY = math.min(height - 1, pixelY + pixelRadius);
    
    for (int y = startY; y <= endY; y++) {
      for (int x = startX; x <= endX; x++) {
        final dx = x - pixelX;
        final dy = y - pixelY;
        if (dx * dx + dy * dy <= pixelRadius * pixelRadius) {
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
    return calculateShannonEntropy(samples);
  }

  double calculateShannonEntropy(List<int> values) {
    if (values.isEmpty) return 0.0;
    final frequencies = <int, int>{};
    for (final value in values) {
      frequencies[value] = (frequencies[value] ?? 0) + 1;
    }
    double entropy = 0.0;
    final total = values.length;
    for (final count in frequencies.values) {
      final probability = count / total;
      if (probability > 0) {
        entropy -= probability * math.log(probability) / math.ln2;
      }
    }
    return math.min(1.0, entropy / 8.0);
  }

  double scoreEntropy(CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    double score = 0.0;
    score += scoreAverageEntropy(crop, imageSize, imageData) * 0.6;
    score += scoreEntropyVariance(crop, imageSize, imageData) * 0.25;
    score += scoreContentDensity(crop, imageSize, imageData) * 0.15;
    return math.min(1.0, score);
  }

  double scoreAverageEntropy(CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final sampleCount = 4; // Use 4x4 for performance
    double totalEntropy = 0.0;
    int validSamples = 0;
    for (int i = 0; i < sampleCount; i++) {
      for (int j = 0; j < sampleCount; j++) {
        final relativeX = (i + 0.5) / sampleCount;
        final relativeY = (j + 0.5) / sampleCount;
        final absoluteX = crop.x + relativeX * crop.width;
        final absoluteY = crop.y + relativeY * crop.height;
        final entropy = calculateLocalEntropy(absoluteX, absoluteY, imageSize, imageData, 0.02);
        totalEntropy += entropy;
        validSamples++;
      }
    }
    return validSamples > 0 ? totalEntropy / validSamples : 0.0;
  }

  double scoreEntropyVariance(CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final sampleCount = 3; // 3x3
    final entropies = <double>[];
    for (int i = 0; i < sampleCount; i++) {
      for (int j = 0; j < sampleCount; j++) {
        final relativeX = (i + 0.5) / sampleCount;
        final relativeY = (j + 0.5) / sampleCount;
        final absoluteX = crop.x + relativeX * crop.width;
        final absoluteY = crop.y + relativeY * crop.height;
        final entropy = calculateLocalEntropy(absoluteX, absoluteY, imageSize, imageData, 0.03);
        entropies.add(entropy);
      }
    }
    if (entropies.isEmpty) return 0.0;
    final mean = entropies.reduce((a, b) => a + b) / entropies.length;
    final variance = entropies.map((e) => math.pow(e - mean, 2)).reduce((a, b) => a + b) / entropies.length;
    return math.min(1.0, variance * 4);
  }

  double scoreContentDensity(CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
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
            final gray = (0.299 * imageData[pixelIndex] + 0.587 * imageData[pixelIndex + 1] + 0.114 * imageData[pixelIndex + 2]).round();
            samples.add(gray);
          }
        }
      }
    }
    if (samples.isEmpty) return 0.0;
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) / samples.length;
    return math.min(1.0, math.sqrt(variance) / 128.0);
  }

  Map<String, double> calculateMetricsSync(CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    return {
      'average_entropy': scoreAverageEntropy(crop, imageSize, imageData),
      'entropy_variance': scoreEntropyVariance(crop, imageSize, imageData),
      'content_density': scoreContentDensity(crop, imageSize, imageData),
      'crop_area_ratio': crop.width * crop.height,
      'center_distance': math.sqrt(
        math.pow((crop.x + crop.width / 2) - 0.5, 2) + 
        math.pow((crop.y + crop.height / 2) - 0.5, 2)
      ),
    };
  }
}