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

  const CropSettings({
    this.aggressiveness = CropAggressiveness.balanced,
    this.enableRuleOfThirds = true,
    this.enableEntropyAnalysis = true,
    this.enableEdgeDetection = false,
    this.enableCenterWeighting = true,
    this.maxProcessingTime = const Duration(seconds: 2),
  });

  /// Default settings for the smart crop system
  static const CropSettings defaultSettings = CropSettings(
    aggressiveness: CropAggressiveness.aggressive, // Plus agressif pour voir l'effet
    enableRuleOfThirds: true,
    enableEntropyAnalysis: true,
    enableEdgeDetection: true, // Activé pour plus d'analyse
    enableCenterWeighting: true,
    maxProcessingTime: Duration(seconds: 3), // Plus de temps pour un meilleur résultat
  );

  /// Creates a copy with modified values
  CropSettings copyWith({
    CropAggressiveness? aggressiveness,
    bool? enableRuleOfThirds,
    bool? enableEntropyAnalysis,
    bool? enableEdgeDetection,
    bool? enableCenterWeighting,
    Duration? maxProcessingTime,
  }) {
    return CropSettings(
      aggressiveness: aggressiveness ?? this.aggressiveness,
      enableRuleOfThirds: enableRuleOfThirds ?? this.enableRuleOfThirds,
      enableEntropyAnalysis: enableEntropyAnalysis ?? this.enableEntropyAnalysis,
      enableEdgeDetection: enableEdgeDetection ?? this.enableEdgeDetection,
      enableCenterWeighting: enableCenterWeighting ?? this.enableCenterWeighting,
      maxProcessingTime: maxProcessingTime ?? this.maxProcessingTime,
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
    return maxProcessingTime.inMilliseconds > 0 &&
           enabledStrategies.isNotEmpty;
  }

  @override
  String toString() {
    return 'CropSettings(aggressiveness: $aggressiveness, enabledStrategies: $enabledStrategies, maxProcessingTime: ${maxProcessingTime.inMilliseconds}ms)';
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
           other.maxProcessingTime == maxProcessingTime;
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
    };
  }

  /// Creates settings from a Map (deserialization)
  factory CropSettings.fromMap(Map<String, dynamic> map) {
    return CropSettings(
      aggressiveness: CropAggressiveness.values[map['aggressiveness'] ?? CropAggressiveness.balanced.index],
      enableRuleOfThirds: map['enableRuleOfThirds'] ?? true,
      enableEntropyAnalysis: map['enableEntropyAnalysis'] ?? true,
      enableEdgeDetection: map['enableEdgeDetection'] ?? false,
      enableCenterWeighting: map['enableCenterWeighting'] ?? true,
      maxProcessingTime: Duration(milliseconds: map['maxProcessingTimeMs'] ?? 2000),
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
        '"maxProcessingTimeMs":${map['maxProcessingTimeMs']}'
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
        } else {
          map[key] = value.toLowerCase() == 'true';
        }
      }
    }
    
    return CropSettings.fromMap(map);
  }
}