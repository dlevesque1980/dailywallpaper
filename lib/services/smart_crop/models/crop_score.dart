import 'crop_coordinates.dart';

/// Represents a scored crop result from a specific analysis strategy
class CropScore {
  /// The crop coordinates
  final CropCoordinates coordinates;
  
  /// Overall score for this crop (0.0 to 1.0, higher is better)
  final double score;
  
  /// Strategy that generated this score
  final String strategy;
  
  /// Detailed metrics from the analysis
  final Map<String, double> metrics;

  const CropScore({
    required this.coordinates,
    required this.score,
    required this.strategy,
    required this.metrics,
  });

  /// Creates a copy with modified values
  CropScore copyWith({
    CropCoordinates? coordinates,
    double? score,
    String? strategy,
    Map<String, double>? metrics,
  }) {
    return CropScore(
      coordinates: coordinates ?? this.coordinates,
      score: score ?? this.score,
      strategy: strategy ?? this.strategy,
      metrics: metrics ?? this.metrics,
    );
  }

  /// Validates that the score is within valid bounds
  bool get isValid {
    return score >= 0.0 && score <= 1.0 && coordinates.isValid;
  }

  @override
  String toString() {
    return 'CropScore(score: $score, strategy: $strategy, coordinates: $coordinates, metrics: $metrics)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropScore &&
           other.coordinates == coordinates &&
           other.score == score &&
           other.strategy == strategy &&
           _mapEquals(other.metrics, metrics);
  }

  @override
  int get hashCode {
    return Object.hash(coordinates, score, strategy, metrics);
  }

  /// Helper method to compare maps
  bool _mapEquals(Map<String, double> a, Map<String, double> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}