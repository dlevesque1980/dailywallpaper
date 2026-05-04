import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_score.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/registry/analyzer_registry.dart';
import 'package:dailywallpaper/services/smart_crop/interfaces/crop_analyzer.dart';

class ScoringEngine {
  final AnalyzerRegistry _registry;

  ScoringEngine(this._registry);

  CropCoordinates selectBestCrop(List<CropScore> scores, CropSettings settings) {
    if (scores.isEmpty) {
      throw StateError('No valid crop scores available');
    }

    final weightedScores = <CropScore>[];

    for (final score in scores) {
      CropAnalyzer? analyzer = _registry.getAnalyzer(score.strategy);
      
      if (analyzer == null) {
        for (final a in _registry.getAllAnalyzers()) {
          if (score.strategy.startsWith(a.strategyName)) {
            analyzer = a;
            break;
          }
        }
      }

      if (analyzer != null) {
        double aggressivenessMultiplier = 1.0;
        final baseStrategy = analyzer.strategyName;

        if (baseStrategy == 'ml_subject_detection' || baseStrategy == 'subject_detection') {
          switch (settings.aggressiveness) {
            case CropAggressiveness.conservative:
              aggressivenessMultiplier = 1.0;
              break;
            case CropAggressiveness.balanced:
              aggressivenessMultiplier = 1.1;
              break;
            case CropAggressiveness.aggressive:
              aggressivenessMultiplier = 1.2;
              break;
          }
        }

        final weightedScore =
            score.score * analyzer.weight * aggressivenessMultiplier;

        weightedScores.add(score.copyWith(
          score: weightedScore,
          metrics: {
            ...score.metrics,
            'weighted_score': weightedScore,
            'original_score': score.score,
            'analyzer_weight': analyzer.weight,
            'aggressiveness_multiplier': aggressivenessMultiplier,
          },
        ));
      } else {
        weightedScores.add(score);
      }
    }

    weightedScores.sort((a, b) => b.score.compareTo(a.score));

    final bestCandidate = weightedScores.first;
    final centerCandidate = weightedScores.firstWhere(
      (s) => s.strategy == 'center_weighted',
      orElse: () => bestCandidate,
    );

    if (centerCandidate.strategy == 'center_weighted' &&
        bestCandidate.strategy != 'center_weighted' &&
        bestCandidate.score < centerCandidate.score * 1.15) {
      return centerCandidate.coordinates.copyWith(
        strategy: '${centerCandidate.strategy}_consensus',
      );
    }

    return bestCandidate.coordinates;
  }
}
