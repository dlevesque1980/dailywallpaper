import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'bird_feature_detector.dart';

class BirdScoringLogic {
  static double scoreBirdCrop(CropCoordinates crop, DetectedBird bird) {
    double score = 0.0;
    score += _scoreBirdInclusion(crop, bird) * 0.35;
    if (bird.hasHead) {
      score += _scoreHeadQuality(crop, bird) * 0.3;
    } else {
      score += _scoreBirdCenterPosition(crop, bird) * 0.3;
    }
    score += _scoreBirdComposition(crop, bird) * 0.2;
    score += _scoreEdgeAvoidance(crop) * 0.15;
    return math.min(1.0, score);
  }

  static double _scoreBirdInclusion(CropCoordinates crop, DetectedBird bird) {
    final cropRect = ui.Rect.fromLTWH(crop.x, crop.y, crop.width, crop.height);
    final intersection = cropRect.intersect(bird.bounds);
    if (intersection.isEmpty) return 0.0;
    return intersection.width * intersection.height / (bird.bounds.width * bird.bounds.height);
  }

  static double _scoreHeadQuality(CropCoordinates crop, DetectedBird bird) {
    final headInCropY = (bird.center.dy - crop.y) / crop.height;
    double headPositionScore = headInCropY > 0.6 ? math.max(0.3, 1.0 - (headInCropY - 0.6) * 2) : 1.0;
    return bird.confidence * headPositionScore * (bird.hasBeak ? 1.2 : 1.0);
  }

  static double _scoreBirdCenterPosition(CropCoordinates crop, DetectedBird bird) {
    final dist = (ui.Offset((bird.center.dx - crop.x) / crop.width, (bird.center.dy - crop.y) / crop.height) - const ui.Offset(0.5, 0.5)).distance;
    return math.max(0.2, 1.0 - dist);
  }

  static double _scoreBirdComposition(CropCoordinates crop, DetectedBird bird) {
    final birdX = (bird.center.dx - crop.x) / crop.width;
    final birdY = (bird.center.dy - crop.y) / crop.height;
    final thirdPoints = [1 / 3, 2 / 3];
    double bestDist = double.infinity;
    for (final tx in thirdPoints) {
      for (final ty in thirdPoints) {
        bestDist = math.min(bestDist, (ui.Offset(birdX, birdY) - ui.Offset(tx, ty)).distance);
      }
    }
    return math.max(0.1, 1.0 - bestDist * 1.5);
  }

  static double _scoreEdgeAvoidance(CropCoordinates crop) {
    final distToEdge = [crop.x, 1.0 - (crop.x + crop.width), crop.y, 1.0 - (crop.y + crop.height)].reduce(math.min);
    return math.min(1.0, distToEdge * 5.0);
  }
}
