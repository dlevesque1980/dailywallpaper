import 'dart:ui' as ui;
import '../models/crop_coordinates.dart';
import '../models/crop_score.dart';
import '../models/crop_settings.dart';

import 'fallback_strategies/fallback_strategy.dart';
import 'fallback_strategies/intelligent_center_strategy.dart';
import 'fallback_strategies/aspect_ratio_aware_strategy.dart';
import 'fallback_strategies/user_preference_strategy.dart';
import 'fallback_strategies/safe_zone_strategy.dart';
import 'fallback_strategies/ultimate_center_strategy.dart';

/// Types of fallback strategies available
enum FallbackType {
  intelligentCenter,
  aspectRatioAware,
  userPreference,
  safeZone,
  ultimateCenter,
}

/// Comprehensive fallback crop strategies for when smart analysis fails
class FallbackCropStrategies {
  static final FallbackCropStrategies _instance =
      FallbackCropStrategies._internal();
  factory FallbackCropStrategies() => _instance;
  
  late final Map<FallbackType, FallbackStrategy> _strategies;

  FallbackCropStrategies._internal() {
    _strategies = {
      FallbackType.intelligentCenter: IntelligentCenterStrategy(),
      FallbackType.aspectRatioAware: AspectRatioAwareStrategy(),
      FallbackType.userPreference: UserPreferenceStrategy(),
      FallbackType.safeZone: SafeZoneStrategy(),
      FallbackType.ultimateCenter: UltimateCenterStrategy(),
    };
  }

  /// Creates the most appropriate fallback crop based on context
  CropCoordinates createFallbackCrop({
    required ui.Image image,
    required ui.Size targetSize,
    required String reason,
    CropSettings? settings,
    Map<String, dynamic>? context,
  }) {
    final type = _selectFallbackStrategy(reason, settings, context);
    final strategy = _strategies[type] ?? _strategies[FallbackType.intelligentCenter]!;

    return strategy.createCrop(
      image: image,
      targetSize: targetSize,
      settings: settings,
      context: context,
    );
  }

  /// Creates multiple fallback options with quality scores
  List<CropScore> createFallbackOptions({
    required ui.Image image,
    required ui.Size targetSize,
    CropSettings? settings,
  }) {
    final options = <CropScore>[];

    void addOption(FallbackType type, String strategyName, String fallbackType, double confidence) {
      final strategy = _strategies[type]!;
      final coordinates = strategy.createCrop(image: image, targetSize: targetSize, settings: settings);
      
      options.add(CropScore(
        coordinates: coordinates,
        score: strategy.scoreCrop(crop: coordinates, image: image, targetSize: targetSize),
        strategy: strategyName,
        metrics: {
          'fallback_type': fallbackType,
          'confidence': confidence,
        },
      ));
    }

    addOption(FallbackType.intelligentCenter, 'intelligent_center_fallback', 'intelligent_center', 0.7);
    addOption(FallbackType.aspectRatioAware, 'aspect_ratio_aware_fallback', 'aspect_ratio_aware', 0.6);
    addOption(FallbackType.safeZone, 'safe_zone_fallback', 'safe_zone', 0.5);

    // Sort by score (highest first)
    options.sort((a, b) => b.score.compareTo(a.score));

    return options;
  }

  /// Selects the most appropriate fallback strategy
  FallbackType _selectFallbackStrategy(
    String reason,
    CropSettings? settings,
    Map<String, dynamic>? context,
  ) {
    // Select based on failure reason
    switch (reason) {
      case 'timeout':
      case 'memory_pressure':
        return FallbackType.intelligentCenter; // Fast and reliable
      case 'analyzer_failure':
      case 'all_analyzers_failed':
        return FallbackType.aspectRatioAware; // More sophisticated
      case 'invalid_input':
      case 'corrupted_image':
        return FallbackType.safeZone; // Conservative approach
      case 'network_error':
        return FallbackType.userPreference; // Use cached preferences
      case 'ultimate_fallback':
      case 'absolute_fallback':
        return FallbackType.ultimateCenter; // Last resort
      default:
        return FallbackType.intelligentCenter; // Default safe choice
    }
  }
}
