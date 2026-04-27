import 'dart:ui' as ui;
import 'dart:math' as math;
import '../models/crop_settings.dart';
import '../interfaces/crop_analyzer.dart';
import 'error_handler.dart';

/// Manages graceful degradation of crop analysis under resource constraints
class DegradationManager {
  static final DegradationManager _instance = DegradationManager._internal();
  factory DegradationManager() => _instance;
  DegradationManager._internal();

  final SmartCropErrorHandler _errorHandler = SmartCropErrorHandler();

  // Performance thresholds
  static const Duration fastProcessingThreshold = Duration(milliseconds: 100);
  static const Duration normalProcessingThreshold = Duration(milliseconds: 500);
  static const Duration slowProcessingThreshold = Duration(milliseconds: 1000);

  // Memory usage thresholds (approximate)
  static const int lowMemoryThreshold = 50 * 1024 * 1024; // 50MB
  static const int criticalMemoryThreshold = 20 * 1024 * 1024; // 20MB

  /// Determines if degradation is needed based on current conditions
  DegradationLevel assessDegradationNeeds({
    required ui.Image image,
    required CropSettings settings,
    Duration? recentProcessingTime,
    int? availableMemory,
    List<CropError>? recentErrors,
  }) {
    var level = DegradationLevel.none;

    // Check processing time performance
    if (recentProcessingTime != null) {
      if (recentProcessingTime > slowProcessingThreshold) {
        level = DegradationLevel.high;
      } else if (recentProcessingTime > normalProcessingThreshold) {
        level = DegradationLevel.medium;
      }
    }

    // Check memory constraints
    if (availableMemory != null) {
      if (availableMemory < criticalMemoryThreshold) {
        level = DegradationLevel.high;
      } else if (availableMemory < lowMemoryThreshold) {
        level = _maxLevel(level, DegradationLevel.medium);
      }
    }

    // Check image size constraints
    final imagePixels = image.width * image.height;
    if (imagePixels > 4000000) {
      // > 4MP
      level = _maxLevel(level, DegradationLevel.low);
    }

    // Check recent error patterns
    if (recentErrors != null && recentErrors.isNotEmpty) {
      final criticalErrors = recentErrors
          .where((e) =>
              e.severity == ErrorSeverity.critical ||
              e.severity == ErrorSeverity.high)
          .length;

      if (criticalErrors >= 3) {
        level = DegradationLevel.high;
      } else if (criticalErrors >= 1) {
        level = _maxLevel(level, DegradationLevel.medium);
      }
    }

    // Check timeout constraints
    if (settings.maxProcessingTime < fastProcessingThreshold) {
      level = _maxLevel(level, DegradationLevel.high);
    } else if (settings.maxProcessingTime < normalProcessingThreshold) {
      level = _maxLevel(level, DegradationLevel.medium);
    }

    return level;
  }

  /// Creates degraded settings based on degradation level
  CropSettings createDegradedSettings(
    CropSettings originalSettings,
    DegradationLevel level,
  ) {
    switch (level) {
      case DegradationLevel.none:
        return originalSettings;

      case DegradationLevel.low:
        return originalSettings.copyWith(
          maxProcessingTime: Duration(
            milliseconds:
                (originalSettings.maxProcessingTime.inMilliseconds * 0.8)
                    .round(),
          ),
          enableBatteryOptimization: true,
          maxCropCandidates:
              math.max(5, (originalSettings.maxCropCandidates * 0.8).round()),
        );

      case DegradationLevel.medium:
        return originalSettings.copyWith(
          maxProcessingTime: Duration(
            milliseconds:
                (originalSettings.maxProcessingTime.inMilliseconds * 0.6)
                    .round(),
          ),
          enableBatteryOptimization: true,
          enableEdgeDetection: false, // Disable expensive operations
          maxCropCandidates:
              math.max(3, (originalSettings.maxCropCandidates * 0.5).round()),
        );

      case DegradationLevel.high:
        return originalSettings.copyWith(
          maxProcessingTime: Duration(
            milliseconds:
                (originalSettings.maxProcessingTime.inMilliseconds * 0.3)
                    .round(),
          ),
          enableBatteryOptimization: true,
          enableEdgeDetection: false,
          enableEntropyAnalysis: false, // Disable expensive operations
          maxCropCandidates: 1, // Minimal candidates
        );
    }
  }

  /// Filters analyzers based on degradation level and error history
  List<CropAnalyzer> filterAnalyzers(
    List<CropAnalyzer> analyzers,
    DegradationLevel level,
    ui.Image image,
    CropSettings settings,
  ) {
    var filteredAnalyzers = <CropAnalyzer>[];

    // Remove analyzers that have been failing recently
    for (final analyzer in analyzers) {
      final analyzerName =
          analyzer is CropAnalyzerV2 ? analyzer.name : analyzer.strategyName;
      if (!_errorHandler.shouldSkipAnalyzer(analyzerName)) {
        filteredAnalyzers.add(analyzer);
      }
    }

    // Sort by priority (higher priority first)
    filteredAnalyzers.sort((a, b) {
      final aPriority = a is CropAnalyzerV2 ? a.priority : 100;
      final bPriority = b is CropAnalyzerV2 ? b.priority : 100;
      return bPriority.compareTo(aPriority);
    });

    // Apply degradation-based filtering
    switch (level) {
      case DegradationLevel.none:
        // Use all available analyzers
        break;

      case DegradationLevel.low:
        // Skip the most expensive analyzers
        filteredAnalyzers = filteredAnalyzers.where((analyzer) {
          if (analyzer is CropAnalyzerV2) {
            return analyzer.maxProcessingTime.inMilliseconds <= 800;
          }
          return true; // Keep v1 analyzers
        }).toList();
        break;

      case DegradationLevel.medium:
        // Keep only fast analyzers
        filteredAnalyzers = filteredAnalyzers
            .where((analyzer) {
              if (analyzer is CropAnalyzerV2) {
                return analyzer.maxProcessingTime.inMilliseconds <= 400;
              }
              return true; // Keep v1 analyzers but limit count
            })
            .take(3)
            .toList();
        break;

      case DegradationLevel.high:
        // Keep only the fastest, most reliable analyzer
        filteredAnalyzers = filteredAnalyzers
            .where((analyzer) {
              if (analyzer is CropAnalyzerV2) {
                return analyzer.maxProcessingTime.inMilliseconds <= 200;
              }
              return true; // Keep v1 analyzers but limit to 1
            })
            .take(1)
            .toList();
        break;
    }

    // Ensure we always have at least one analyzer
    if (filteredAnalyzers.isEmpty && analyzers.isNotEmpty) {
      // Use the first available analyzer as emergency fallback
      filteredAnalyzers = [analyzers.first];
    }

    return filteredAnalyzers;
  }

  /// Creates a fallback chain for progressive degradation
  List<FallbackStrategy> createFallbackChain(
    ui.Image image,
    ui.Size targetSize,
    CropSettings settings,
  ) {
    return [
      // Primary: Try with reduced quality
      FallbackStrategy(
        name: 'reduced_quality',
        settings: createDegradedSettings(settings, DegradationLevel.low),
        timeout: Duration(
          milliseconds:
              (settings.maxProcessingTime.inMilliseconds * 0.8).round(),
        ),
      ),

      // Secondary: Try with minimal analyzers
      FallbackStrategy(
        name: 'minimal_analyzers',
        settings: createDegradedSettings(settings, DegradationLevel.medium),
        timeout: Duration(
          milliseconds:
              (settings.maxProcessingTime.inMilliseconds * 0.5).round(),
        ),
      ),

      // Tertiary: Try with single fast analyzer
      FallbackStrategy(
        name: 'single_analyzer',
        settings: createDegradedSettings(settings, DegradationLevel.high),
        timeout: Duration(
          milliseconds:
              (settings.maxProcessingTime.inMilliseconds * 0.3).round(),
        ),
      ),

      // Ultimate: Center crop fallback
      FallbackStrategy(
        name: 'center_crop',
        settings: CropSettings.conservative,
        timeout: const Duration(milliseconds: 50),
      ),
    ];
  }

  /// Records degradation event for monitoring
  void recordDegradationEvent({
    required DegradationLevel level,
    required String reason,
    String? imageId,
    Map<String, dynamic>? context,
  }) {
    final error = CropError(
      type: CropErrorType.resourceExhaustion,
      message: 'Degradation applied: $level ($reason)',
      severity: _severityForLevel(level),
      imageId: imageId,
      isRecoverable: true,
      context: {
        'degradation_level': level.toString(),
        'reason': reason,
        ...?context,
      },
    );

    _errorHandler.recordError(error);
  }

  /// Gets degradation statistics
  Map<String, dynamic> getDegradationStats() {
    final errorStats = _errorHandler.getErrorStats();
    final degradationErrors = _errorHandler
        .getRecentErrors()
        .where((e) => e.type == CropErrorType.resourceExhaustion)
        .toList();

    final degradationsByLevel = <String, int>{};
    for (final error in degradationErrors) {
      final level = error.context['degradation_level'] as String?;
      if (level != null) {
        degradationsByLevel[level] = (degradationsByLevel[level] ?? 0) + 1;
      }
    }

    return {
      'total_degradations': degradationErrors.length,
      'degradations_by_level': degradationsByLevel,
      'error_stats': errorStats,
    };
  }

  DegradationLevel _maxLevel(DegradationLevel a, DegradationLevel b) {
    return DegradationLevel.values[math.max(a.index, b.index)];
  }

  ErrorSeverity _severityForLevel(DegradationLevel level) {
    switch (level) {
      case DegradationLevel.none:
        return ErrorSeverity.low;
      case DegradationLevel.low:
        return ErrorSeverity.low;
      case DegradationLevel.medium:
        return ErrorSeverity.medium;
      case DegradationLevel.high:
        return ErrorSeverity.high;
    }
  }
}

/// Levels of degradation that can be applied
enum DegradationLevel {
  none,
  low,
  medium,
  high,
}

/// Represents a fallback strategy with specific settings and timeout
class FallbackStrategy {
  final String name;
  final CropSettings settings;
  final Duration timeout;

  const FallbackStrategy({
    required this.name,
    required this.settings,
    required this.timeout,
  });

  @override
  String toString() =>
      'FallbackStrategy($name, timeout: ${timeout.inMilliseconds}ms)';
}
