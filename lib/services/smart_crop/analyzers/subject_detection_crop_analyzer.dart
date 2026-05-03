import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Analyseur avancé de détection de sujets pour un cropping précis
///
/// Cet analyseur utilise des techniques avancées pour détecter les sujets
/// importants (animaux, personnes, objets) et détermine la meilleure stratégie :
/// - Crop serré sur le sujet principal (ex: tête d'oiseau)
/// - Crop incluant le sujet complet avec contexte
/// - Scale adaptatif selon la taille du sujet
class SubjectDetectionCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'subject_detection';

  @override
  double get weight => 0.75; // Reduced weight to allow specialized ML to win

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.3;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    // Obtenir les données de l'image
    final imageData = await _getImageData(image);

    // Offload heavy subject detection and scoring to worker isolate
    final result = await compute(_performSubjectAnalysisIsolate, {
      'imageSize': imageSize,
      'targetAspectRatio': targetAspectRatio,
      'imageData': imageData,
      'strategyName': strategyName,
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

  /// Obtient les données de pixels de l'image
  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Fallback centré (Main thread)
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

Map<String, dynamic> _performSubjectAnalysisIsolate(Map<String, dynamic> params) {
  final ui.Size imageSize = params['imageSize'];
  final double targetAspectRatio = params['targetAspectRatio'];
  final Uint8List imageData = params['imageData'];
  final String strategyName = params['strategyName'];

  final core = _SubjectAnalyzerCore(strategyName);
  
  // 1. Detect subjects
  final subjects = core.detectSubjects(imageSize, imageData);

  if (subjects.isEmpty) {
    return {
      'bestCrop': null,
      'bestScore': 0.1,
      'bestMetrics': {'subjects_detected': 0.0},
    };
  }

  // 2. Score crops
  CropCoordinates? bestCrop;
  double bestScore = 0.0;
  Map<String, double> bestMetrics = {};

  double maxImportance = subjects.map((s) => s.importance).reduce(math.max);

  for (final subject in subjects) {
    final strategies = core.generateCropStrategies(subject, imageSize, targetAspectRatio);
    for (final strategy in strategies) {
      final score = core.scoreSubjectCrop(strategy, subject, imageSize, imageData, maxImportance, targetAspectRatio);
      final metrics = core.calculateMetricsSync(strategy, subject, imageSize, imageData);

      if (score > bestScore) {
        bestScore = score;
        bestCrop = strategy;
        bestMetrics = metrics;
      }
    }
  }

  if (subjects.isNotEmpty) {
    bestMetrics['subject_target_x'] = subjects.first.center.dx;
    bestMetrics['subject_target_y'] = subjects.first.center.dy;
  }

  return {
    'bestCrop': bestCrop,
    'bestScore': bestScore,
    'bestMetrics': bestMetrics,
  };
}

class _SubjectAnalyzerCore {
  final String strategyName;
  _SubjectAnalyzerCore(this.strategyName);

  List<DetectedSubject> detectSubjects(ui.Size imageSize, Uint8List imageData) {
    final subjects = <DetectedSubject>[];
    subjects.addAll(detectByContrast(imageSize, imageData));
    subjects.addAll(detectByColorAnalysis(imageSize, imageData));
    subjects.addAll(detectByShape(imageSize, imageData));
    final merged = mergeNearbySubjects(subjects);
    merged.sort((a, b) => b.importance.compareTo(a.importance));
    return merged.take(5).toList();
  }

  List<DetectedSubject> detectByContrast(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final subjects = <DetectedSubject>[];
    final gridSize = 16;
    final cellWidth = width / gridSize;
    final cellHeight = height / gridSize;

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final startX = (gx * cellWidth).round();
        final endX = ((gx + 1) * cellWidth).round();
        final startY = (gy * cellHeight).round();
        final endY = ((gy + 1) * cellHeight).round();
        final contrast = calculateLocalContrast(imageData, width, startX, endX, startY, endY);
        if (contrast > 0.25) {
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          final size = math.sqrt((cellWidth * cellHeight) / (width * height));
          subjects.add(DetectedSubject(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height, (endX - startX) / width, (endY - startY) / height),
            type: SubjectType.highContrast,
            confidence: contrast,
            importance: contrast * getPositionWeight(centerX, centerY) * size,
          ));
        }
      }
    }
    return subjects;
  }

  double calculateLocalContrast(Uint8List imageData, int width, int startX, int endX, int startY, int endY) {
    final pixels = <int>[];
    for (int y = startY; y < endY; y += 2) {
      for (int x = startX; x < endX; x += 2) {
        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 < imageData.length) {
          pixels.add((0.299 * imageData[pixelIndex] + 0.587 * imageData[pixelIndex + 1] + 0.114 * imageData[pixelIndex + 2]).round());
        }
      }
    }
    if (pixels.length < 4) return 0.0;
    pixels.sort();
    return (pixels[(pixels.length * 3) ~/ 4] - pixels[pixels.length ~/ 4]) / 255.0;
  }

  List<DetectedSubject> detectByColorAnalysis(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final subjects = <DetectedSubject>[];
    final clusters = findColorClusters(imageData, width, height);
    for (final cluster in clusters) {
      if (cluster.distinctiveness > 0.3 && cluster.size > 0.01) {
        subjects.add(DetectedSubject(
          center: cluster.center,
          bounds: cluster.bounds,
          type: SubjectType.colorDistinct,
          confidence: cluster.distinctiveness,
          importance: cluster.distinctiveness * cluster.size * getPositionWeight(cluster.center.dx, cluster.center.dy),
        ));
      }
    }
    return subjects;
  }

  List<ColorCluster> findColorClusters(Uint8List imageData, int width, int height) {
    final clusters = <ColorCluster>[];
    final regionSize = 32;
    for (int ry = 0; ry < height ~/ regionSize; ry++) {
      for (int rx = 0; rx < width ~/ regionSize; rx++) {
        final startX = rx * regionSize;
        final endX = math.min((rx + 1) * regionSize, width);
        final startY = ry * regionSize;
        final endY = math.min((ry + 1) * regionSize, height);
        final domColor = getDominantColor(imageData, width, startX, endX, startY, endY);
        final distinct = calculateColorDistinctiveness(domColor, imageData, width, height);
        if (distinct > 0.2) {
          clusters.add(ColorCluster(
            center: ui.Offset((startX + endX) / 2 / width, (startY + endY) / 2 / height),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height, (endX - startX) / width, (endY - startY) / height),
            dominantColor: domColor,
            distinctiveness: distinct,
            size: (endX - startX) * (endY - startY) / (width * height),
          ));
        }
      }
    }
    return clusters;
  }

  ui.Color getDominantColor(Uint8List imageData, int width, int startX, int endX, int startY, int endY) {
    int totalR = 0, totalG = 0, totalB = 0, count = 0;
    for (int y = startY; y < endY; y += 2) {
      for (int x = startX; x < endX; x += 2) {
        final idx = (y * width + x) * 4;
        if (idx + 2 < imageData.length) {
          totalR += imageData[idx]; totalG += imageData[idx + 1]; totalB += imageData[idx + 2]; count++;
        }
      }
    }
    return count == 0 ? const ui.Color(0xFF808080) : ui.Color.fromARGB(255, totalR ~/ count, totalG ~/ count, totalB ~/ count);
  }

  double calculateColorDistinctiveness(ui.Color color, Uint8List imageData, int width, int height) {
    int similar = 0, total = 0;
    for (int y = 0; y < height; y += 8) {
      for (int x = 0; x < width; x += 8) {
        final idx = (y * width + x) * 4;
        if (idx + 2 < imageData.length) {
          final dist = math.sqrt(math.pow(imageData[idx] - (color.r * 255).round(), 2) + math.pow(imageData[idx+1] - (color.g * 255).round(), 2) + math.pow(imageData[idx+2] - (color.b * 255).round(), 2));
          if (dist < 50) similar++;
          total++;
        }
      }
    }
    return total == 0 ? 0.0 : 1.0 - (similar / total);
  }

  List<DetectedSubject> detectByShape(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt(), height = imageSize.height.toInt();
    final subjects = <DetectedSubject>[];
    for (final scale in [16, 24, 32, 48]) {
      final step = scale ~/ 2;
      for (int y = scale; y < height - scale; y += step) {
        for (int x = scale; x < width - scale; x += step) {
          final circularity = calculateCircularity(imageData, width, x, y, scale);
          if (circularity > 0.3) {
            subjects.add(DetectedSubject(
              center: ui.Offset(x / width, y / height),
              bounds: ui.Rect.fromLTWH((x - scale) / width, (y - scale) / height, (scale * 2) / width, (scale * 2) / height),
              type: SubjectType.circularShape,
              confidence: circularity,
              importance: circularity * (scale * 2 / math.min(width, height)) * getPositionWeight(x / width, y / height) * 1.2,
            ));
          }
        }
      }
    }
    return subjects;
  }

  double calculateCircularity(Uint8List imageData, int width, int centerX, int centerY, int radius) {
    final samples = <int>[], edgeSamples = <int>[];
    for (int angle = 0; angle < 360; angle += 15) {
      final rad = angle * math.pi / 180;
      final cp = getPixelBrightness(imageData, width, centerX, centerY);
      if (cp >= 0) samples.add(cp);
      final ep = getPixelBrightness(imageData, width, centerX + (radius * math.cos(rad)).round(), centerY + (radius * math.sin(rad)).round());
      if (ep >= 0) edgeSamples.add(ep);
    }
    if (samples.isEmpty || edgeSamples.isEmpty) return 0.0;
    final edgeMean = edgeSamples.reduce((a, b) => a + b) / edgeSamples.length;
    final edgeVar = edgeSamples.map((s) => math.pow(s - edgeMean, 2)).reduce((a, b) => a + b) / edgeSamples.length;
    return (samples.reduce((a, b) => a + b) / samples.length - edgeMean).abs() / 255.0 * (1.0 - math.min(1.0, edgeVar / (255 * 255)));
  }

  int getPixelBrightness(Uint8List imageData, int width, int x, int y) {
    final idx = (y * width + x) * 4;
    if (idx + 2 >= imageData.length) return -1;
    return (0.299 * imageData[idx] + 0.587 * imageData[idx+1] + 0.114 * imageData[idx+2]).round();
  }

  List<DetectedSubject> mergeNearbySubjects(List<DetectedSubject> subjects) {
    final merged = <DetectedSubject>[];
    final processed = List.filled(subjects.length, false);
    for (int i = 0; i < subjects.length; i++) {
      if (processed[i]) continue;
      final current = subjects[i];
      final nearby = [current];
      processed[i] = true;
      for (int j = i + 1; j < subjects.length; j++) {
        if (!processed[j] && math.sqrt(math.pow(current.center.dx - subjects[j].center.dx, 2) + math.pow(current.center.dy - subjects[j].center.dy, 2)) < 0.15) {
          nearby.add(subjects[j]); processed[j] = true;
        }
      }
      merged.add(createMergedSubject(nearby));
    }
    return merged;
  }

  DetectedSubject createMergedSubject(List<DetectedSubject> subjects) {
    if (subjects.length == 1) return subjects.first;
    double totalImp = 0, weightedX = 0, weightedY = 0, totalSaliency = 0;
    double minX = 1, minY = 1, maxX = 0, maxY = 0, maxConf = 0;
    SubjectType bestType = subjects.first.type;
    for (final s in subjects) {
      totalImp += s.importance;
      final w = math.pow(s.importance, 2.0);
      weightedX += s.center.dx * w; weightedY += s.center.dy * w; totalSaliency += w;
      minX = math.min(minX, s.bounds.left); minY = math.min(minY, s.bounds.top);
      maxX = math.max(maxX, s.bounds.right); maxY = math.max(maxY, s.bounds.bottom);
      if (s.confidence > maxConf) { maxConf = s.confidence; bestType = s.type; }
    }
    return DetectedSubject(center: ui.Offset(weightedX / totalSaliency, weightedY / totalSaliency), bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY), type: bestType, confidence: maxConf, importance: totalImp);
  }

  double getPositionWeight(double x, double y) => math.max(0.1, 1.0 - (math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2)) * 2.5));

  List<CropCoordinates> generateCropStrategies(DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final strategies = <CropCoordinates>[];
    strategies.add(createTightCrop(subject, imageSize, targetAspectRatio)!);
    strategies.add(createContextCrop(subject, imageSize, targetAspectRatio));
    strategies.add(createCenteredCrop(subject, imageSize, targetAspectRatio));
    return strategies;
  }

  CropCoordinates? createTightCrop(DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final bounds = subject.bounds;
    final tightW = bounds.width * 1.3, tightH = bounds.height * 1.3;
    final relRatio = targetAspectRatio / (imageSize.width / imageSize.height);
    double sw = tightW, sh = tightH;
    if (sw / sh > relRatio) sh = sw / relRatio; else sw = sh * relRatio;
    if (sw > 1.0 || sh > 1.0) { final s = math.min(1.0 / sw, 1.0 / sh); sw *= s; sh *= s; }
    return CropCoordinates(x: (subject.center.dx - sw / 2).clamp(0.0, 1.0 - sw), y: (subject.center.dy - sh / 2).clamp(0.0, 1.0 - sh), width: sw, height: sh, confidence: subject.confidence * 0.9, strategy: '${strategyName}_tight_scaled');
  }

  CropCoordinates createContextCrop(DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final sw = calculateCropWidth(imageSize, targetAspectRatio), sh = calculateCropHeight(imageSize, targetAspectRatio);
    return CropCoordinates(x: (subject.center.dx - sw / 2).clamp(0.0, 1.0 - sw), y: (subject.center.dy - sh / 2).clamp(0.0, 1.0 - sh), width: sw, height: sh, confidence: subject.confidence, strategy: '${strategyName}_context');
  }

  CropCoordinates createCenteredCrop(DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final sw = calculateCropWidth(imageSize, targetAspectRatio), sh = calculateCropHeight(imageSize, targetAspectRatio);
    return CropCoordinates(x: (subject.center.dx - sw / 2).clamp(0.0, 1.0 - sw), y: (subject.center.dy - sh / 2).clamp(0.0, 1.0 - sh), width: sw, height: sh, confidence: subject.confidence * 0.8, strategy: '${strategyName}_centered');
  }

  double scoreSubjectCrop(CropCoordinates crop, DetectedSubject subject, ui.Size imageSize, Uint8List imageData, double maxImp, double targetAspectRatio) {
    double score = 0.0;
    score += scoreSubjectInclusion(crop, subject) * 0.25;
    score += subject.confidence * (subject.type == SubjectType.circularShape ? 1.2 : (subject.type == SubjectType.highContrast ? 1.1 : 1.0)) * 0.15;
    score += scoreComposition(crop, subject) * 0.15;
    score += scoreEdgeAvoidance(crop) * 0.05;
    score += (maxImp > 0 ? subject.importance / maxImp : 1.0) * 0.20;
    final cw = calculateCropWidth(imageSize, targetAspectRatio), ch = calculateCropHeight(imageSize, targetAspectRatio);
    score += ((crop.width * crop.height) / (cw * ch)) * 0.10;
    return score;
  }

  double scoreSubjectInclusion(CropCoordinates crop, DetectedSubject subject) {
    final i = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height).intersect(subject.bounds);
    return i.isEmpty ? 0.0 : (i.width * i.height) / (subject.bounds.width * subject.bounds.height);
  }

  double scoreComposition(CropCoordinates crop, DetectedSubject subject) {
    final sx = (subject.center.dx - crop.x) / crop.width, sy = (subject.center.dy - crop.y) / crop.height;
    double bx = 1, by = 1;
    for (final p in [1/3, 2/3]) { bx = math.min(bx, (sx - p).abs()); by = math.min(by, (sy - p).abs()); }
    return (1 - bx) * (1 - by);
  }

  double scoreEdgeAvoidance(CropCoordinates crop) {
    double p = 0;
    if (crop.x <= 0.01) p += 0.2; if (crop.y <= 0.01) p += 0.2;
    if (crop.x + crop.width >= 0.99) p += 0.2; if (crop.y + crop.height >= 0.99) p += 0.2;
    return math.max(0.0, 1.0 - p);
  }

  double calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final aspect = imageSize.width / imageSize.height;
    return targetAspectRatio > aspect ? 1.0 : targetAspectRatio / aspect;
  }

  double calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final aspect = imageSize.width / imageSize.height;
    return targetAspectRatio < aspect ? 1.0 : aspect / targetAspectRatio;
  }

  Map<String, double> calculateMetricsSync(CropCoordinates crop, DetectedSubject? subject, ui.Size imageSize, Uint8List imageData) {
    return {
      'subjects_detected': subject != null ? 1.0 : 0.0,
      'subject_inclusion': subject != null ? scoreSubjectInclusion(crop, subject) : 0.0,
      'composition_score': subject != null ? scoreComposition(crop, subject) : 0.0,
      if (subject != null) 'subject_importance': subject.importance,
    };
  }
}

/// Classes de support pour l'analyseur de sujet
enum SubjectType { highContrast, colorDistinct, circularShape }

class DetectedSubject {
  final ui.Offset center;
  final ui.Rect bounds;
  final SubjectType type;
  final double confidence;
  final double importance;
  DetectedSubject({required this.center, required this.bounds, required this.type, required this.confidence, required this.importance});
}

class ColorCluster {
  final ui.Offset center;
  final ui.Rect bounds;
  final ui.Color dominantColor;
  final double distinctiveness;
  final double size;
  ColorCluster({required this.center, required this.bounds, required this.dominantColor, required this.distinctiveness, required this.size});
}

class CircularShape {
  final ui.Offset center;
  final ui.Rect bounds;
  final double radius;
  final double confidence;
  final double size;
  CircularShape({required this.center, required this.bounds, required this.radius, required this.confidence, required this.size});
}
