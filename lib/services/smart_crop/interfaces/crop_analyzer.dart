import 'dart:ui' as ui;
import '../models/crop_score.dart';

/// Abstract interface for crop analysis strategies
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