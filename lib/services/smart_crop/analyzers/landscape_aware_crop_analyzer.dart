import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Analyseur de crop spécialement conçu pour les images de paysage
///
/// Cet analyseur détecte les images de paysage et applique des stratégies
/// de cropping optimisées pour préserver les éléments importants comme
/// l'horizon, les sujets principaux et les points d'intérêt visuels.
class LandscapeAwareCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'landscape_aware';

  @override
  double get weight => 1.0; // Force landscape aware for horizontal nature photos

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.2;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    // Vérifier si c'est une image de paysage (ratio > 1.3)
    if (imageAspectRatio < 1.3) {
      // Pas une image de paysage, retourner un score faible
      return CropScore(
        coordinates: _getCenterCrop(imageSize, targetAspectRatio),
        score: 0.1,
        strategy: strategyName,
        metrics: {'landscape_detected': 0.0},
      );
    }

    // Obtenir les données de l'image pour l'analyse
    final imageData = await _getImageData(image);

    CropCoordinates? bestCrop;
    double bestScore = 0.0;
    Map<String, double> bestMetrics = {};

    // Générer des candidats spécifiques aux paysages
    final candidates =
        _generateLandscapeCandidates(imageSize, targetAspectRatio, imageData);

    for (final candidate in candidates) {
      final score = await _scoreLandscapeCrop(candidate, imageSize, imageData);
      final metrics = await _calculateMetrics(candidate, imageSize, imageData);
      // print('Landscape candidate ${candidate.strategy} x=${candidate.x} score=$score');

      if (score > bestScore) {
        bestScore = score;
        bestCrop = candidate;
        
        // Find the bounding box of the included subjects for this candidate if subjects exist
        final subjects = _detectSubjectAreas(imageSize, imageData);
        if (subjects.isNotEmpty) {
           double minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
           bool foundSubjectInCrop = false;
           for(final subject in subjects) {
               if (subject.dx >= candidate.x &&
                  subject.dx <= candidate.x + candidate.width &&
                  subject.dy >= candidate.y &&
                  subject.dy <= candidate.y + candidate.height) {
                  
                  minX = math.min(minX, subject.dx);
                  minY = math.min(minY, subject.dy);
                  maxX = math.max(maxX, subject.dx);
                  maxY = math.max(maxY, subject.dy);
                  foundSubjectInCrop = true;
               }
           }
           
           if (foundSubjectInCrop) {
              // Add a small padding around the points to create a proper bounding box
              final boxWidth = math.max(0.1, maxX - minX);
              final boxHeight = math.max(0.1, maxY - minY);
              
              metrics['subject_x'] = math.max(0.0, minX - 0.05);
              metrics['subject_y'] = math.max(0.0, minY - 0.05);
              metrics['subject_width'] = math.min(1.0 - metrics['subject_x']!, boxWidth + 0.1);
              metrics['subject_height'] = math.min(1.0 - metrics['subject_y']!, boxHeight + 0.1);
           }
        }
        
        bestMetrics = metrics;
      }
    }

    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    bestMetrics = await _calculateMetrics(bestCrop, imageSize, imageData);

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

  /// Génère des candidats de crop optimisés pour les paysages
  List<CropCoordinates> _generateLandscapeCandidates(
      ui.Size imageSize, double targetAspectRatio, Uint8List imageData) {
    final candidates = <CropCoordinates>[];
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // 1. Détection de l'horizon
    final horizonY = _detectHorizon(imageSize, imageData);

    // 2. Candidats basés sur la règle des tiers avec horizon
    final thirdPositions = [1 / 3, 0.5, 2 / 3];

    for (final horizonPosition in thirdPositions) {
      // Positionner le crop pour que l'horizon soit à la position désirée
      final targetHorizonY = horizonPosition;
      final cropY = math.max(0.0,
          math.min(1.0 - cropHeight, horizonY - (targetHorizonY * cropHeight)));

      // Plusieurs positions horizontales
      final horizontalPositions = [0.0, 0.25, 0.5, 0.75, 1.0 - cropWidth];

      for (final cropX in horizontalPositions) {
        if (cropX >= 0.0 && cropX <= 1.0 - cropWidth) {
          candidates.add(CropCoordinates(
            x: cropX,
            y: cropY,
            width: cropWidth,
            height: cropHeight,
            confidence: 0.6,
            strategy: strategyName,
          ));
        }
      }
    }

    // 3. Candidats basés sur la détection de sujets
    final subjectAreas = _detectSubjectAreas(imageSize, imageData);

    if (subjectAreas.isNotEmpty) {
      // a. Candidat centré sur le point moyen de tous les sujets pour équilibrer la scène
      double avgX = 0;
      double avgY = 0;
      for (final s in subjectAreas) {
        avgX += s.dx;
        avgY += s.dy;
      }
      avgX /= subjectAreas.length;
      avgY /= subjectAreas.length;

      final meanCropX = math.max(
          0.0, math.min(1.0 - cropWidth, avgX - cropWidth / 2));
      final meanCropY = math.max(
          0.0, math.min(1.0 - cropHeight, avgY - cropHeight / 2));

      candidates.add(CropCoordinates(
        x: meanCropX,
        y: meanCropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.8, // Haute confiance pour englober tous les sujets équitablement
        strategy: '${strategyName}_mean_subjects',
      ));

      // b. Candidats centrés sur chaque sujet individuel
      for (final subjectArea in subjectAreas) {
        final cropX = math.max(
            0.0, math.min(1.0 - cropWidth, subjectArea.dx - cropWidth / 2));
        final cropY = math.max(
            0.0, math.min(1.0 - cropHeight, subjectArea.dy - cropHeight / 2));

        candidates.add(CropCoordinates(
          x: cropX,
          y: cropY,
          width: cropWidth,
          height: cropHeight,
          confidence: 0.7,
          strategy: strategyName,
        ));
      }
    }

    // 4. Candidats pour éviter les zones vides (ciel/eau)
    final nonEmptyAreas = _detectNonEmptyAreas(imageSize, imageData);

    for (final area in nonEmptyAreas) {
      final cropX =
          math.max(0.0, math.min(1.0 - cropWidth, area.dx - cropWidth / 2));
      final cropY =
          math.max(0.0, math.min(1.0 - cropHeight, area.dy - cropHeight / 2));

      candidates.add(CropCoordinates(
        x: cropX,
        y: cropY,
        width: cropWidth,
        height: cropHeight,
        confidence: 0.5,
        strategy: strategyName,
      ));
    }

    return candidates;
  }

  /// Détecte la position de l'horizon dans l'image
  double _detectHorizon(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    // Analyser les changements de luminosité horizontaux
    final horizontalGradients = <double>[];

    for (int y = height ~/ 4; y < (height * 3) ~/ 4; y++) {
      double rowBrightness = 0.0;
      int pixelCount = 0;

      for (int x = 0; x < width; x += 4) {
        // Échantillonnage
        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 < imageData.length) {
          final r = imageData[pixelIndex];
          final g = imageData[pixelIndex + 1];
          final b = imageData[pixelIndex + 2];
          final brightness = (0.299 * r + 0.587 * g + 0.114 * b);
          rowBrightness += brightness;
          pixelCount++;
        }
      }

      if (pixelCount > 0) {
        horizontalGradients.add(rowBrightness / pixelCount);
      }
    }

    // Trouver la plus grande variation (probable horizon)
    double maxGradient = 0.0;
    int horizonIndex = horizontalGradients.length ~/ 2;

    for (int i = 1; i < horizontalGradients.length - 1; i++) {
      final gradient =
          (horizontalGradients[i + 1] - horizontalGradients[i - 1]).abs();
      if (gradient > maxGradient) {
        maxGradient = gradient;
        horizonIndex = i;
      }
    }

    // Convertir en coordonnée normalisée
    final actualY = (height ~/ 4) + horizonIndex;
    return actualY / height;
  }

  /// Détecte les zones avec des sujets potentiels
  List<ui.Offset> _detectSubjectAreas(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final subjects = <ui.Offset>[];

    // Grille d'analyse 8x6 pour détecter les zones d'intérêt
    final gridWidth = 8;
    final gridHeight = 6;

    for (int gy = 0; gy < gridHeight; gy++) {
      for (int gx = 0; gx < gridWidth; gx++) {
        final startX = (gx * width) ~/ gridWidth;
        final endX = ((gx + 1) * width) ~/ gridWidth;
        final startY = (gy * height) ~/ gridHeight;
        final endY = ((gy + 1) * height) ~/ gridHeight;

        // Calculer la variance de couleur dans cette zone
        final variance = _calculateColorVariance(
            imageData, width, startX, endX, startY, endY);

        // Si la variance est élevée, c'est probablement un sujet
        if (variance > 800) {
          // Seuil ajustable
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          subjects.add(ui.Offset(centerX, centerY));
        }
      }
    }

    return subjects;
  }

  /// Détecte les zones non vides (éviter le ciel uniforme)
  List<ui.Offset> _detectNonEmptyAreas(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final nonEmptyAreas = <ui.Offset>[];

    // Analyser la partie inférieure de l'image (plus susceptible d'avoir du contenu)
    final startY = height ~/ 3;
    final gridSize = 6;

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final centerX = (gx + 0.5) / gridSize;
        final centerY = startY / height + (gy + 0.5) / gridSize * (2 / 3);

        final pixelX = (centerX * width).round();
        final pixelY = (centerY * height).round();

        if (pixelX < width && pixelY < height) {
          // Calculer la complexité locale
          final complexity = _calculateLocalComplexity(
              imageData, width, height, pixelX, pixelY, 20);

          if (complexity > 0.3) {
            nonEmptyAreas.add(ui.Offset(centerX, centerY));
          }
        }
      }
    }

    return nonEmptyAreas;
  }

  /// Calcule la variance de couleur dans une région
  double _calculateColorVariance(Uint8List imageData, int width, int startX,
      int endX, int startY, int endY) {
    final colors = <int>[];

    for (int y = startY; y < endY; y += 2) {
      for (int x = startX; x < endX; x += 2) {
        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 < imageData.length) {
          final r = imageData[pixelIndex];
          final g = imageData[pixelIndex + 1];
          final b = imageData[pixelIndex + 2];
          final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
          colors.add(gray);
        }
      }
    }

    if (colors.isEmpty) return 0.0;

    final mean = colors.reduce((a, b) => a + b) / colors.length;
    final variance =
        colors.map((c) => math.pow(c - mean, 2)).reduce((a, b) => a + b) /
            colors.length;

    return variance;
  }

  /// Calcule la complexité locale autour d'un point
  double _calculateLocalComplexity(Uint8List imageData, int width, int height,
      int centerX, int centerY, int radius) {
    final samples = <int>[];

    for (int dy = -radius; dy <= radius; dy += 4) {
      for (int dx = -radius; dx <= radius; dx += 4) {
        final x = centerX + dx;
        final y = centerY + dy;

        if (x >= 0 && x < width && y >= 0 && y < height) {
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

    // Calculer l'écart-type normalisé
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance =
        samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) /
            samples.length;
    final stdDev = math.sqrt(variance);

    return math.min(1.0, stdDev / 128.0);
  }

  /// Score un crop basé sur les critères de paysage
  Future<double> _scoreLandscapeCrop(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) async {
    double score = 0.0;

    // 1. Score de préservation de l'horizon (30%)
    score += _scoreHorizonPreservation(crop, imageSize, imageData) * 0.3;

    // 2. Score d'inclusion de sujets (25%)
    score += _scoreSubjectInclusion(crop, imageSize, imageData) * 0.25;

    // 3. Score d'évitement des zones vides (20%)
    score += _scoreEmptyAreaAvoidance(crop, imageSize, imageData) * 0.2;

    // 4. Score de composition (règle des tiers) (15%)
    score += _scoreComposition(crop) * 0.15;

    // 5. Score de diversité visuelle (10%)
    score += _scoreVisualDiversity(crop, imageSize, imageData) * 0.1;

    return math.min(1.0, score);
  }

  /// Score la préservation de l'horizon
  double _scoreHorizonPreservation(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final horizonY = _detectHorizon(imageSize, imageData);

    // Vérifier si l'horizon est dans le crop
    if (horizonY >= crop.y && horizonY <= crop.y + crop.height) {
      // Position de l'horizon dans le crop (0.0 = haut, 1.0 = bas)
      final horizonPositionInCrop = (horizonY - crop.y) / crop.height;

      // Préférer l'horizon aux tiers (1/3 ou 2/3)
      final distanceFromThird1 = (horizonPositionInCrop - 1 / 3).abs();
      final distanceFromThird2 = (horizonPositionInCrop - 2 / 3).abs();
      final minDistance = math.min(distanceFromThird1, distanceFromThird2);

      return math.max(0.0, 1.0 - minDistance * 3);
    }

    return 0.6; // Neutre/léger bonus si l'horizon n'est pas clair ou hors crop
  }

  /// Score l'inclusion de sujets importants
  double _scoreSubjectInclusion(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final subjects = _detectSubjectAreas(imageSize, imageData);
    int includedSubjects = 0;

    for (final subject in subjects) {
      if (subject.dx >= crop.x &&
          subject.dx <= crop.x + crop.width &&
          subject.dy >= crop.y &&
          subject.dy <= crop.y + crop.height) {
        includedSubjects++;
      }
    }

    if (subjects.isEmpty) return 0.8; // Très bon score par défaut si on n'a que le paysage

    return includedSubjects / subjects.length;
  }

  /// Score l'évitement des zones vides
  double _scoreEmptyAreaAvoidance(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    // Échantillonner plusieurs points dans le crop
    double totalComplexity = 0.0;
    int sampleCount = 0;

    for (double y = crop.y + 0.1; y < crop.y + crop.height - 0.1; y += 0.2) {
      for (double x = crop.x + 0.1; x < crop.x + crop.width - 0.1; x += 0.2) {
        final pixelX = (x * imageSize.width).round();
        final pixelY = (y * imageSize.height).round();

        final complexity = _calculateLocalComplexity(
            imageData,
            imageSize.width.toInt(),
            imageSize.height.toInt(),
            pixelX,
            pixelY,
            15);

        totalComplexity += complexity;
        sampleCount++;
      }
    }

    return sampleCount > 0 ? totalComplexity / sampleCount : 0.0;
  }

  /// Score la composition selon la règle des tiers
  double _scoreComposition(CropCoordinates crop) {
    final centerX = crop.x + crop.width / 2;
    final centerY = crop.y + crop.height / 2;

    // Distance du centre aux points de règle des tiers
    final thirdPoints = [
      ui.Offset(1 / 3, 1 / 3),
      ui.Offset(2 / 3, 1 / 3),
      ui.Offset(1 / 3, 2 / 3),
      ui.Offset(2 / 3, 2 / 3),
    ];

    double minDistance = double.infinity;
    for (final point in thirdPoints) {
      final distance = math.sqrt(
          math.pow(centerX - point.dx, 2) + math.pow(centerY - point.dy, 2));
      minDistance = math.min(minDistance, distance);
    }

    // Score inversement proportionnel à la distance
    return math.max(0.0, 1.0 - minDistance * 2);
  }

  /// Score la diversité visuelle dans le crop
  double _scoreVisualDiversity(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    final cropPixelX = (crop.x * width).round();
    final cropPixelY = (crop.y * height).round();
    final cropPixelWidth = (crop.width * width).round();
    final cropPixelHeight = (crop.height * height).round();

    final colors = <int>[];

    // Échantillonner les couleurs dans le crop
    for (int y = cropPixelY; y < cropPixelY + cropPixelHeight; y += 8) {
      for (int x = cropPixelX; x < cropPixelX + cropPixelWidth; x += 8) {
        if (x < width && y < height) {
          final pixelIndex = (y * width + x) * 4;
          if (pixelIndex + 2 < imageData.length) {
            final r = imageData[pixelIndex];
            final g = imageData[pixelIndex + 1];
            final b = imageData[pixelIndex + 2];
            final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
            colors.add(gray);
          }
        }
      }
    }

    if (colors.isEmpty) return 0.0;

    // Calculer l'entropie des couleurs
    final histogram = <int, int>{};
    for (final color in colors) {
      final bucket = color ~/ 32; // Regrouper en buckets
      histogram[bucket] = (histogram[bucket] ?? 0) + 1;
    }

    double entropy = 0.0;
    final total = colors.length;

    for (final count in histogram.values) {
      final probability = count / total;
      if (probability > 0) {
        entropy -= probability * math.log(probability) / math.ln2;
      }
    }

    // Normaliser l'entropie
    final maxEntropy = math.log(histogram.length) / math.ln2;
    return maxEntropy > 0 ? entropy / maxEntropy : 0.0;
  }

  /// Calcule la largeur du crop
  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;

    if (targetAspectRatio > imageAspectRatio) {
      return 1.0;
    } else {
      return targetAspectRatio / imageAspectRatio;
    }
  }

  /// Calcule la hauteur du crop
  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;

    if (targetAspectRatio < imageAspectRatio) {
      return 1.0;
    } else {
      return imageAspectRatio / targetAspectRatio;
    }
  }

  /// Crée un crop centré comme fallback
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

  /// Calcule les métriques détaillées
  Future<Map<String, double>> _calculateMetrics(
      CropCoordinates crop, ui.Size imageSize, Uint8List imageData) async {
    return {
      'landscape_detected':
          imageSize.width / imageSize.height > 1.3 ? 1.0 : 0.0,
      'horizon_preservation':
          _scoreHorizonPreservation(crop, imageSize, imageData),
      'subject_inclusion': _scoreSubjectInclusion(crop, imageSize, imageData),
      'empty_area_avoidance':
          _scoreEmptyAreaAvoidance(crop, imageSize, imageData),
      'composition_score': _scoreComposition(crop),
      'visual_diversity': _scoreVisualDiversity(crop, imageSize, imageData),
      'crop_area_ratio': crop.width * crop.height,
    };
  }
}
