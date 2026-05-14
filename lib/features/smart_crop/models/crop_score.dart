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
  final Map<String, dynamic> metrics;

  const CropScore({
    required this.coordinates,
    required this.score,
    required this.strategy,
    required this.metrics,
  });

  /// Factory for an empty score
  factory CropScore.empty(String strategy) => CropScore(
    coordinates: CropCoordinates.empty(strategy),
    score: 0.0,
    strategy: strategy,
    metrics: const {},
  );

  /// Creates a copy with modified values
  CropScore copyWith({
    CropCoordinates? coordinates,
    double? score,
    String? strategy,
    Map<String, dynamic>? metrics,
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

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'coordinates': coordinates.toJson(),
      'score': score,
      'strategy': strategy,
      'metrics': metrics,
    };
  }

  /// Creates from JSON
  factory CropScore.fromJson(Map<String, dynamic> json) {
    return CropScore(
      coordinates: CropCoordinates.fromJson(json['coordinates']),
      score: (json['score'] ?? 0.0).toDouble(),
      strategy: json['strategy'] ?? 'unknown',
      metrics: Map<String, dynamic>.from(json['metrics'] ?? {}),
    );
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
  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
