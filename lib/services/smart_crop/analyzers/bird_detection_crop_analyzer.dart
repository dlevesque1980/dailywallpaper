import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
import '../interfaces/crop_analyzer.dart';
import '../models/crop_score.dart';
import '../models/crop_coordinates.dart';

/// Analyseur spécialisé pour la détection d'oiseaux et le cropping optimal
///
/// Cet analyseur est spécialement conçu pour détecter les oiseaux dans les images
/// et créer des crops qui mettent en valeur la tête et les caractéristiques importantes.
class BirdDetectionCropAnalyzer implements CropAnalyzer {
  @override
  String get strategyName => 'bird_detection';

  @override
  double get weight => 0.95; // Poids très élevé pour les images d'oiseaux

  @override
  bool get isEnabledByDefault => true;

  @override
  double get minConfidenceThreshold => 0.25;

  @override
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize) async {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;

    // Obtenir les données de l'image
    final imageData = await _getImageData(image);

    // Vérifier la complexité de l'image avant de chercher des oiseaux
    final imageComplexity = _calculateImageComplexity(imageSize, imageData);
    if (imageComplexity < 0.3) {
      // Image trop simple (gradient, couleur unie, etc.) - pas d'oiseau probable
      final centerCrop = _getCenterCrop(imageSize, targetAspectRatio);
      return CropScore(
        coordinates: centerCrop,
        score: 0.05,
        strategy: strategyName,
        metrics: {
          'birds_detected': 0.0,
          'crop_area_ratio': centerCrop.width * centerCrop.height,
          'image_complexity': imageComplexity
        },
      );
    }

    // Détecter les oiseaux potentiels
    final birds = await _detectBirds(imageSize, imageData);

    if (birds.isEmpty) {
      // Pas d'oiseau détecté, retourner un score très faible
      final centerCrop = _getCenterCrop(imageSize, targetAspectRatio);
      return CropScore(
        coordinates: centerCrop,
        score: 0.05,
        strategy: strategyName,
        metrics: {
          'birds_detected': 0.0,
          'crop_area_ratio': centerCrop.width * centerCrop.height,
        },
      );
    }

    // Analyser chaque oiseau et choisir la meilleure stratégie
    CropCoordinates? bestCrop;
    double bestScore = 0.0;
    Map<String, double> bestMetrics = {};

    for (final bird in birds) {
      // Tester différentes stratégies de crop pour cet oiseau
      final strategies =
          _generateBirdCropStrategies(bird, imageSize, targetAspectRatio);

      for (final strategy in strategies) {
        final score =
            await _scoreBirdCrop(strategy, bird, imageSize, imageData);
        final metrics =
            await _calculateMetrics(strategy, bird, imageSize, imageData);

        if (score > bestScore) {
          bestScore = score;
          bestCrop = strategy;
          bestMetrics = metrics;
        }
      }
    }

    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    bestMetrics = await _calculateMetrics(
        bestCrop, birds.isNotEmpty ? birds.first : null, imageSize, imageData);

    // Si aucun oiseau n'a été détecté, utiliser un score très faible
    final finalScore = birds.isEmpty ? 0.05 : bestScore;

    return CropScore(
      coordinates: bestCrop,
      score: finalScore,
      strategy: strategyName,
      metrics: bestMetrics,
    );
  }

  /// Obtient les données de pixels de l'image
  Future<Uint8List> _getImageData(ui.Image image) async {
    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    return byteData!.buffer.asUint8List();
  }

  /// Détecte les oiseaux dans l'image
  Future<List<DetectedBird>> _detectBirds(
      ui.Size imageSize, Uint8List imageData) async {
    final birds = <DetectedBird>[];

    // 1. Détection de têtes d'oiseaux (formes circulaires/ovales avec bec)
    final heads = _detectBirdHeads(imageSize, imageData);
    birds.addAll(heads);

    // 2. Détection de corps d'oiseaux (formes allongées)
    final bodies = _detectBirdBodies(imageSize, imageData);
    birds.addAll(bodies);

    // 3. Détection par contraste de couleur (plumage distinctif)
    final colorBirds = _detectByPlumageColor(imageSize, imageData);
    birds.addAll(colorBirds);

    // Fusionner les détections proches (tête + corps = oiseau complet)
    final mergedBirds = _mergeBirdParts(birds);

    // Filtrer les détections faibles - exiger un score minimum plus élevé
    final validBirds =
        mergedBirds.where((bird) => bird.confidence > 0.75).toList();

    // Trier par score de confiance
    validBirds.sort((a, b) => b.confidence.compareTo(a.confidence));

    // Retourner les 2 meilleurs oiseaux maximum
    return validBirds.take(2).toList();
  }

  /// Détecte les têtes d'oiseaux
  List<DetectedBird> _detectBirdHeads(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final heads = <DetectedBird>[];

    // Rechercher des formes circulaires/ovales de différentes tailles
    final headSizes = [8, 12, 16, 24, 32]; // Tailles de têtes en pixels

    for (final headSize in headSizes) {
      final step = headSize ~/ 2;
      int checksPerformed = 0;
      const maxChecks =
          200; // Limiter le nombre de vérifications pour éviter les timeouts

      for (int y = headSize;
          y < height - headSize && checksPerformed < maxChecks;
          y += step) {
        for (int x = headSize;
            x < width - headSize && checksPerformed < maxChecks;
            x += step) {
          checksPerformed++;
          final headScore =
              _calculateHeadScore(imageData, width, x, y, headSize);

          if (headScore > 0.8) {
            // Rechercher un bec potentiel
            final beakScore = _detectBeak(imageData, width, x, y, headSize);
            final totalScore = headScore * 0.7 + beakScore * 0.3;

            if (totalScore > 0.75) {
              final centerX = x / width;
              final centerY = y / height;
              final size = (headSize * 2) / math.min(width, height);

              heads.add(DetectedBird(
                center: ui.Offset(centerX, centerY),
                bounds: ui.Rect.fromLTWH(
                    (x - headSize) / width,
                    (y - headSize) / height,
                    (headSize * 2) / width,
                    (headSize * 2) / height),
                type: BirdPartType.head,
                confidence: totalScore,
                size: size,
                hasHead: true,
                hasBeak: beakScore > 0.2,
              ));
            }
          }
        }
      }
    }

    return heads;
  }

  /// Calcule le score de probabilité qu'une région soit une tête d'oiseau
  double _calculateHeadScore(
      Uint8List imageData, int width, int centerX, int centerY, int radius) {
    // Analyser la forme circulaire/ovale
    final circularityScore =
        _calculateCircularity(imageData, width, centerX, centerY, radius);

    // Analyser le contraste avec l'arrière-plan
    final contrastScore =
        _calculateHeadContrast(imageData, width, centerX, centerY, radius);

    // Analyser la texture (plumage)
    final textureScore =
        _calculateFeatherTexture(imageData, width, centerX, centerY, radius);

    // Score combiné
    return (circularityScore * 0.4 + contrastScore * 0.4 + textureScore * 0.2);
  }

  /// Calcule la circularité d'une région
  double _calculateCircularity(
      Uint8List imageData, int width, int centerX, int centerY, int radius) {
    final centerBrightness =
        _getPixelBrightness(imageData, width, centerX, centerY);
    if (centerBrightness < 0) return 0.0;

    double totalVariance = 0.0;
    int sampleCount = 0;
    double consistencyScore = 0.0;

    // Échantillonner le contour du cercle
    final edgeBrightnesses = <int>[];
    for (int angle = 0; angle < 360; angle += 20) {
      final radians = angle * math.pi / 180;
      final edgeX = centerX + (radius * math.cos(radians)).round();
      final edgeY = centerY + (radius * math.sin(radians)).round();

      final edgeBrightness =
          _getPixelBrightness(imageData, width, edgeX, edgeY);
      if (edgeBrightness >= 0) {
        final variance = (centerBrightness - edgeBrightness).abs();
        totalVariance += variance;
        sampleCount++;
        edgeBrightnesses.add(edgeBrightness);
      }
    }

    if (sampleCount == 0 || sampleCount < 10) return 0.0;

    // Vérifier la consistance des bords (une vraie tête d'oiseau a des bords plus uniformes)
    if (edgeBrightnesses.length > 2) {
      final mean =
          edgeBrightnesses.reduce((a, b) => a + b) / edgeBrightnesses.length;
      final variance = edgeBrightnesses
              .map((b) => math.pow(b - mean, 2))
              .reduce((a, b) => a + b) /
          edgeBrightnesses.length;
      consistencyScore = math.max(0.0, 1.0 - math.sqrt(variance) / 64.0);
    }

    final avgVariance = totalVariance / sampleCount;
    final circularityScore = math.min(1.0, avgVariance / 128.0);

    // Combiner circularité et consistance - exiger les deux pour une détection valide
    return circularityScore * 0.6 + consistencyScore * 0.4;
  }

  /// Calcule le contraste de la tête avec l'arrière-plan
  double _calculateHeadContrast(
      Uint8List imageData, int width, int centerX, int centerY, int radius) {
    // Comparer la région de la tête avec l'arrière-plan environnant
    final headBrightness =
        _getRegionBrightness(imageData, width, centerX, centerY, radius);
    final backgroundBrightness =
        _getRegionBrightness(imageData, width, centerX, centerY, radius * 2) -
            headBrightness;

    final contrast = (headBrightness - backgroundBrightness).abs() / 255.0;
    return math.min(1.0, contrast);
  }

  /// Calcule la texture de plumage
  double _calculateFeatherTexture(
      Uint8List imageData, int width, int centerX, int centerY, int radius) {
    // Analyser la variation de texture dans la région
    final samples = <int>[];

    for (int dy = -radius ~/ 2; dy <= radius ~/ 2; dy += 2) {
      for (int dx = -radius ~/ 2; dx <= radius ~/ 2; dx += 2) {
        final x = centerX + dx;
        final y = centerY + dy;
        final brightness = _getPixelBrightness(imageData, width, x, y);
        if (brightness >= 0) samples.add(brightness);
      }
    }

    if (samples.length < 4) return 0.0;

    // Calculer l'écart-type (texture)
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance =
        samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) /
            samples.length;
    final stdDev = math.sqrt(variance);

    // Normaliser (plumage a généralement une texture modérée)
    return math.min(1.0, stdDev / 64.0);
  }

  /// Détecte un bec potentiel près d'une tête
  double _detectBeak(
      Uint8List imageData, int width, int headX, int headY, int headRadius) {
    double bestBeakScore = 0.0;

    // Rechercher dans différentes directions autour de la tête
    for (int angle = 0; angle < 360; angle += 30) {
      final radians = angle * math.pi / 180;
      final beakDistance =
          headRadius + (headRadius * 0.3); // Bec à ~30% du rayon de la tête

      final beakX = headX + (beakDistance * math.cos(radians)).round();
      final beakY = headY + (beakDistance * math.sin(radians)).round();

      // Analyser si cette région ressemble à un bec
      final beakScore =
          _calculateBeakScore(imageData, width, beakX, beakY, headRadius ~/ 3);
      bestBeakScore = math.max(bestBeakScore, beakScore);
    }

    return bestBeakScore;
  }

  /// Calcule le score de probabilité qu'une région soit un bec
  double _calculateBeakScore(
      Uint8List imageData, int width, int beakX, int beakY, int beakSize) {
    // Un bec est généralement plus sombre et plus contrasté
    final beakBrightness =
        _getRegionBrightness(imageData, width, beakX, beakY, beakSize);
    final surroundingBrightness =
        _getRegionBrightness(imageData, width, beakX, beakY, beakSize * 2) -
            beakBrightness;

    // Le bec devrait être plus sombre que l'environnement
    final darknessScore =
        math.max(0.0, (surroundingBrightness - beakBrightness) / 255.0);

    // Le bec devrait avoir une forme allongée/pointue
    final shapeScore =
        _calculateBeakShape(imageData, width, beakX, beakY, beakSize);

    return (darknessScore * 0.6 + shapeScore * 0.4);
  }

  /// Calcule le score de forme pour un bec
  double _calculateBeakShape(
      Uint8List imageData, int width, int beakX, int beakY, int beakSize) {
    // Analyser l'asymétrie (bec pointu vs rond)
    final horizontalVariance =
        _getDirectionalVariance(imageData, width, beakX, beakY, beakSize, true);
    final verticalVariance = _getDirectionalVariance(
        imageData, width, beakX, beakY, beakSize, false);

    // Un bec a généralement plus de variance dans une direction
    final asymmetry = (horizontalVariance - verticalVariance).abs() /
        math.max(horizontalVariance, verticalVariance);
    return math.min(1.0, asymmetry);
  }

  /// Détecte les corps d'oiseaux
  List<DetectedBird> _detectBirdBodies(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final bodies = <DetectedBird>[];

    // Rechercher des formes allongées de différentes tailles
    final bodySizes = [20, 30, 40, 60]; // Tailles de corps

    for (final bodySize in bodySizes) {
      final step = bodySize ~/ 3;
      int checksPerformed = 0;
      const maxChecks = 150; // Limiter le nombre de vérifications

      for (int y = bodySize;
          y < height - bodySize && checksPerformed < maxChecks;
          y += step) {
        for (int x = bodySize;
            x < width - bodySize && checksPerformed < maxChecks;
            x += step) {
          checksPerformed++;
          final bodyScore =
              _calculateBodyScore(imageData, width, x, y, bodySize);

          if (bodyScore > 0.8) {
            final centerX = x / width;
            final centerY = y / height;
            final size = (bodySize * 2) / math.min(width, height);

            bodies.add(DetectedBird(
              center: ui.Offset(centerX, centerY),
              bounds: ui.Rect.fromLTWH(
                  (x - bodySize) / width,
                  (y - bodySize) / height,
                  (bodySize * 2) / width,
                  (bodySize * 2) / height),
              type: BirdPartType.body,
              confidence: bodyScore,
              size: size,
              hasHead: false,
              hasBeak: false,
            ));
          }
        }
      }
    }

    return bodies;
  }

  /// Calcule le score de probabilité qu'une région soit un corps d'oiseau
  double _calculateBodyScore(
      Uint8List imageData, int width, int centerX, int centerY, int size) {
    // Analyser la forme allongée
    final elongationScore =
        _calculateElongation(imageData, width, centerX, centerY, size);

    // Analyser la texture de plumage
    final textureScore =
        _calculateFeatherTexture(imageData, width, centerX, centerY, size);

    // Analyser le contraste avec l'arrière-plan
    final contrastScore =
        _calculateHeadContrast(imageData, width, centerX, centerY, size);

    return (elongationScore * 0.5 + textureScore * 0.3 + contrastScore * 0.2);
  }

  /// Calcule l'élongation d'une forme
  double _calculateElongation(
      Uint8List imageData, int width, int centerX, int centerY, int size) {
    final horizontalVariance =
        _getDirectionalVariance(imageData, width, centerX, centerY, size, true);
    final verticalVariance = _getDirectionalVariance(
        imageData, width, centerX, centerY, size, false);

    // Un corps d'oiseau est généralement plus long dans une direction
    final ratio = math.max(horizontalVariance, verticalVariance) /
        math.min(horizontalVariance, verticalVariance);
    return math.min(1.0, (ratio - 1.0) / 2.0); // Normaliser
  }

  /// Détecte les oiseaux par couleur de plumage
  List<DetectedBird> _detectByPlumageColor(
      ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final colorBirds = <DetectedBird>[];

    // Analyser les régions avec des couleurs distinctives typiques des oiseaux
    final regionSize = 24;
    final step = regionSize ~/ 2;

    int checksPerformed = 0;
    const maxChecks = 100; // Limiter le nombre de vérifications

    for (int y = regionSize;
        y < height - regionSize && checksPerformed < maxChecks;
        y += step) {
      for (int x = regionSize;
          x < width - regionSize && checksPerformed < maxChecks;
          x += step) {
        checksPerformed++;
        final colorScore =
            _calculatePlumageColorScore(imageData, width, x, y, regionSize);

        if (colorScore > 0.85) {
          final centerX = x / width;
          final centerY = y / height;
          final size = (regionSize * 2) / math.min(width, height);

          colorBirds.add(DetectedBird(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(
                (x - regionSize) / width,
                (y - regionSize) / height,
                (regionSize * 2) / width,
                (regionSize * 2) / height),
            type: BirdPartType.plumage,
            confidence: colorScore,
            size: size,
            hasHead: false,
            hasBeak: false,
          ));
        }
      }
    }

    return colorBirds;
  }

  /// Calcule le score de couleur de plumage
  double _calculatePlumageColorScore(
      Uint8List imageData, int width, int centerX, int centerY, int size) {
    // Analyser la saturation et la distinctivité des couleurs
    final colors = <ui.Color>[];

    for (int dy = -size ~/ 2; dy <= size ~/ 2; dy += 3) {
      for (int dx = -size ~/ 2; dx <= size ~/ 2; dx += 3) {
        final x = centerX + dx;
        final y = centerY + dy;
        final color = _getPixelColor(imageData, width, x, y);
        if (color != null) colors.add(color);
      }
    }

    if (colors.isEmpty) return 0.0;

    // Calculer la saturation moyenne
    double totalSaturation = 0.0;
    for (final color in colors) {
      final hsv = _rgbToHsv(color);
      totalSaturation += hsv.saturation;
    }

    final avgSaturation = totalSaturation / colors.length;

    // Les oiseaux ont souvent des couleurs plus saturées que l'arrière-plan
    return math.min(1.0, avgSaturation * 1.5);
  }

  /// Fusionne les parties d'oiseaux détectées
  List<DetectedBird> _mergeBirdParts(List<DetectedBird> parts) {
    final mergedBirds = <DetectedBird>[];
    final processed = <bool>[];

    for (int i = 0; i < parts.length; i++) {
      processed.add(false);
    }

    for (int i = 0; i < parts.length; i++) {
      if (processed[i]) continue;

      final current = parts[i];
      final nearbyParts = <DetectedBird>[current];
      processed[i] = true;

      // Trouver les parties proches
      for (int j = i + 1; j < parts.length; j++) {
        if (processed[j]) continue;

        final distance = math.sqrt(
            math.pow(current.center.dx - parts[j].center.dx, 2) +
                math.pow(current.center.dy - parts[j].center.dy, 2));

        if (distance < 0.2) {
          // Seuil de proximité pour fusionner
          nearbyParts.add(parts[j]);
          processed[j] = true;
        }
      }

      // Créer un oiseau fusionné
      mergedBirds.add(_createMergedBird(nearbyParts));
    }

    return mergedBirds;
  }

  /// Crée un oiseau fusionné à partir de plusieurs parties
  DetectedBird _createMergedBird(List<DetectedBird> parts) {
    if (parts.length == 1) return parts.first;

    double totalConfidence = 0;
    double weightedX = 0, weightedY = 0;
    double minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    bool hasHead = false;
    bool hasBeak = false;
    BirdPartType bestType = parts.first.type;

    for (final part in parts) {
      totalConfidence += part.confidence;
      weightedX += part.center.dx * part.confidence;
      weightedY += part.center.dy * part.confidence;

      minX = math.min(minX, part.bounds.left);
      minY = math.min(minY, part.bounds.top);
      maxX = math.max(maxX, part.bounds.right);
      maxY = math.max(maxY, part.bounds.bottom);

      if (part.hasHead) hasHead = true;
      if (part.hasBeak) hasBeak = true;
      if (part.type == BirdPartType.head) bestType = BirdPartType.head;
    }

    final avgConfidence = totalConfidence / parts.length;
    final size = (maxX - minX) * (maxY - minY);

    return DetectedBird(
      center:
          ui.Offset(weightedX / totalConfidence, weightedY / totalConfidence),
      bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY),
      type: bestType,
      confidence: avgConfidence,
      size: size,
      hasHead: hasHead,
      hasBeak: hasBeak,
    );
  }

  /// Génère différentes stratégies de crop pour un oiseau
  List<CropCoordinates> _generateBirdCropStrategies(
      DetectedBird bird, ui.Size imageSize, double targetAspectRatio) {
    final strategies = <CropCoordinates>[];

    // Stratégie 1: Crop serré sur la tête (si détectée)
    if (bird.hasHead) {
      final headCrop =
          _createHeadFocusedCrop(bird, imageSize, targetAspectRatio);
      if (headCrop != null) strategies.add(headCrop);
    }

    // Stratégie 2: Crop sur l'oiseau complet avec contexte minimal
    final fullBirdCrop =
        _createFullBirdCrop(bird, imageSize, targetAspectRatio);
    if (fullBirdCrop != null) strategies.add(fullBirdCrop);

    // Stratégie 3: Crop avec contexte environnemental
    final contextCrop =
        _createBirdContextCrop(bird, imageSize, targetAspectRatio);
    if (contextCrop != null) strategies.add(contextCrop);

    return strategies;
  }

  /// Crée un crop focalisé sur la tête de l'oiseau
  CropCoordinates? _createHeadFocusedCrop(
      DetectedBird bird, ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Positionner le crop pour que la tête soit dans le tiers supérieur
    final headX = bird.center.dx;
    final headY = bird.center.dy;

    // Placer la tête dans le tiers supérieur du crop
    final targetHeadY = 0.3; // 30% du haut
    final cropY = math.max(
        0.0, math.min(1.0 - cropHeight, headY - (targetHeadY * cropHeight)));

    // Centrer horizontalement sur la tête
    final cropX =
        math.max(0.0, math.min(1.0 - cropWidth, headX - cropWidth / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: bird.confidence * 1.2, // Bonus pour focus sur la tête
      strategy: '${strategyName}_head_focus',
    );
  }

  /// Crée un crop incluant l'oiseau complet
  CropCoordinates? _createFullBirdCrop(
      DetectedBird bird, ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Centrer sur l'oiseau avec un peu de padding
    final birdCenterX = bird.center.dx;
    final birdCenterY = bird.center.dy;

    final cropX =
        math.max(0.0, math.min(1.0 - cropWidth, birdCenterX - cropWidth / 2));
    final cropY =
        math.max(0.0, math.min(1.0 - cropHeight, birdCenterY - cropHeight / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: bird.confidence,
      strategy: '${strategyName}_full_bird',
    );
  }

  /// Crée un crop avec contexte environnemental
  CropCoordinates? _createBirdContextCrop(
      DetectedBird bird, ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Positionner l'oiseau selon la règle des tiers
    final birdX = bird.center.dx;
    final birdY = bird.center.dy;

    // Choisir la position des tiers la plus proche
    final thirdPositions = [1 / 3, 2 / 3];
    double bestX = 0.5, bestY = 0.5;
    double minDistance = double.infinity;

    for (final thirdX in thirdPositions) {
      for (final thirdY in thirdPositions) {
        final distance = math
            .sqrt(math.pow(birdX - thirdX, 2) + math.pow(birdY - thirdY, 2));
        if (distance < minDistance) {
          minDistance = distance;
          bestX = thirdX;
          bestY = thirdY;
        }
      }
    }

    // Positionner le crop pour que l'oiseau soit au point des tiers choisi
    final cropX =
        math.max(0.0, math.min(1.0 - cropWidth, birdX - (bestX * cropWidth)));
    final cropY =
        math.max(0.0, math.min(1.0 - cropHeight, birdY - (bestY * cropHeight)));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: bird.confidence * 0.9, // Légèrement réduit car moins focalisé
      strategy: '${strategyName}_context',
    );
  }

  /// Score un crop basé sur l'oiseau détecté
  Future<double> _scoreBirdCrop(CropCoordinates crop, DetectedBird bird,
      ui.Size imageSize, Uint8List imageData) async {
    double score = 0.0;

    // 1. Inclusion de l'oiseau (35%)
    score += _scoreBirdInclusion(crop, bird) * 0.35;

    // 2. Qualité de la tête (si présente) (30%)
    if (bird.hasHead) {
      score += _scoreHeadQuality(crop, bird) * 0.3;
    } else {
      score += _scoreBirdCenterPosition(crop, bird) * 0.3;
    }

    // 3. Composition générale (20%)
    score += _scoreBirdComposition(crop, bird) * 0.2;

    // 4. Évitement des bords (15%)
    score += _scoreEdgeAvoidance(crop) * 0.15;

    return math.min(1.0, score);
  }

  /// Score l'inclusion de l'oiseau dans le crop
  double _scoreBirdInclusion(CropCoordinates crop, DetectedBird bird) {
    final cropRect = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height);
    final intersection = cropRect.intersect(bird.bounds);

    if (intersection.isEmpty) return 0.0;

    final inclusionRatio = intersection.width *
        intersection.height /
        (bird.bounds.width * bird.bounds.height);

    return inclusionRatio;
  }

  /// Score la qualité de la tête dans le crop
  double _scoreHeadQuality(CropCoordinates crop, DetectedBird bird) {
    if (!bird.hasHead) return 0.0;

    // Vérifier si la tête est bien positionnée dans le crop
    final headInCropY = (bird.center.dy - crop.y) / crop.height;

    // Préférer la tête dans le tiers supérieur
    double headPositionScore = 1.0;
    if (headInCropY > 0.6) {
      headPositionScore = math.max(0.3, 1.0 - (headInCropY - 0.6) * 2);
    }

    // Bonus si un bec est détecté
    double beakBonus = bird.hasBeak ? 1.2 : 1.0;

    return bird.confidence * headPositionScore * beakBonus;
  }

  /// Score la position centrale de l'oiseau
  double _scoreBirdCenterPosition(CropCoordinates crop, DetectedBird bird) {
    final birdInCropX = (bird.center.dx - crop.x) / crop.width;
    final birdInCropY = (bird.center.dy - crop.y) / crop.height;

    // Préférer l'oiseau près du centre ou des points de règle des tiers
    final distanceFromCenter = math
        .sqrt(math.pow(birdInCropX - 0.5, 2) + math.pow(birdInCropY - 0.5, 2));

    return math.max(0.2, 1.0 - distanceFromCenter);
  }

  /// Score la composition du crop avec l'oiseau
  double _scoreBirdComposition(CropCoordinates crop, DetectedBird bird) {
    // Analyser la position de l'oiseau selon la règle des tiers
    final birdInCropX = (bird.center.dx - crop.x) / crop.width;
    final birdInCropY = (bird.center.dy - crop.y) / crop.height;

    // Distance aux points de règle des tiers
    final thirdPoints = [
      ui.Offset(1 / 3, 1 / 3),
      ui.Offset(2 / 3, 1 / 3),
      ui.Offset(1 / 3, 2 / 3),
      ui.Offset(2 / 3, 2 / 3),
    ];

    double minDistance = double.infinity;
    for (final point in thirdPoints) {
      final distance = math.sqrt(math.pow(birdInCropX - point.dx, 2) +
          math.pow(birdInCropY - point.dy, 2));
      minDistance = math.min(minDistance, distance);
    }

    return math.max(0.0, 1.0 - minDistance * 2);
  }

  /// Score l'évitement des bords
  double _scoreEdgeAvoidance(CropCoordinates crop) {
    double penalty = 0.0;

    if (crop.x <= 0.01) penalty += 0.3;
    if (crop.y <= 0.01) penalty += 0.3;
    if (crop.x + crop.width >= 0.99) penalty += 0.3;
    if (crop.y + crop.height >= 0.99) penalty += 0.3;

    return math.max(0.0, 1.0 - penalty);
  }

  // Méthodes utilitaires...

  int _getPixelBrightness(Uint8List imageData, int width, int x, int y) {
    if (x < 0 || x >= width || y < 0) return -1;
    final pixelIndex = (y * width + x) * 4;
    if (pixelIndex + 2 >= imageData.length) return -1;

    final r = imageData[pixelIndex];
    final g = imageData[pixelIndex + 1];
    final b = imageData[pixelIndex + 2];
    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }

  double _getRegionBrightness(
      Uint8List imageData, int width, int centerX, int centerY, int radius) {
    double totalBrightness = 0.0;
    int count = 0;

    for (int dy = -radius; dy <= radius; dy += 2) {
      for (int dx = -radius; dx <= radius; dx += 2) {
        final brightness =
            _getPixelBrightness(imageData, width, centerX + dx, centerY + dy);
        if (brightness >= 0) {
          totalBrightness += brightness;
          count++;
        }
      }
    }

    return count > 0 ? totalBrightness / count : 0.0;
  }

  double _getDirectionalVariance(Uint8List imageData, int width, int centerX,
      int centerY, int size, bool horizontal) {
    final samples = <int>[];

    if (horizontal) {
      for (int dx = -size; dx <= size; dx += 2) {
        final brightness =
            _getPixelBrightness(imageData, width, centerX + dx, centerY);
        if (brightness >= 0) samples.add(brightness);
      }
    } else {
      for (int dy = -size; dy <= size; dy += 2) {
        final brightness =
            _getPixelBrightness(imageData, width, centerX, centerY + dy);
        if (brightness >= 0) samples.add(brightness);
      }
    }

    if (samples.length < 2) return 0.0;

    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance =
        samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) /
            samples.length;
    return variance;
  }

  ui.Color? _getPixelColor(Uint8List imageData, int width, int x, int y) {
    if (x < 0 || x >= width || y < 0) return null;
    final pixelIndex = (y * width + x) * 4;
    if (pixelIndex + 3 >= imageData.length) return null;

    return ui.Color.fromARGB(
      imageData[pixelIndex + 3], // A
      imageData[pixelIndex], // R
      imageData[pixelIndex + 1], // G
      imageData[pixelIndex + 2], // B
    );
  }

  HSV _rgbToHsv(ui.Color color) {
    final r = (color.r * 255.0).round() / 255.0;
    final g = (color.g * 255.0).round() / 255.0;
    final b = (color.b * 255.0).round() / 255.0;

    final max = math.max(r, math.max(g, b));
    final min = math.min(r, math.min(g, b));
    final delta = max - min;

    double hue = 0.0;
    if (delta != 0) {
      if (max == r) {
        hue = ((g - b) / delta) % 6;
      } else if (max == g) {
        hue = (b - r) / delta + 2;
      } else {
        hue = (r - g) / delta + 4;
      }
      hue *= 60;
    }

    final saturation = max == 0 ? 0.0 : delta / max;
    final value = max;

    return HSV(hue, saturation, value);
  }

  double _calculateCropWidth(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio > imageAspectRatio
        ? 1.0
        : targetAspectRatio / imageAspectRatio;
  }

  double _calculateCropHeight(ui.Size imageSize, double targetAspectRatio) {
    final imageAspectRatio = imageSize.width / imageSize.height;
    return targetAspectRatio < imageAspectRatio
        ? 1.0
        : imageAspectRatio / targetAspectRatio;
  }

  CropCoordinates _getCenterCrop(ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.2,
      strategy: strategyName,
    );
  }

  Future<Map<String, double>> _calculateMetrics(CropCoordinates crop,
      DetectedBird? bird, ui.Size imageSize, Uint8List imageData) async {
    final metrics = <String, double>{
      'birds_detected': bird != null ? 1.0 : 0.0,
      'crop_area_ratio': crop.width * crop.height,
    };

    if (bird != null) {
      metrics.addAll({
        'bird_confidence': bird.confidence,
        'bird_size': bird.size,
        'has_head': bird.hasHead ? 1.0 : 0.0,
        'has_beak': bird.hasBeak ? 1.0 : 0.0,
        'bird_inclusion': _scoreBirdInclusion(crop, bird),
        'bird_type': bird.type.index.toDouble(),
      });
    }

    return metrics;
  }

  /// Calcule la complexité de l'image pour déterminer si elle peut contenir des oiseaux
  double _calculateImageComplexity(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();

    // Échantillonner très rapidement avec un pas plus grand pour la performance
    final samples = <int>[];
    final step = math.max(
        8, math.min(width, height) ~/ 10); // Échantillonner moins de points

    // Limiter le nombre d'échantillons pour éviter les timeouts
    int sampleCount = 0;
    const maxSamples = 100;

    for (int y = 0; y < height && sampleCount < maxSamples; y += step) {
      for (int x = 0; x < width && sampleCount < maxSamples; x += step) {
        final brightness = _getPixelBrightness(imageData, width, x, y);
        if (brightness >= 0) {
          samples.add(brightness);
          sampleCount++;
        }
      }
    }

    if (samples.length < 5) return 0.0;

    // Calculer seulement la variance de luminosité pour la rapidité
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance =
        samples.map((s) => math.pow(s - mean, 2)).reduce((a, b) => a + b) /
            samples.length;
    final stdDev = math.sqrt(variance);

    // Retourner seulement la complexité de luminosité (plus rapide)
    return math.min(1.0, stdDev / 64.0);
  }
}

/// Types de parties d'oiseaux détectées
enum BirdPartType {
  head,
  body,
  plumage,
}

/// Représente un oiseau détecté dans l'image
class DetectedBird {
  final ui.Offset center;
  final ui.Rect bounds;
  final BirdPartType type;
  final double confidence;
  final double size;
  final bool hasHead;
  final bool hasBeak;

  DetectedBird({
    required this.center,
    required this.bounds,
    required this.type,
    required this.confidence,
    required this.size,
    required this.hasHead,
    required this.hasBeak,
  });
}

/// Représente une couleur HSV
class HSV {
  final double hue;
  final double saturation;
  final double value;

  HSV(this.hue, this.saturation, this.value);
}
