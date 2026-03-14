import 'dart:ui' as ui;
import '../models/crop_score.dart';
import '../models/crop_settings.dart';
import 'analysis_context.dart';
import 'analyzer_metadata.dart';

/// Abstract interface for crop analysis strategies
/// Maintains backward compatibility with v1 while adding v2 features
abstract class CropAnalyzer {
  /// Analyzes an image and returns a crop score
  ///
  /// [image] The source image to analyze
  /// [targetSize] The desired output size for the crop
  ///
  /// Returns a [CropScore] with the best crop area and confidence score
  Future<CropScore> analyze(ui.Image image, ui.Size targetSize);

  /// The name of this crop analysis strategy
  String get strategyName;

  /// The weight/importance of this strategy in the final decision (0.0 to 1.0)
  double get weight;

  /// Whether this analyzer is enabled by default
  bool get isEnabledByDefault => true;

  /// Minimum confidence threshold for this analyzer to be considered valid
  double get minConfidenceThreshold => 0.1;
}

/// Enhanced interface for Smart Crop v2 analyzers
/// Extends the basic CropAnalyzer with additional v2 features
abstract class CropAnalyzerV2 extends CropAnalyzer {
  /// The unique name identifier for this analyzer (v2)
  String get name => strategyName;

  /// The execution priority of this analyzer (higher values execute first) (v2)
  int get priority => 100;

  /// Whether this analyzer can analyze the given image and settings (v2)
  bool canAnalyze(ui.Image image, CropSettings settings) => true;

  /// Maximum processing time this analyzer should take (v2)
  Duration get maxProcessingTime => const Duration(milliseconds: 500);

  /// Metadata about this analyzer's capabilities and requirements (v2)
  AnalyzerMetadata get metadata => AnalyzerMetadata(
        description: 'V2 analyzer: $strategyName',
        version: '2.0.0',
      );

  /// Performance monitoring hook called before analysis starts (v2)
  void onAnalysisStart(String imageId, ui.Size imageSize, ui.Size targetSize) {}

  /// Performance monitoring hook called after analysis completes (v2)
  void onAnalysisComplete(
      String imageId, Duration processingTime, bool success) {}

  /// Performance monitoring hook called when analysis fails (v2)
  void onAnalysisError(String imageId, Object error, StackTrace stackTrace) {}

  /// Validates that the analyzer is properly configured (v2)
  bool validate() => true;

  /// Cleanup resources when analyzer is no longer needed (v2)
  void dispose() {}

  /// V2 analyze method with context
  Future<CropScore> analyzeWithContext(
      ui.Image image, ui.Size targetSize, AnalysisContext context) {
    // Default implementation delegates to legacy analyze method
    return analyze(image, targetSize);
  }
}

/// Base class providing common functionality for v2 crop analyzers
abstract class BaseCropAnalyzer extends CropAnalyzerV2 {
  final String _name;
  final int _priority;
  final double _weight;
  final Duration _maxProcessingTime;
  final AnalyzerMetadata _metadata;

  BaseCropAnalyzer({
    required String name,
    required int priority,
    required double weight,
    Duration maxProcessingTime = const Duration(milliseconds: 500),
    required AnalyzerMetadata metadata,
  })  : _name = name,
        _priority = priority,
        _weight = weight,
        _maxProcessingTime = maxProcessingTime,
        _metadata = metadata;

  @override
  String get name => _name;

  @override
  String get strategyName => _name;

  @override
  int get priority => _priority;

  @override
  double get weight => _weight;

  @override
  Duration get maxProcessingTime => _maxProcessingTime;

  @override
  AnalyzerMetadata get metadata => _metadata;

  @override
  bool canAnalyze(ui.Image image, CropSettings settings) {
    // Default implementation - can analyze any image
    return image.width > 0 && image.height > 0;
  }

  @override
  bool validate() {
    return name.isNotEmpty &&
        priority >= 0 &&
        weight >= 0.0 &&
        weight <= 1.0 &&
        maxProcessingTime.inMilliseconds > 0;
  }

  @override
  void onAnalysisStart(String imageId, ui.Size imageSize, ui.Size targetSize) {
    // Default implementation - no-op
  }

  @override
  void onAnalysisComplete(
      String imageId, Duration processingTime, bool success) {
    // Default implementation - no-op
  }

  @override
  void onAnalysisError(String imageId, Object error, StackTrace stackTrace) {
    // Default implementation - no-op
  }

  @override
  void dispose() {
    // Default implementation - no-op
  }

  @override
  Future<CropScore> analyzeWithContext(
      ui.Image image, ui.Size targetSize, AnalysisContext context) {
    // Default implementation delegates to legacy analyze method
    return analyze(image, targetSize);
  }
}
