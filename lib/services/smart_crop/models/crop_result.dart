import 'crop_coordinates.dart';
import 'crop_score.dart';

/// Represents the complete result of a crop analysis operation
class CropResult {
  /// The best crop coordinates selected from all strategies
  final CropCoordinates bestCrop;
  
  /// All crop scores from different strategies
  final List<CropScore> allScores;
  
  /// Time taken to process the crop analysis
  final Duration processingTime;
  
  /// Whether this result came from cache
  final bool fromCache;

  const CropResult({
    required this.bestCrop,
    required this.allScores,
    required this.processingTime,
    required this.fromCache,
  });

  /// Creates a copy with modified values
  CropResult copyWith({
    CropCoordinates? bestCrop,
    List<CropScore>? allScores,
    Duration? processingTime,
    bool? fromCache,
  }) {
    return CropResult(
      bestCrop: bestCrop ?? this.bestCrop,
      allScores: allScores ?? this.allScores,
      processingTime: processingTime ?? this.processingTime,
      fromCache: fromCache ?? this.fromCache,
    );
  }

  /// Gets the highest scoring crop from all strategies
  CropScore? get bestScore {
    if (allScores.isEmpty) return null;
    return allScores.reduce((a, b) => a.score > b.score ? a : b);
  }

  /// Gets scores sorted by score (highest first)
  List<CropScore> get sortedScores {
    final sorted = List<CropScore>.from(allScores);
    sorted.sort((a, b) => b.score.compareTo(a.score));
    return sorted;
  }

  /// Validates that the result is valid
  bool get isValid {
    return bestCrop.isValid && 
           allScores.every((score) => score.isValid) &&
           processingTime.inMilliseconds >= 0;
  }

  @override
  String toString() {
    return 'CropResult(bestCrop: $bestCrop, scoresCount: ${allScores.length}, processingTime: ${processingTime.inMilliseconds}ms, fromCache: $fromCache)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropResult &&
           other.bestCrop == bestCrop &&
           _listEquals(other.allScores, allScores) &&
           other.processingTime == processingTime &&
           other.fromCache == fromCache;
  }

  @override
  int get hashCode {
    return Object.hash(bestCrop, allScores, processingTime, fromCache);
  }

  /// Helper method to compare lists
  bool _listEquals(List<CropScore> a, List<CropScore> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}