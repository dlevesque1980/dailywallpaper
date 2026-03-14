import 'dart:ui' as ui;
import 'dart:math' as math;
import '../models/crop_coordinates.dart';
import '../models/crop_score.dart';
import '../models/crop_settings.dart';

/// Comprehensive fallback crop strategies for when smart analysis fails
class FallbackCropStrategies {
  static final FallbackCropStrategies _instance =
      FallbackCropStrategies._internal();
  factory FallbackCropStrategies() => _instance;
  FallbackCropStrategies._internal();

  /// Creates the most appropriate fallback crop based on context
  CropCoordinates createFallbackCrop({
    required ui.Image image,
    required ui.Size targetSize,
    required String reason,
    CropSettings? settings,
    Map<String, dynamic>? context,
  }) {
    final strategy = _selectFallbackStrategy(reason, settings, context);

    switch (strategy) {
      case FallbackType.intelligentCenter:
        return _createIntelligentCenterCrop(image, targetSize, settings);
      case FallbackType.aspectRatioAware:
        return _createAspectRatioAwareCrop(image, targetSize, settings);
      case FallbackType.userPreference:
        return _createUserPreferenceCrop(image, targetSize, settings);
      case FallbackType.safeZone:
        return _createSafeZoneCrop(image, targetSize, settings);
      case FallbackType.ultimateCenter:
        return _createUltimateCenterCrop(image, targetSize);
    }
  }

  /// Creates multiple fallback options with quality scores
  List<CropScore> createFallbackOptions({
    required ui.Image image,
    required ui.Size targetSize,
    CropSettings? settings,
  }) {
    final options = <CropScore>[];

    // Intelligent center crop
    final intelligentCenter =
        _createIntelligentCenterCrop(image, targetSize, settings);
    options.add(CropScore(
      coordinates: intelligentCenter,
      score: _scoreFallbackCrop(
          intelligentCenter, image, targetSize, 'intelligent_center'),
      strategy: 'intelligent_center_fallback',
      metrics: {
        'fallback_type': 'intelligent_center',
        'confidence': 0.7,
      },
    ));

    // Aspect ratio aware crop
    final aspectRatioAware =
        _createAspectRatioAwareCrop(image, targetSize, settings);
    options.add(CropScore(
      coordinates: aspectRatioAware,
      score: _scoreFallbackCrop(
          aspectRatioAware, image, targetSize, 'aspect_ratio_aware'),
      strategy: 'aspect_ratio_aware_fallback',
      metrics: {
        'fallback_type': 'aspect_ratio_aware',
        'confidence': 0.6,
      },
    ));

    // Safe zone crop
    final safeZone = _createSafeZoneCrop(image, targetSize, settings);
    options.add(CropScore(
      coordinates: safeZone,
      score: _scoreFallbackCrop(safeZone, image, targetSize, 'safe_zone'),
      strategy: 'safe_zone_fallback',
      metrics: {
        'fallback_type': 'safe_zone',
        'confidence': 0.5,
      },
    ));

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
    // For now, we'll use the aggressiveness level to determine fallback type
    // In the future, this could be extended with user preferences

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

  /// Creates an intelligent center crop that considers image content
  CropCoordinates _createIntelligentCenterCrop(
    ui.Image image,
    ui.Size targetSize,
    CropSettings? settings,
  ) {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    double cropWidth, cropHeight;
    double offsetX = 0.0, offsetY = 0.0;

    if (targetAspectRatio > imageAspectRatio) {
      // Target is wider - use full width, crop height
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;

      // Apply intelligent vertical positioning
      offsetY = _getIntelligentVerticalOffset(cropHeight, settings);
    } else {
      // Target is taller - use full height, crop width
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;

      // Apply intelligent horizontal positioning
      offsetX = _getIntelligentHorizontalOffset(cropWidth, settings);
    }

    // Ensure valid bounds
    cropWidth = math.max(0.1, math.min(1.0, cropWidth));
    cropHeight = math.max(0.1, math.min(1.0, cropHeight));
    offsetX = math.max(0.0, math.min(1.0 - cropWidth, offsetX));
    offsetY = math.max(0.0, math.min(1.0 - cropHeight, offsetY));

    return CropCoordinates(
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.7,
      strategy: 'intelligent_center_fallback',
    );
  }

  /// Creates an aspect ratio aware crop that preserves important areas
  CropCoordinates _createAspectRatioAwareCrop(
    ui.Image image,
    ui.Size targetSize,
    CropSettings? settings,
  ) {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    // Calculate crop dimensions with padding to avoid edge artifacts
    const padding = 0.05; // 5% padding
    double cropWidth, cropHeight;
    double offsetX, offsetY;

    if (targetAspectRatio > imageAspectRatio) {
      // Target is wider
      cropWidth = math.max(0.1, 1.0 - padding);
      cropHeight =
          math.max(0.1, (imageAspectRatio / targetAspectRatio) * cropWidth);

      offsetX = (1.0 - cropWidth) / 2;
      offsetY = _getOptimalVerticalPosition(cropHeight, imageSize, settings);
    } else {
      // Target is taller
      cropHeight = math.max(0.1, 1.0 - padding);
      cropWidth =
          math.max(0.1, (targetAspectRatio / imageAspectRatio) * cropHeight);

      offsetY = (1.0 - cropHeight) / 2;
      offsetX = _getOptimalHorizontalPosition(cropWidth, imageSize, settings);
    }

    // Ensure valid bounds
    offsetX = math.max(0.0, math.min(1.0 - cropWidth, offsetX));
    offsetY = math.max(0.0, math.min(1.0 - cropHeight, offsetY));

    return CropCoordinates(
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.6,
      strategy: 'aspect_ratio_aware_fallback',
    );
  }

  /// Creates a crop based on user preferences and history
  CropCoordinates _createUserPreferenceCrop(
    ui.Image image,
    ui.Size targetSize,
    CropSettings? settings,
  ) {
    // Use aggressiveness level to determine positioning
    final cropBias = _getCropBiasFromAggressiveness(settings?.aggressiveness);

    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    double cropWidth, cropHeight;
    double offsetX, offsetY;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
      offsetX = 0.0;
      offsetY = (1.0 - cropHeight) * cropBias.vertical;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
      offsetY = 0.0;
      offsetX = (1.0 - cropWidth) * cropBias.horizontal;
    }

    // Ensure valid bounds
    cropWidth = math.max(0.1, math.min(1.0, cropWidth));
    cropHeight = math.max(0.1, math.min(1.0, cropHeight));
    offsetX = math.max(0.0, math.min(1.0 - cropWidth, offsetX));
    offsetY = math.max(0.0, math.min(1.0 - cropHeight, offsetY));

    return CropCoordinates(
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.65,
      strategy: 'user_preference_fallback',
    );
  }

  /// Creates a safe zone crop that avoids edges and potential problem areas
  CropCoordinates _createSafeZoneCrop(
    ui.Image image,
    ui.Size targetSize,
    CropSettings? settings,
  ) {
    const safeZoneMargin = 0.1; // 10% margin from edges

    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    // Calculate safe zone dimensions
    final safeWidth = 1.0 - (2 * safeZoneMargin);
    final safeHeight = 1.0 - (2 * safeZoneMargin);

    double cropWidth, cropHeight;
    double offsetX, offsetY;

    if (targetAspectRatio > imageAspectRatio) {
      // Target is wider - fit within safe zone
      cropWidth = math.min(safeWidth, 1.0);
      cropHeight = math.min(
          safeHeight, (imageAspectRatio / targetAspectRatio) * cropWidth);
    } else {
      // Target is taller - fit within safe zone
      cropHeight = math.min(safeHeight, 1.0);
      cropWidth = math.min(
          safeWidth, (targetAspectRatio / imageAspectRatio) * cropHeight);
    }

    // Center within safe zone
    offsetX = (1.0 - cropWidth) / 2;
    offsetY = (1.0 - cropHeight) / 2;

    // Ensure minimum size
    cropWidth = math.max(0.2, cropWidth);
    cropHeight = math.max(0.2, cropHeight);

    return CropCoordinates(
      x: offsetX,
      y: offsetY,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.5,
      strategy: 'safe_zone_fallback',
    );
  }

  /// Creates the ultimate fallback - simple center crop
  CropCoordinates _createUltimateCenterCrop(
      ui.Image image, ui.Size targetSize) {
    final imageSize = ui.Size(image.width.toDouble(), image.height.toDouble());
    final targetAspectRatio = targetSize.width / targetSize.height;
    final imageAspectRatio = imageSize.width / imageSize.height;

    double cropWidth, cropHeight;

    if (targetAspectRatio > imageAspectRatio) {
      cropWidth = 1.0;
      cropHeight = imageAspectRatio / targetAspectRatio;
    } else {
      cropHeight = 1.0;
      cropWidth = targetAspectRatio / imageAspectRatio;
    }

    // Ensure valid dimensions
    cropWidth = math.max(0.1, math.min(1.0, cropWidth));
    cropHeight = math.max(0.1, math.min(1.0, cropHeight));

    return CropCoordinates(
      x: (1.0 - cropWidth) / 2,
      y: (1.0 - cropHeight) / 2,
      width: cropWidth,
      height: cropHeight,
      confidence: 0.3,
      strategy: 'ultimate_center_fallback',
    );
  }

  /// Gets intelligent vertical offset based on image characteristics
  double _getIntelligentVerticalOffset(
      double cropHeight, CropSettings? settings) {
    // For portraits, bias towards upper third (faces are usually there)
    // For landscapes, bias towards center or lower third (horizon/subjects)

    // Use rule of thirds as default positioning
    final verticalBias = settings?.enableRuleOfThirds == true ? 0.33 : 0.4;
    return (1.0 - cropHeight) * verticalBias;
  }

  /// Gets intelligent horizontal offset based on image characteristics
  double _getIntelligentHorizontalOffset(
      double cropWidth, CropSettings? settings) {
    // Generally center horizontally
    return (1.0 - cropWidth) * 0.5;
  }

  /// Gets optimal vertical position for aspect ratio aware crop
  double _getOptimalVerticalPosition(
    double cropHeight,
    ui.Size imageSize,
    CropSettings? settings,
  ) {
    // Use rule of thirds as default
    const ruleOfThirdsPosition = 1.0 / 3.0;

    if (cropHeight >= 0.8) {
      // Large crop - center it
      return (1.0 - cropHeight) / 2;
    } else {
      // Smaller crop - use rule of thirds
      final position = (1.0 - cropHeight) * ruleOfThirdsPosition;
      return math.max(0.0, math.min(1.0 - cropHeight, position));
    }
  }

  /// Gets optimal horizontal position for aspect ratio aware crop
  double _getOptimalHorizontalPosition(
    double cropWidth,
    ui.Size imageSize,
    CropSettings? settings,
  ) {
    // Generally center horizontally
    return (1.0 - cropWidth) / 2;
  }

  /// Gets crop bias from aggressiveness level
  CropBias _getCropBiasFromAggressiveness(CropAggressiveness? aggressiveness) {
    switch (aggressiveness) {
      case CropAggressiveness.conservative:
        return const CropBias(horizontal: 0.5, vertical: 0.5); // Center
      case CropAggressiveness.balanced:
        return const CropBias(horizontal: 0.5, vertical: 0.33); // Upper third
      case CropAggressiveness.aggressive:
        return const CropBias(horizontal: 0.5, vertical: 0.25); // Upper quarter
      default:
        return const CropBias(horizontal: 0.5, vertical: 0.5); // Center
    }
  }

  /// Scores a fallback crop based on basic quality metrics
  double _scoreFallbackCrop(
    CropCoordinates crop,
    ui.Image image,
    ui.Size targetSize,
    String type,
  ) {
    double score = 0.5; // Base score for fallback

    // Bonus for good aspect ratio preservation
    final targetAspectRatio = targetSize.width / targetSize.height;
    final cropAspectRatio = crop.width / crop.height;
    final aspectRatioDiff = (targetAspectRatio - cropAspectRatio).abs();

    if (aspectRatioDiff < 0.1) {
      score += 0.2; // Good aspect ratio match
    } else if (aspectRatioDiff < 0.3) {
      score += 0.1; // Acceptable aspect ratio match
    }

    // Bonus for avoiding edges (unless it's a safe zone crop)
    if (type != 'safe_zone') {
      final edgeDistance = math.min(
        math.min(crop.x, 1.0 - crop.x - crop.width),
        math.min(crop.y, 1.0 - crop.y - crop.height),
      );

      if (edgeDistance > 0.1) {
        score += 0.1; // Good edge distance
      }
    }

    // Bonus for reasonable crop size
    final cropArea = crop.width * crop.height;
    if (cropArea > 0.3 && cropArea < 0.9) {
      score += 0.1; // Good crop size
    }

    // Type-specific bonuses
    switch (type) {
      case 'intelligent_center':
        score += 0.1; // Reliable strategy
        break;
      case 'aspect_ratio_aware':
        score += 0.05; // Sophisticated approach
        break;
      case 'user_preference':
        score += 0.15; // User customized
        break;
    }

    return math.max(0.0, math.min(1.0, score));
  }
}

/// Types of fallback strategies available
enum FallbackType {
  intelligentCenter,
  aspectRatioAware,
  userPreference,
  safeZone,
  ultimateCenter,
}

/// Represents crop positioning bias
class CropBias {
  final double horizontal; // 0.0 = left, 0.5 = center, 1.0 = right
  final double vertical; // 0.0 = top, 0.5 = center, 1.0 = bottom

  const CropBias({
    required this.horizontal,
    required this.vertical,
  });
}
