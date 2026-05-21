/// Enum for crop aggressiveness levels
enum CropAggressiveness {
  /// Conservative cropping - minimal changes, prefer center crops
  conservative,

  /// Balanced cropping - moderate analysis, good balance of safety and optimization
  balanced,

  /// Aggressive cropping - maximum analysis, prioritize optimal composition
  aggressive,
}

/// Configuration settings for smart crop analysis
class CropSettings {
  /// Overall aggressiveness of the cropping algorithm
  final CropAggressiveness aggressiveness;

  /// Whether to enable rule of thirds analysis
  final bool enableRuleOfThirds;

  /// Whether to enable entropy-based analysis
  final bool enableEntropyAnalysis;

  /// Whether to enable edge detection analysis
  final bool enableEdgeDetection;

  /// Whether to enable center-weighted analysis
  final bool enableCenterWeighting;

  /// Maximum time allowed for processing
  final Duration maxProcessingTime;

  /// Whether to enable battery optimization
  final bool enableBatteryOptimization;

  /// Maximum number of crop candidates to generate
  final int? maxCropCandidates;

  const CropSettings({
    this.aggressiveness = CropAggressiveness.balanced,
    this.enableRuleOfThirds = true,
    this.enableEntropyAnalysis = true,
    this.enableEdgeDetection = false,
    this.enableCenterWeighting = true,
    this.maxProcessingTime = const Duration(seconds: 2),
    this.enableBatteryOptimization = false,
    this.maxCropCandidates = 10,
  });

  /// Default settings for the smart crop system
  static const CropSettings defaultSettings = CropSettings(
    aggressiveness: CropAggressiveness.balanced,
    enableRuleOfThirds: true,
    enableEntropyAnalysis: true,
    enableEdgeDetection: false,
    enableCenterWeighting: true,
    maxProcessingTime: Duration(seconds: 2),
    enableBatteryOptimization: false,
    maxCropCandidates: 10,
  );
}
