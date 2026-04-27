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
  final int maxCropCandidates;

  /// Whether to enable automatic scaling to fit the main subject
  final bool enableSubjectScaling;

  /// Minimum subject coverage to consider the crop valid before scaling (0.0 to 1.0)
  final double minSubjectCoverage;

  /// Maximum scale factor allowed when zooming out to fit the subject
  final double maxScaleFactor;

  /// Whether to enable ML Kit subject detection for crop analysis
  final bool enableMlSubjectDetection;

  /// When true, if the subject is wider than a portrait strip allows, the crop
  /// window is expanded and blurred letterbox bars fill the empty sides.
  /// Recommended for Bing/NASA editorial shots; leave false for Pexels.
  final bool allowLetterbox;

  const CropSettings({
    this.aggressiveness = CropAggressiveness.balanced,
    this.enableRuleOfThirds = true,
    this.enableEntropyAnalysis = true,
    this.enableEdgeDetection = false,
    this.enableCenterWeighting = true,
    this.maxProcessingTime = const Duration(seconds: 2),
    this.enableBatteryOptimization = false,
    this.maxCropCandidates = 10,
    this.enableSubjectScaling = true,
    this.minSubjectCoverage = 0.85,
    this.maxScaleFactor = 2.0,
    this.enableMlSubjectDetection = true,
    this.allowLetterbox = false,
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
    enableSubjectScaling: true,
    minSubjectCoverage: 0.85,
    maxScaleFactor: 2.0,
    enableMlSubjectDetection: true,
    allowLetterbox: false,
  );

  /// Optimized settings for landscape images (like Bing wallpapers)
  static const CropSettings landscapeOptimized = CropSettings(
    aggressiveness: CropAggressiveness.aggressive,
    enableRuleOfThirds: true,
    enableEntropyAnalysis: true,
    enableEdgeDetection: true,
    enableCenterWeighting: false,
    maxProcessingTime: Duration(seconds: 3),
    enableBatteryOptimization: false,
    maxCropCandidates: 15,
    enableSubjectScaling: true,
    minSubjectCoverage: 0.65, // Softer — allows wider crops with letterbox
    maxScaleFactor: 2.5,
    enableMlSubjectDetection: true,
    allowLetterbox: true, // Bing/NASA editorial shots look great with blurred fill
  );

  /// Conservative settings for portrait or complex images
  static const CropSettings conservative = CropSettings(
    aggressiveness: CropAggressiveness.conservative,
    enableRuleOfThirds: true,
    enableEntropyAnalysis: false,
    enableEdgeDetection: false,
    enableCenterWeighting: true,
    maxProcessingTime: Duration(seconds: 1),
    enableBatteryOptimization: true,
    maxCropCandidates: 5,
    enableSubjectScaling: false,
    minSubjectCoverage: 0.9,
    maxScaleFactor: 1.2,
    enableMlSubjectDetection: false,
    allowLetterbox: false,
  );

  /// Balanced settings for general use
  static const CropSettings balanced = CropSettings(
    aggressiveness: CropAggressiveness.balanced,
    enableRuleOfThirds: true,
    enableEntropyAnalysis: true,
    enableEdgeDetection: false,
    enableCenterWeighting: true,
    maxProcessingTime: Duration(seconds: 2),
    enableBatteryOptimization: false,
    maxCropCandidates: 10,
    enableSubjectScaling: true,
    minSubjectCoverage: 0.85,
    maxScaleFactor: 2.0,
    enableMlSubjectDetection: true,
    allowLetterbox: false,
  );

  /// Aggressive settings for maximum optimization
  static const CropSettings aggressive = CropSettings(
    aggressiveness: CropAggressiveness.aggressive,
    enableRuleOfThirds: true,
    enableEntropyAnalysis: true,
    enableEdgeDetection: true,
    enableCenterWeighting: true,
    maxProcessingTime: Duration(seconds: 4),
    enableBatteryOptimization: false,
    maxCropCandidates: 20,
    enableSubjectScaling: true,
    minSubjectCoverage: 0.8,
    maxScaleFactor: 3.0,
    enableMlSubjectDetection: true,
    allowLetterbox: false,
  );

  /// Creates a copy with modified values
  CropSettings copyWith({
    CropAggressiveness? aggressiveness,
    bool? enableRuleOfThirds,
    bool? enableEntropyAnalysis,
    bool? enableEdgeDetection,
    bool? enableCenterWeighting,
    Duration? maxProcessingTime,
    bool? enableBatteryOptimization,
    int? maxCropCandidates,
    bool? enableSubjectScaling,
    double? minSubjectCoverage,
    double? maxScaleFactor,
    bool? enableMlSubjectDetection,
    bool? allowLetterbox,
  }) {
    return CropSettings(
      aggressiveness: aggressiveness ?? this.aggressiveness,
      enableRuleOfThirds: enableRuleOfThirds ?? this.enableRuleOfThirds,
      enableEntropyAnalysis:
          enableEntropyAnalysis ?? this.enableEntropyAnalysis,
      enableEdgeDetection: enableEdgeDetection ?? this.enableEdgeDetection,
      enableCenterWeighting:
          enableCenterWeighting ?? this.enableCenterWeighting,
      maxProcessingTime: maxProcessingTime ?? this.maxProcessingTime,
      enableBatteryOptimization:
          enableBatteryOptimization ?? this.enableBatteryOptimization,
      maxCropCandidates: maxCropCandidates ?? this.maxCropCandidates,
      enableSubjectScaling: enableSubjectScaling ?? this.enableSubjectScaling,
      minSubjectCoverage: minSubjectCoverage ?? this.minSubjectCoverage,
      maxScaleFactor: maxScaleFactor ?? this.maxScaleFactor,
      enableMlSubjectDetection:
          enableMlSubjectDetection ?? this.enableMlSubjectDetection,
      allowLetterbox: allowLetterbox ?? this.allowLetterbox,
    );
  }

  /// Gets the list of enabled strategies
  List<String> get enabledStrategies {
    final strategies = <String>[];
    if (enableRuleOfThirds) strategies.add('rule_of_thirds');
    if (enableEntropyAnalysis) strategies.add('entropy');
    if (enableEdgeDetection) strategies.add('edge_detection');
    if (enableCenterWeighting) strategies.add('center_weighted');
    return strategies;
  }

  /// Validates that settings are valid
  bool get isValid {
    return maxProcessingTime.inMilliseconds > 0 && enabledStrategies.isNotEmpty;
  }

  @override
  String toString() {
    return 'CropSettings(aggressiveness: $aggressiveness, enabledStrategies: $enabledStrategies, scaling: $enableSubjectScaling, maxProcessingTime: ${maxProcessingTime.inMilliseconds}ms)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CropSettings &&
        other.aggressiveness == aggressiveness &&
        other.enableRuleOfThirds == enableRuleOfThirds &&
        other.enableEntropyAnalysis == enableEntropyAnalysis &&
        other.enableEdgeDetection == enableEdgeDetection &&
        other.enableCenterWeighting == enableCenterWeighting &&
        other.maxProcessingTime == maxProcessingTime &&
        other.enableBatteryOptimization == enableBatteryOptimization &&
        other.maxCropCandidates == maxCropCandidates &&
        other.enableSubjectScaling == enableSubjectScaling &&
        other.minSubjectCoverage == minSubjectCoverage &&
        other.maxScaleFactor == maxScaleFactor &&
        other.enableMlSubjectDetection == enableMlSubjectDetection &&
        other.allowLetterbox == allowLetterbox;
  }

  @override
  int get hashCode {
    return Object.hash(
      aggressiveness,
      enableRuleOfThirds,
      enableEntropyAnalysis,
      enableEdgeDetection,
      enableCenterWeighting,
      maxProcessingTime,
      enableBatteryOptimization,
      maxCropCandidates,
      enableSubjectScaling,
      minSubjectCoverage,
      maxScaleFactor,
      enableMlSubjectDetection,
      allowLetterbox,
    );
  }

  /// Converts settings to a Map for serialization
  Map<String, dynamic> toMap() {
    return {
      'aggressiveness': aggressiveness.index,
      'enableRuleOfThirds': enableRuleOfThirds,
      'enableEntropyAnalysis': enableEntropyAnalysis,
      'enableEdgeDetection': enableEdgeDetection,
      'enableCenterWeighting': enableCenterWeighting,
      'maxProcessingTimeMs': maxProcessingTime.inMilliseconds,
      'enableBatteryOptimization': enableBatteryOptimization,
      'maxCropCandidates': maxCropCandidates,
      'enableSubjectScaling': enableSubjectScaling,
      'minSubjectCoverage': minSubjectCoverage,
      'maxScaleFactor': maxScaleFactor,
      'enableMlSubjectDetection': enableMlSubjectDetection,
      'allowLetterbox': allowLetterbox,
    };
  }

  /// Creates settings from a Map (deserialization)
  factory CropSettings.fromMap(Map<String, dynamic> map) {
    return CropSettings(
      aggressiveness: CropAggressiveness
          .values[map['aggressiveness'] ?? CropAggressiveness.balanced.index],
      enableRuleOfThirds: map['enableRuleOfThirds'] ?? true,
      enableEntropyAnalysis: map['enableEntropyAnalysis'] ?? true,
      enableEdgeDetection: map['enableEdgeDetection'] ?? false,
      enableCenterWeighting: map['enableCenterWeighting'] ?? true,
      maxProcessingTime:
          Duration(milliseconds: map['maxProcessingTimeMs'] ?? 2000),
      enableBatteryOptimization: map['enableBatteryOptimization'] ?? false,
      maxCropCandidates: map['maxCropCandidates'] ?? 10,
      enableSubjectScaling: map['enableSubjectScaling'] ?? true,
      minSubjectCoverage: (map['minSubjectCoverage'] ?? 0.85).toDouble(),
      maxScaleFactor: (map['maxScaleFactor'] ?? 1.5).toDouble(),
      enableMlSubjectDetection: map['enableMlSubjectDetection'] ?? true,
      allowLetterbox: map['allowLetterbox'] ?? false,
    );
  }

  /// Converts settings to JSON string
  String toJson() {
    final map = toMap();
    return '{'
        '"aggressiveness":${map['aggressiveness']},'
        '"enableRuleOfThirds":${map['enableRuleOfThirds']},'
        '"enableEntropyAnalysis":${map['enableEntropyAnalysis']},'
        '"enableEdgeDetection":${map['enableEdgeDetection']},'
        '"enableCenterWeighting":${map['enableCenterWeighting']},'
        '"maxProcessingTimeMs":${map['maxProcessingTimeMs']},'
        '"enableSubjectScaling":${map['enableSubjectScaling']},'
        '"minSubjectCoverage":${map['minSubjectCoverage']},'
        '"maxScaleFactor":${map['maxScaleFactor']},'
        '"enableMlSubjectDetection":${map['enableMlSubjectDetection']},'
        '"allowLetterbox":${map['allowLetterbox']}'
        '}';
  }

  /// Creates settings from JSON string
  factory CropSettings.fromJson(String json) {
    // Simple JSON parsing for the specific format we use
    final cleanJson = json.replaceAll(RegExp(r'[{}"]'), '');
    final pairs = cleanJson.split(',');
    final map = <String, dynamic>{};

    for (final pair in pairs) {
      final keyValue = pair.split(':');
      if (keyValue.length == 2) {
        final key = keyValue[0].trim();
        final value = keyValue[1].trim();

        if (key == 'aggressiveness' || key == 'maxProcessingTimeMs') {
          map[key] = int.tryParse(value) ?? 0;
        } else if (key == 'minSubjectCoverage' || key == 'maxScaleFactor') {
          map[key] = double.tryParse(value) ?? 0.0;
        } else {
          map[key] = value.toLowerCase() == 'true';
        }
      }
    }

    return CropSettings.fromMap(map);
  }
}
