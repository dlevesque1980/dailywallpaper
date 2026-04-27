import 'dart:convert';
import 'crop_coordinates.dart';
import 'crop_score.dart';

/// Performance metrics for crop analysis
class PerformanceMetrics {
  /// Total analysis time
  final Duration totalTime;

  /// Time spent by each analyzer
  final Map<String, Duration> analyzerTimes;

  /// Memory usage during analysis (in bytes)
  final int memoryUsage;

  /// Number of analyzers that ran
  final int analyzersExecuted;

  /// Number of analyzers that were skipped
  final int analyzersSkipped;

  /// Cache hit rate (0.0 to 1.0)
  final double cacheHitRate;

  const PerformanceMetrics({
    required this.totalTime,
    required this.analyzerTimes,
    required this.memoryUsage,
    required this.analyzersExecuted,
    required this.analyzersSkipped,
    required this.cacheHitRate,
  });

  /// Creates a copy with modified values
  PerformanceMetrics copyWith({
    Duration? totalTime,
    Map<String, Duration>? analyzerTimes,
    int? memoryUsage,
    int? analyzersExecuted,
    int? analyzersSkipped,
    double? cacheHitRate,
  }) {
    return PerformanceMetrics(
      totalTime: totalTime ?? this.totalTime,
      analyzerTimes: analyzerTimes ?? this.analyzerTimes,
      memoryUsage: memoryUsage ?? this.memoryUsage,
      analyzersExecuted: analyzersExecuted ?? this.analyzersExecuted,
      analyzersSkipped: analyzersSkipped ?? this.analyzersSkipped,
      cacheHitRate: cacheHitRate ?? this.cacheHitRate,
    );
  }

  /// Converts to JSON for serialization
  Map<String, dynamic> toJson() {
    return {
      'totalTime': totalTime.inMilliseconds,
      'analyzerTimes':
          analyzerTimes.map((k, v) => MapEntry(k, v.inMilliseconds)),
      'memoryUsage': memoryUsage,
      'analyzersExecuted': analyzersExecuted,
      'analyzersSkipped': analyzersSkipped,
      'cacheHitRate': cacheHitRate,
    };
  }

  /// Creates from JSON
  factory PerformanceMetrics.fromJson(Map<String, dynamic> json) {
    return PerformanceMetrics(
      totalTime: Duration(milliseconds: json['totalTime'] ?? 0),
      analyzerTimes: (json['analyzerTimes'] as Map<String, dynamic>? ?? {})
          .map((k, v) => MapEntry(k, Duration(milliseconds: v as int))),
      memoryUsage: json['memoryUsage'] ?? 0,
      analyzersExecuted: json['analyzersExecuted'] ?? 0,
      analyzersSkipped: json['analyzersSkipped'] ?? 0,
      cacheHitRate: (json['cacheHitRate'] ?? 0.0).toDouble(),
    );
  }

  @override
  String toString() {
    return 'PerformanceMetrics(totalTime: ${totalTime.inMilliseconds}ms, '
        'analyzersExecuted: $analyzersExecuted, memoryUsage: ${memoryUsage}B)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is PerformanceMetrics &&
        other.totalTime == totalTime &&
        _mapEquals(other.analyzerTimes, analyzerTimes) &&
        other.memoryUsage == memoryUsage &&
        other.analyzersExecuted == analyzersExecuted &&
        other.analyzersSkipped == analyzersSkipped &&
        other.cacheHitRate == cacheHitRate;
  }

  @override
  int get hashCode {
    return Object.hash(totalTime, analyzerTimes, memoryUsage, analyzersExecuted,
        analyzersSkipped, cacheHitRate);
  }

  /// Helper method to compare Duration maps
  bool _mapEquals(Map<String, Duration> a, Map<String, Duration> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}

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

  /// Metadata from analyzers including performance metrics
  final Map<String, dynamic> analyzerMetadata;

  /// Performance metrics for the analysis
  final PerformanceMetrics performanceMetrics;

  /// Detailed scoring breakdown by analyzer
  final Map<String, double> scoringBreakdown;

  const CropResult({
    required this.bestCrop,
    required this.allScores,
    required this.processingTime,
    required this.fromCache,
    required this.analyzerMetadata,
    required this.performanceMetrics,
    required this.scoringBreakdown,
  });

  /// Creates a copy with modified values
  CropResult copyWith({
    CropCoordinates? bestCrop,
    List<CropScore>? allScores,
    Duration? processingTime,
    bool? fromCache,
    Map<String, dynamic>? analyzerMetadata,
    PerformanceMetrics? performanceMetrics,
    Map<String, double>? scoringBreakdown,
  }) {
    return CropResult(
      bestCrop: bestCrop ?? this.bestCrop,
      allScores: allScores ?? this.allScores,
      processingTime: processingTime ?? this.processingTime,
      fromCache: fromCache ?? this.fromCache,
      analyzerMetadata: analyzerMetadata ?? this.analyzerMetadata,
      performanceMetrics: performanceMetrics ?? this.performanceMetrics,
      scoringBreakdown: scoringBreakdown ?? this.scoringBreakdown,
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
        processingTime.inMilliseconds >= 0 &&
        scoringBreakdown.values.every((score) => score >= 0.0 && score <= 1.0);
  }

  /// Gets analyzer metadata for a specific analyzer
  Map<String, dynamic>? getAnalyzerMetadata(String analyzerName) {
    return analyzerMetadata[analyzerName] as Map<String, dynamic>?;
  }

  /// Gets the score breakdown for a specific analyzer
  double? getAnalyzerScore(String analyzerName) {
    return scoringBreakdown[analyzerName];
  }

  /// Gets the top performing analyzers by score
  List<MapEntry<String, double>> get topAnalyzers {
    final entries = scoringBreakdown.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  /// Converts to JSON for caching/serialization
  Map<String, dynamic> toJson() {
    return {
      'bestCrop': bestCrop.toJson(),
      'allScores': allScores.map((score) => score.toJson()).toList(),
      'processingTime': processingTime.inMilliseconds,
      'fromCache': fromCache,
      'analyzerMetadata': analyzerMetadata,
      'performanceMetrics': performanceMetrics.toJson(),
      'scoringBreakdown': scoringBreakdown,
    };
  }

  /// Creates from JSON
  factory CropResult.fromJson(Map<String, dynamic> json) {
    return CropResult(
      bestCrop: CropCoordinates.fromJson(json['bestCrop']),
      allScores: (json['allScores'] as List)
          .map((score) => CropScore.fromJson(score))
          .toList(),
      processingTime: Duration(milliseconds: json['processingTime'] ?? 0),
      fromCache: json['fromCache'] ?? false,
      analyzerMetadata:
          Map<String, dynamic>.from(json['analyzerMetadata'] ?? {}),
      performanceMetrics:
          PerformanceMetrics.fromJson(json['performanceMetrics'] ?? {}),
      scoringBreakdown:
          Map<String, double>.from(json['scoringBreakdown'] ?? {}),
    );
  }

  /// Serializes to JSON string
  String serialize() {
    return jsonEncode(toJson());
  }

  /// Deserializes from JSON string
  factory CropResult.deserialize(String jsonString) {
    return CropResult.fromJson(jsonDecode(jsonString));
  }

  @override
  String toString() {
    return 'CropResult(bestCrop: $bestCrop, scoresCount: ${allScores.length}, '
        'processingTime: ${processingTime.inMilliseconds}ms, fromCache: $fromCache, '
        'analyzers: ${scoringBreakdown.keys.length}, performance: $performanceMetrics)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropResult &&
        other.bestCrop == bestCrop &&
        _listEquals(other.allScores, allScores) &&
        other.processingTime == processingTime &&
        other.fromCache == fromCache &&
        _mapEquals(other.analyzerMetadata, analyzerMetadata) &&
        other.performanceMetrics == performanceMetrics &&
        _mapEquals(other.scoringBreakdown, scoringBreakdown);
  }

  @override
  int get hashCode {
    return Object.hash(bestCrop, allScores, processingTime, fromCache,
        analyzerMetadata, performanceMetrics, scoringBreakdown);
  }

  /// Helper method to compare lists
  bool _listEquals(List<CropScore> a, List<CropScore> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
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
