import '../models/crop_settings.dart';

/// Context information provided to analyzers during crop analysis
class AnalysisContext {
  /// Unique identifier for the image being analyzed
  final String imageId;

  /// Crop settings for this analysis
  final CropSettings settings;

  /// Additional metadata that may be useful for analysis
  final Map<String, dynamic> metadata;

  /// Timestamp when analysis started
  final DateTime startTime;

  /// Whether this is a retry attempt
  final bool isRetry;

  /// Previous analysis results if this is a retry
  final Map<String, dynamic>? previousResults;

  AnalysisContext({
    required this.imageId,
    required this.settings,
    required this.metadata,
    DateTime? startTime,
    this.isRetry = false,
    this.previousResults,
  }) : startTime = startTime ?? DateTime.now();

  /// Creates a copy with modified values
  AnalysisContext copyWith({
    String? imageId,
    CropSettings? settings,
    Map<String, dynamic>? metadata,
    DateTime? startTime,
    bool? isRetry,
    Map<String, dynamic>? previousResults,
  }) {
    return AnalysisContext(
      imageId: imageId ?? this.imageId,
      settings: settings ?? this.settings,
      metadata: metadata ?? this.metadata,
      startTime: startTime ?? this.startTime,
      isRetry: isRetry ?? this.isRetry,
      previousResults: previousResults ?? this.previousResults,
    );
  }

  /// Gets elapsed time since analysis started
  Duration get elapsedTime => DateTime.now().difference(startTime);

  /// Checks if analysis has exceeded the maximum allowed time
  bool get hasExceededTimeout => elapsedTime > settings.maxProcessingTime;

  /// Gets a specific metadata value with type safety
  T? getMetadata<T>(String key) {
    final value = metadata[key];
    return value is T ? value : null;
  }

  /// Adds metadata to the context
  AnalysisContext withMetadata(String key, dynamic value) {
    final newMetadata = Map<String, dynamic>.from(metadata);
    newMetadata[key] = value;
    return copyWith(metadata: newMetadata);
  }

  @override
  String toString() {
    return 'AnalysisContext(imageId: $imageId, elapsedTime: ${elapsedTime.inMilliseconds}ms, isRetry: $isRetry)';
  }
}
