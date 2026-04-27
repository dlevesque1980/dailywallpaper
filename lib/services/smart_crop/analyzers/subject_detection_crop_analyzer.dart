import 'dart:ui' as ui;
import 'dart:math' as math;
import 'dart:typed_data';
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
  double get weight => 0.85; // Increased weight to compete with specialized analyzers

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

    // Détecter les sujets potentiels
    final subjects = await _detectSubjects(imageSize, imageData);

    if (subjects.isEmpty) {
      // Pas de sujet détecté, retourner un score faible
      return CropScore(
        coordinates: _getCenterCrop(imageSize, targetAspectRatio),
        score: 0.1,
        strategy: strategyName,
        metrics: {'subjects_detected': 0.0},
      );
    }

    // Analyser chaque sujet et choisir la meilleure stratégie
    CropCoordinates? bestCrop;
    double bestScore = 0.0;
    Map<String, double> bestMetrics = {};

    double maxImportance = 0.0;
    if (subjects.isNotEmpty) {
      maxImportance = subjects.map((s) => s.importance).reduce(math.max);
    }

    for (int i = 0; i < subjects.length; i++) {
      final subject = subjects[i];
      // Tester différentes stratégies de crop pour ce sujet
      final strategies =
          _generateCropStrategies(subject, imageSize, targetAspectRatio);

      for (final strategy in strategies) {
        final score =
            await _scoreSubjectCrop(strategy, subject, imageSize, imageData, maxImportance, targetAspectRatio);
        final metrics =
            await _calculateMetrics(strategy, subject, imageSize, imageData);

        if (score > bestScore) {
          bestScore = score;
          bestCrop = strategy;
          bestMetrics = metrics;
        }
      }
    }

    bestCrop ??= _getCenterCrop(imageSize, targetAspectRatio);
    bestMetrics = await _calculateMetrics(bestCrop,
        subjects.isNotEmpty ? subjects.first : null, imageSize, imageData);
        
    if (subjects.isNotEmpty) {
       bestMetrics['subject_target_x'] = subjects.first.center.dx;
       bestMetrics['subject_target_y'] = subjects.first.center.dy;
    }

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

  /// Détecte les sujets dans l'image
  Future<List<DetectedSubject>> _detectSubjects(
      ui.Size imageSize, Uint8List imageData) async {
    final subjects = <DetectedSubject>[];

    // 1. Détection par contraste et contours
    final contrastSubjects = _detectByContrast(imageSize, imageData);
    subjects.addAll(contrastSubjects);

    // 2. Détection par analyse de couleur
    final colorSubjects = _detectByColorAnalysis(imageSize, imageData);
    subjects.addAll(colorSubjects);

    // 3. Détection par forme et texture
    final shapeSubjects = _detectByShape(imageSize, imageData);
    subjects.addAll(shapeSubjects);

    // Fusionner les sujets proches et éliminer les doublons
    final mergedSubjects = _mergeNearbySubjects(subjects);

    // Trier par importance (taille, contraste, position)
    mergedSubjects.sort((a, b) => b.importance.compareTo(a.importance));

    // Retourner les 5 meilleurs sujets maximum pour ne pas rater la tête
    return mergedSubjects.take(5).toList();
  }

  /// Détection de sujets par analyse de contraste
  List<DetectedSubject> _detectByContrast(
      ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final subjects = <DetectedSubject>[];

    // Grille d'analyse plus fine pour détecter les détails
    final gridSize = 16; // 16x16 pour plus de précision
    final cellWidth = width / gridSize;
    final cellHeight = height / gridSize;

    for (int gy = 0; gy < gridSize; gy++) {
      for (int gx = 0; gx < gridSize; gx++) {
        final startX = (gx * cellWidth).round();
        final endX = ((gx + 1) * cellWidth).round();
        final startY = (gy * cellHeight).round();
        final endY = ((gy + 1) * cellHeight).round();

        // Calculer le contraste local
        final contrast = _calculateLocalContrast(
            imageData, width, startX, endX, startY, endY);

        // Si le contraste est suffisant, c'est probablement un sujet
        if (contrast > 0.25) {
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          final size = math.sqrt((cellWidth * cellHeight) / (width * height));

          subjects.add(DetectedSubject(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height,
                (endX - startX) / width, (endY - startY) / height),
            type: SubjectType.highContrast,
            confidence: contrast,
            importance: contrast * _getPositionWeight(centerX, centerY) * size,
          ));
        }
      }
    }

    return subjects;
  }

  /// Détection de sujets par analyse de couleur
  List<DetectedSubject> _detectByColorAnalysis(
      ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final subjects = <DetectedSubject>[];

    // Analyser les zones avec des couleurs distinctives
    final colorClusters = _findColorClusters(imageData, width, height);

    for (final cluster in colorClusters) {
      if (cluster.distinctiveness > 0.3 && cluster.size > 0.01) {
        final importance = cluster.distinctiveness *
            cluster.size *
            _getPositionWeight(cluster.center.dx, cluster.center.dy);

        subjects.add(DetectedSubject(
          center: cluster.center,
          bounds: cluster.bounds,
          type: SubjectType.colorDistinct,
          confidence: cluster.distinctiveness,
          importance: importance,
        ));
      }
    }

    return subjects;
  }

  /// Détection de sujets par forme et texture
  List<DetectedSubject> _detectByShape(ui.Size imageSize, Uint8List imageData) {
    final width = imageSize.width.toInt();
    final height = imageSize.height.toInt();
    final subjects = <DetectedSubject>[];

    // Détecter les formes circulaires/ovales (têtes, yeux)
    final circularShapes = _detectCircularShapes(imageData, width, height);

    for (final shape in circularShapes) {
      if (shape.confidence > 0.25) {
        final importance = shape.confidence *
            shape.size *
            _getPositionWeight(shape.center.dx, shape.center.dy) *
            1.2; // Bonus réduit (1.8 -> 1.2) pour éviter que des roches ou gouttes d'eau ne dominent le sujet

        subjects.add(DetectedSubject(
          center: shape.center,
          bounds: shape.bounds,
          type: SubjectType.circularShape,
          confidence: shape.confidence,
          importance: importance,
        ));
      }
    }

    return subjects;
  }

  /// Calcule le contraste local dans une région
  double _calculateLocalContrast(Uint8List imageData, int width, int startX,
      int endX, int startY, int endY) {
    final pixels = <int>[];

    for (int y = startY; y < endY; y += 2) {
      for (int x = startX; x < endX; x += 2) {
        if (x < width && y < width) {
          final pixelIndex = (y * width + x) * 4;
          if (pixelIndex + 2 < imageData.length) {
            final r = imageData[pixelIndex];
            final g = imageData[pixelIndex + 1];
            final b = imageData[pixelIndex + 2];
            final gray = (0.299 * r + 0.587 * g + 0.114 * b).round();
            pixels.add(gray);
          }
        }
      }
    }

    if (pixels.length < 4) return 0.0;

    pixels.sort();
    final q1 = pixels[pixels.length ~/ 4];
    final q3 = pixels[(pixels.length * 3) ~/ 4];
    final contrast = (q3 - q1) / 255.0;

    return math.min(1.0, contrast);
  }

  /// Trouve les clusters de couleurs distinctives
  List<ColorCluster> _findColorClusters(
      Uint8List imageData, int width, int height) {
    final clusters = <ColorCluster>[];

    // Analyser par régions pour trouver les couleurs dominantes
    final regionSize = 32;
    final regionsX = width ~/ regionSize;
    final regionsY = height ~/ regionSize;

    for (int ry = 0; ry < regionsY; ry++) {
      for (int rx = 0; rx < regionsX; rx++) {
        final startX = rx * regionSize;
        final endX = math.min((rx + 1) * regionSize, width);
        final startY = ry * regionSize;
        final endY = math.min((ry + 1) * regionSize, height);

        final dominantColor =
            _getDominantColor(imageData, width, startX, endX, startY, endY);
        final distinctiveness = _calculateColorDistinctiveness(
            dominantColor, imageData, width, height);

        if (distinctiveness > 0.2) {
          final centerX = (startX + endX) / 2 / width;
          final centerY = (startY + endY) / 2 / height;
          final size = (endX - startX) * (endY - startY) / (width * height);

          clusters.add(ColorCluster(
            center: ui.Offset(centerX, centerY),
            bounds: ui.Rect.fromLTWH(startX / width, startY / height,
                (endX - startX) / width, (endY - startY) / height),
            dominantColor: dominantColor,
            distinctiveness: distinctiveness,
            size: size,
          ));
        }
      }
    }

    return clusters;
  }

  /// Détecte les formes circulaires
  List<CircularShape> _detectCircularShapes(
      Uint8List imageData, int width, int height) {
    final shapes = <CircularShape>[];

    // Rechercher des patterns circulaires à différentes échelles
    final scales = [16, 24, 32, 48]; // Différentes tailles de cercles

    for (final scale in scales) {
      final step = scale ~/ 2;

      for (int y = scale; y < height - scale; y += step) {
        for (int x = scale; x < width - scale; x += step) {
          final circularity =
              _calculateCircularity(imageData, width, x, y, scale);

          if (circularity > 0.3) {
            final centerX = x / width;
            final centerY = y / height;
            final size = (scale * 2) / math.min(width, height);

            shapes.add(CircularShape(
              center: ui.Offset(centerX, centerY),
              bounds: ui.Rect.fromLTWH(
                  (x - scale) / width,
                  (y - scale) / height,
                  (scale * 2) / width,
                  (scale * 2) / height),
              radius: scale / math.min(width, height),
              confidence: circularity,
              size: size,
            ));
          }
        }
      }
    }

    return shapes;
  }

  /// Calcule la circularité d'une région
  double _calculateCircularity(
      Uint8List imageData, int width, int centerX, int centerY, int radius) {
    final samples = <int>[];
    final edgeSamples = <int>[];

    // Échantillonner le centre et le bord du cercle
    for (int angle = 0; angle < 360; angle += 15) {
      final radians = angle * math.pi / 180;

      // Point au centre
      final centerPixel =
          _getPixelBrightness(imageData, width, centerX, centerY);
      if (centerPixel >= 0) samples.add(centerPixel);

      // Point sur le bord
      final edgeX = centerX + (radius * math.cos(radians)).round();
      final edgeY = centerY + (radius * math.sin(radians)).round();
      final edgePixel = _getPixelBrightness(imageData, width, edgeX, edgeY);
      if (edgePixel >= 0) edgeSamples.add(edgePixel);
    }

    if (samples.isEmpty || edgeSamples.isEmpty) return 0.0;

    // Calculer la différence entre centre et bord
    final centerMean = samples.reduce((a, b) => a + b) / samples.length;
    final edgeMean = edgeSamples.reduce((a, b) => a + b) / edgeSamples.length;
    final difference = (centerMean - edgeMean).abs() / 255.0;

    // Calculer la variance du bord (cercle parfait = faible variance)
    final edgeVariance = edgeSamples
            .map((s) => math.pow(s - edgeMean, 2))
            .reduce((a, b) => a + b) /
        edgeSamples.length;
    final normalizedVariance = math.min(1.0, edgeVariance / (255 * 255));

    // Score de circularité : différence élevée + faible variance = forme circulaire
    return difference * (1.0 - normalizedVariance);
  }

  /// Obtient la luminosité d'un pixel
  int _getPixelBrightness(Uint8List imageData, int width, int x, int y) {
    final pixelIndex = (y * width + x) * 4;
    if (pixelIndex + 2 >= imageData.length) return -1;

    final r = imageData[pixelIndex];
    final g = imageData[pixelIndex + 1];
    final b = imageData[pixelIndex + 2];
    return (0.299 * r + 0.587 * g + 0.114 * b).round();
  }

  /// Obtient la couleur dominante d'une région
  ui.Color _getDominantColor(Uint8List imageData, int width, int startX,
      int endX, int startY, int endY) {
    int totalR = 0, totalG = 0, totalB = 0, count = 0;

    for (int y = startY; y < endY; y += 2) {
      for (int x = startX; x < endX; x += 2) {
        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 < imageData.length) {
          totalR += imageData[pixelIndex];
          totalG += imageData[pixelIndex + 1];
          totalB += imageData[pixelIndex + 2];
          count++;
        }
      }
    }

    if (count == 0) return const ui.Color(0xFF808080);

    return ui.Color.fromARGB(
        255, totalR ~/ count, totalG ~/ count, totalB ~/ count);
  }

  /// Calcule la distinctivité d'une couleur par rapport à l'image globale
  double _calculateColorDistinctiveness(
      ui.Color color, Uint8List imageData, int width, int height) {
    // Échantillonner l'image globale pour comparer
    int similarPixels = 0;
    int totalSamples = 0;
    const threshold = 50; // Seuil de similarité de couleur

    for (int y = 0; y < height; y += 8) {
      for (int x = 0; x < width; x += 8) {
        final pixelIndex = (y * width + x) * 4;
        if (pixelIndex + 2 < imageData.length) {
          final r = imageData[pixelIndex];
          final g = imageData[pixelIndex + 1];
          final b = imageData[pixelIndex + 2];

          final distance = math.sqrt(
              math.pow(r - (color.r * 255.0).round(), 2) +
                  math.pow(g - (color.g * 255.0).round(), 2) +
                  math.pow(b - (color.b * 255.0).round(), 2));

          if (distance < threshold) similarPixels++;
          totalSamples++;
        }
      }
    }

    if (totalSamples == 0) return 0.0;

    final similarity = similarPixels / totalSamples;
    return 1.0 -
        similarity; // Plus la couleur est rare, plus elle est distinctive
  }

  /// Fusionne les sujets proches pour éviter les doublons
  List<DetectedSubject> _mergeNearbySubjects(List<DetectedSubject> subjects) {
    final merged = <DetectedSubject>[];
    final processed = <bool>[];

    for (int i = 0; i < subjects.length; i++) {
      processed.add(false);
    }

    for (int i = 0; i < subjects.length; i++) {
      if (processed[i]) continue;

      final current = subjects[i];
      final nearby = <DetectedSubject>[current];
      processed[i] = true;

      // Trouver les sujets proches
      for (int j = i + 1; j < subjects.length; j++) {
        if (processed[j]) continue;

        final distance = math.sqrt(
            math.pow(current.center.dx - subjects[j].center.dx, 2) +
                math.pow(current.center.dy - subjects[j].center.dy, 2));

        if (distance < 0.15) {
          // Seuil de proximité resserré pour éviter de fusionner la moitié de l'image
          nearby.add(subjects[j]);
          processed[j] = true;
        }
      }

      // Créer un sujet fusionné
      if (nearby.length == 1) {
        merged.add(current);
      } else {
        merged.add(_createMergedSubject(nearby));
      }
    }

    return merged;
  }

  /// Crée un sujet fusionné à partir de plusieurs sujets proches
  DetectedSubject _createMergedSubject(List<DetectedSubject> subjects) {
    double totalImportance = 0;
    double weightedX = 0, weightedY = 0;
    double minX = 1.0, minY = 1.0, maxX = 0.0, maxY = 0.0;
    double maxConfidence = 0.0;
    SubjectType bestType = subjects.first.type;

    // Use a power-weighted center to bias towards the MOST important subject
    // instead of a flat average of all clusters.
    double totalSaliencyWeight = 0;

    for (final subject in subjects) {
      totalImportance += subject.importance;
      
      // We use importance^2 to ensure the 'hero' subject dominates the center calculation
      final saliencyWeight = math.pow(subject.importance, 2.0);
      weightedX += subject.center.dx * saliencyWeight;
      weightedY += subject.center.dy * saliencyWeight;
      totalSaliencyWeight += saliencyWeight;

      minX = math.min(minX, subject.bounds.left);
      minY = math.min(minY, subject.bounds.top);
      maxX = math.max(maxX, subject.bounds.right);
      maxY = math.max(maxY, subject.bounds.bottom);

      if (subject.confidence > maxConfidence) {
        maxConfidence = subject.confidence;
        bestType = subject.type;
      }
    }

    return DetectedSubject(
      center: ui.Offset(
          weightedX / totalSaliencyWeight, weightedY / totalSaliencyWeight),
      bounds: ui.Rect.fromLTRB(minX, minY, maxX, maxY),
      type: bestType,
      confidence: maxConfidence,
      importance: totalImportance,
    );
  }

  /// Calcule le poids de position (centre = plus important)
  double _getPositionWeight(double x, double y) {
    final distanceFromCenter =
        math.sqrt(math.pow(x - 0.5, 2) + math.pow(y - 0.5, 2));
    // Aggressive center bias (matches SubjectDetectionCropAnalyzer)
    return math.max(0.1, 1.0 - (distanceFromCenter * 2.5));
  }

  /// Génère différentes stratégies de crop pour un sujet
  List<CropCoordinates> _generateCropStrategies(
      DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final strategies = <CropCoordinates>[];

    // Stratégie 1: Crop serré sur le sujet (pour les détails comme une tête)
    final tightCrop = _createTightCrop(subject, imageSize, targetAspectRatio);
    if (tightCrop != null) strategies.add(tightCrop);

    // Stratégie 2: Crop incluant le sujet avec contexte
    final contextCrop =
        _createContextCrop(subject, imageSize, targetAspectRatio);
    if (contextCrop != null) strategies.add(contextCrop);

    // Stratégie 3: Crop centré sur le sujet
    final centeredCrop =
        _createCenteredCrop(subject, imageSize, targetAspectRatio);
    if (centeredCrop != null) strategies.add(centeredCrop);

    return strategies;
  }

  /// Crée un crop serré sur le sujet
  CropCoordinates? _createTightCrop(
      DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final bounds = subject.bounds;
    // Stratégie 1: Crop serré sur le sujet
    final xMargin = bounds.width * 0.15;
    final yMargin = bounds.height * 0.15;

    final tightCropWidth = bounds.width + (xMargin * 2);
    final tightCropHeight = bounds.height + (yMargin * 2);
    
    // We want the relative width and height to result in an absolute crop 
    // that matches the targetAspectRatio.
    // targetAspectRatio = absolute width / absolute height
    // So targetAspectRatio = (relativeWidth * imageWidth) / (relativeHeight * imageHeight)
    // => relativeWidth / relativeHeight = targetAspectRatio / imageAspectRatio
    final imageAspectRatio = imageSize.width / imageSize.height;
    final targetRelativeRatio = targetAspectRatio / imageAspectRatio;
    
    double scaledWidth = tightCropWidth;
    double scaledHeight = tightCropHeight;
    
    if (scaledWidth / scaledHeight > targetRelativeRatio) {
      // It's too wide for the target aspect ratio, we must increase the height
      scaledHeight = scaledWidth / targetRelativeRatio;
    } else {
      // It's too tall, we must increase the width
      scaledWidth = scaledHeight * targetRelativeRatio;
    }
    
    // Check if the scaled width/height exceeds 1.0. If so, cap it while maintaining aspect ratio
    if (scaledWidth > 1.0 || scaledHeight > 1.0) {
        final scaleX = 1.0 / scaledWidth;
        final scaleY = 1.0 / scaledHeight;
        final minScale = math.min(scaleX, scaleY);
        scaledWidth *= minScale;
        scaledHeight *= minScale;
    }

    final cropX = math.max(0.0, math.min(1.0 - scaledWidth, subject.center.dx - scaledWidth / 2));
    final cropY = math.max(0.0, math.min(1.0 - scaledHeight, subject.center.dy - scaledHeight / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: scaledWidth,
      height: scaledHeight,
      confidence: subject.confidence * 0.9, // Légèrement réduit car plus risqué
      strategy: '${strategyName}_tight_scaled',
    );
  }

  /// Crée un crop avec contexte autour du sujet
  CropCoordinates? _createContextCrop(
      DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    // Positionner pour inclure le sujet avec du contexte
    final targetCenterX = subject.center.dx;
    final targetCenterY = subject.center.dy;

    final cropX =
        math.max(0.0, math.min(1.0 - cropWidth, targetCenterX - cropWidth / 2));
    final cropY = math.max(
        0.0, math.min(1.0 - cropHeight, targetCenterY - cropHeight / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: subject.confidence,
      strategy: '${strategyName}_context',
    );
  }

  /// Crée un crop centré sur le sujet
  CropCoordinates? _createCenteredCrop(
      DetectedSubject subject, ui.Size imageSize, double targetAspectRatio) {
    final cropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final cropHeight = _calculateCropHeight(imageSize, targetAspectRatio);

    final cropX = math.max(
        0.0, math.min(1.0 - cropWidth, subject.center.dx - cropWidth / 2));
    final cropY = math.max(
        0.0, math.min(1.0 - cropHeight, subject.center.dy - cropHeight / 2));

    return CropCoordinates(
      x: cropX,
      y: cropY,
      width: cropWidth,
      height: cropHeight,
      confidence: subject.confidence * 0.8,
      strategy: '${strategyName}_centered',
    );
  }

  /// Score un crop basé sur le sujet détecté
  Future<double> _scoreSubjectCrop(CropCoordinates crop,
      DetectedSubject subject, ui.Size imageSize, Uint8List imageData, double maxImportance, double targetAspectRatio) async {
    double score = 0.0;

    // 1. Inclusion du sujet (25%)
    score += _scoreSubjectInclusion(crop, subject) * 0.25;

    // 2. Qualité du sujet dans le crop (15%)
    score += _scoreSubjectQuality(crop, subject, imageSize, imageData) * 0.15;

    // 3. Composition générale (15%)
    score += _scoreComposition(crop, subject) * 0.15;

    // 4. Évitement des bords (5%) - réduit pour favoriser les grands crops
    score += _scoreEdgeAvoidance(crop) * 0.05;

    // 5. Importance relative du sujet (20%)
    final relativeImportance = maxImportance > 0 ? subject.importance / maxImportance : 1.0;
    score += relativeImportance * 0.20;

    // 6. Résolution / Taille du crop (10%) - Favorise légèrement les grands crops sans écraser les autres analyseurs
    final maxCropWidth = _calculateCropWidth(imageSize, targetAspectRatio);
    final maxCropHeight = _calculateCropHeight(imageSize, targetAspectRatio);
    final sizeRatio = (crop.width * crop.height) / (maxCropWidth * maxCropHeight);
    score += sizeRatio * 0.10;

    return score; // Don't cap at 1.0 here, let the highest score win!
  }

  /// Score l'inclusion du sujet dans le crop
  double _scoreSubjectInclusion(CropCoordinates crop, DetectedSubject subject) {
    final cropRect = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height);
    final intersection = cropRect.intersect(subject.bounds);

    if (intersection.isEmpty) return 0.0;

    final inclusionRatio = intersection.width *
        intersection.height /
        (subject.bounds.width * subject.bounds.height);

    return inclusionRatio;
  }

  /// Score la qualité du sujet dans le crop
  double _scoreSubjectQuality(CropCoordinates crop, DetectedSubject subject,
      ui.Size imageSize, Uint8List imageData) {
    // Bonus selon le type de sujet
    double typeBonus = 1.0;
    switch (subject.type) {
      case SubjectType.circularShape:
        typeBonus = 1.2; // Bonus réduit pour les formes circulaires (têtes, yeux) pour éviter l'inflation du score
        break;
      case SubjectType.highContrast:
        typeBonus = 1.1;
        break;
      case SubjectType.colorDistinct:
        typeBonus = 1.0;
        break;
    }

    return subject.confidence * typeBonus;
  }

  /// Score la composition du crop
  double _scoreComposition(CropCoordinates crop, DetectedSubject subject) {
    // Position du sujet dans le crop
    final subjectInCropX = (subject.center.dx - crop.x) / crop.width;
    final subjectInCropY = (subject.center.dy - crop.y) / crop.height;

    // Préférer les positions selon la règle des tiers
    final thirdPositions = [1 / 3, 2 / 3];
    double bestDistanceX = 1.0;
    double bestDistanceY = 1.0;

    for (final pos in thirdPositions) {
      bestDistanceX = math.min(bestDistanceX, (subjectInCropX - pos).abs());
      bestDistanceY = math.min(bestDistanceY, (subjectInCropY - pos).abs());
    }

    // Score basé sur la proximité aux points de règle des tiers
    final compositionScore = (1.0 - bestDistanceX) * (1.0 - bestDistanceY);
    return compositionScore;
  }

  /// Score l'évitement des bords
  double _scoreEdgeAvoidance(CropCoordinates crop) {
    // Pénaliser les crops qui touchent les bords
    double penalty = 0.0;

    if (crop.x <= 0.01) penalty += 0.2;
    if (crop.y <= 0.01) penalty += 0.2;
    if (crop.x + crop.width >= 0.99) penalty += 0.2;
    if (crop.y + crop.height >= 0.99) penalty += 0.2;

    return math.max(0.0, 1.0 - penalty);
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
      confidence: 0.3,
      strategy: strategyName,
    );
  }

  /// Calcule les métriques détaillées
  Future<Map<String, double>> _calculateMetrics(CropCoordinates crop,
      DetectedSubject? subject, ui.Size imageSize, Uint8List imageData) async {
    final metrics = <String, double>{
      'subjects_detected': subject != null ? 1.0 : 0.0,
      'crop_area_ratio': crop.width * crop.height,
    };

    if (subject != null) {
      metrics.addAll({
        'subject_confidence': subject.confidence,
        'subject_importance': subject.importance,
        'subject_inclusion': _scoreSubjectInclusion(crop, subject),
        'subject_type': subject.type.index.toDouble(),
        'subject_x': subject.bounds.left,
        'subject_y': subject.bounds.top,
        'subject_width': subject.bounds.width,
        'subject_height': subject.bounds.height,
      });
    }

    return metrics;
  }
}

/// Types de sujets détectés
enum SubjectType {
  highContrast,
  colorDistinct,
  circularShape,
}

/// Représente un sujet détecté dans l'image
class DetectedSubject {
  final ui.Offset center;
  final ui.Rect bounds;
  final SubjectType type;
  final double confidence;
  final double importance;

  DetectedSubject({
    required this.center,
    required this.bounds,
    required this.type,
    required this.confidence,
    required this.importance,
  });
}

/// Représente un cluster de couleur
class ColorCluster {
  final ui.Offset center;
  final ui.Rect bounds;
  final ui.Color dominantColor;
  final double distinctiveness;
  final double size;

  ColorCluster({
    required this.center,
    required this.bounds,
    required this.dominantColor,
    required this.distinctiveness,
    required this.size,
  });
}

/// Représente une forme circulaire détectée
class CircularShape {
  final ui.Offset center;
  final ui.Rect bounds;
  final double radius;
  final double confidence;
  final double size;

  CircularShape({
    required this.center,
    required this.bounds,
    required this.radius,
    required this.confidence,
    required this.size,
  });
}
