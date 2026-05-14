import 'dart:async';
import 'dart:io' as io;
import 'dart:math' as math;

import '../models/crop_settings.dart';
import 'device_capability_detector.dart';

/// Optimizes smart crop processing for battery usage
class BatteryOptimizer {
  static BatteryState? _cachedBatteryState;
  static DateTime? _lastBatteryCheck;
  static const Duration _batteryCheckInterval = Duration(minutes: 5);
  
  /// Gets the current battery optimization strategy
  static Future<BatteryOptimizationStrategy> getOptimizationStrategy() async {
    final deviceCapability = await DeviceCapabilityDetector.getDeviceCapability();
    final batteryState = await _getBatteryState();
    
    return _calculateOptimizationStrategy(deviceCapability, batteryState);
  }
  
  /// Optimizes crop settings for battery usage
  static Future<CropSettings> optimizeSettingsForBattery(
    CropSettings originalSettings,
  ) async {
    final strategy = await getOptimizationStrategy();
    
    return _applyBatteryOptimizations(originalSettings, strategy);
  }
  
  /// Determines if background processing should be throttled
  static Future<bool> shouldThrottleBackgroundProcessing() async {
    final strategy = await getOptimizationStrategy();
    
    return strategy.throttleBackgroundProcessing;
  }
  
  /// Gets the recommended processing delay for battery optimization
  static Future<Duration> getRecommendedProcessingDelay() async {
    final strategy = await getOptimizationStrategy();
    
    return strategy.processingDelay;
  }
  
  /// Checks if processing should be deferred due to battery constraints
  static Future<bool> shouldDeferProcessing() async {
    final strategy = await getOptimizationStrategy();
    
    return strategy.deferProcessing;
  }
  
  /// Gets battery state with caching
  static Future<BatteryState> _getBatteryState() async {
    final now = DateTime.now();
    
    // Use cached state if recent
    if (_cachedBatteryState != null && 
        _lastBatteryCheck != null &&
        now.difference(_lastBatteryCheck!) < _batteryCheckInterval) {
      return _cachedBatteryState!;
    }
    
    // Assess battery state
    _cachedBatteryState = await _assessBatteryState();
    _lastBatteryCheck = now;
    
    return _cachedBatteryState!;
  }
  
  /// Assesses current battery state
  static Future<BatteryState> _assessBatteryState() async {
    try {
      // On mobile platforms, we can't directly access battery info from Dart
      // So we use heuristics and conservative assumptions
      
      if (io.Platform.isAndroid || io.Platform.isIOS) {
        // Mobile devices - assume battery optimization is needed
        return BatteryState.optimizationNeeded;
      } else {
        // Desktop platforms - assume plugged in
        return BatteryState.pluggedIn;
      }
    } catch (e) {
      // If we can't determine battery state, be conservative
      return BatteryState.optimizationNeeded;
    }
  }
  
  /// Calculates optimization strategy based on device and battery state
  static BatteryOptimizationStrategy _calculateOptimizationStrategy(
    DeviceCapability deviceCapability,
    BatteryState batteryState,
  ) {
    // Base strategy on battery state
    switch (batteryState) {
      case BatteryState.critical:
        return BatteryOptimizationStrategy.aggressive;
        
      case BatteryState.low:
        return deviceCapability.isLowPerformance 
            ? BatteryOptimizationStrategy.aggressive
            : BatteryOptimizationStrategy.moderate;
            
      case BatteryState.optimizationNeeded:
        return deviceCapability.isLowPerformance
            ? BatteryOptimizationStrategy.moderate
            : BatteryOptimizationStrategy.minimal;
            
      case BatteryState.pluggedIn:
        return BatteryOptimizationStrategy.none;
    }
  }
  
  /// Applies battery optimizations to crop settings
  static CropSettings _applyBatteryOptimizations(
    CropSettings originalSettings,
    BatteryOptimizationStrategy strategy,
  ) {
    switch (strategy) {
      case BatteryOptimizationStrategy.none:
        return originalSettings;
        
      case BatteryOptimizationStrategy.minimal:
        return originalSettings.copyWith(
          // Slightly reduce timeout
          maxProcessingTime: Duration(
            milliseconds: (originalSettings.maxProcessingTime.inMilliseconds * 0.9).round(),
          ),
        );
        
      case BatteryOptimizationStrategy.moderate:
        return originalSettings.copyWith(
          // Disable heavy analyzers
          enableEdgeDetection: false,
          enableEntropyAnalysis: originalSettings.enableEntropyAnalysis && 
                                originalSettings.enableRuleOfThirds == false,
          // Reduce timeout
          maxProcessingTime: Duration(
            milliseconds: (originalSettings.maxProcessingTime.inMilliseconds * 0.7).round(),
          ),
        );
        
      case BatteryOptimizationStrategy.aggressive:
        return originalSettings.copyWith(
          // Only keep lightweight analyzers
          enableEdgeDetection: false,
          enableEntropyAnalysis: false,
          enableRuleOfThirds: true,
          enableCenterWeighting: true,
          // Significantly reduce timeout
          maxProcessingTime: Duration(
            milliseconds: math.min(
              (originalSettings.maxProcessingTime.inMilliseconds * 0.5).round(),
              1000, // Max 1 second
            ),
          ),
        );
    }
  }
  
  /// Clears cached battery state (useful for testing)
  static void clearCache() {
    _cachedBatteryState = null;
    _lastBatteryCheck = null;
  }
  
  /// Gets battery optimization statistics
  static Map<String, dynamic> getOptimizationStats() {
    return {
      'cached_battery_state': _cachedBatteryState?.toString(),
      'last_battery_check': _lastBatteryCheck?.toIso8601String(),
      'cache_age_minutes': _lastBatteryCheck != null 
          ? DateTime.now().difference(_lastBatteryCheck!).inMinutes
          : null,
    };
  }
}

/// Battery state classification
enum BatteryState {
  /// Battery level is critical (< 15%)
  critical,
  
  /// Battery level is low (15-30%)
  low,
  
  /// Battery optimization is recommended (30-80% or unknown)
  optimizationNeeded,
  
  /// Device is plugged in or battery is high (> 80%)
  pluggedIn,
}

/// Battery optimization strategy levels
enum BatteryOptimizationStrategy {
  /// No battery optimizations
  none,
  
  /// Minimal optimizations (slight timeout reduction)
  minimal,
  
  /// Moderate optimizations (disable heavy analyzers)
  moderate,
  
  /// Aggressive optimizations (only lightweight analyzers)
  aggressive,
}

/// Extension to provide strategy details
extension BatteryOptimizationStrategyExtension on BatteryOptimizationStrategy {
  /// Whether to throttle background processing
  bool get throttleBackgroundProcessing {
    switch (this) {
      case BatteryOptimizationStrategy.none:
      case BatteryOptimizationStrategy.minimal:
        return false;
      case BatteryOptimizationStrategy.moderate:
      case BatteryOptimizationStrategy.aggressive:
        return true;
    }
  }
  
  /// Processing delay for battery optimization
  Duration get processingDelay {
    switch (this) {
      case BatteryOptimizationStrategy.none:
        return Duration.zero;
      case BatteryOptimizationStrategy.minimal:
        return const Duration(milliseconds: 100);
      case BatteryOptimizationStrategy.moderate:
        return const Duration(milliseconds: 300);
      case BatteryOptimizationStrategy.aggressive:
        return const Duration(milliseconds: 500);
    }
  }
  
  /// Whether to defer processing entirely
  bool get deferProcessing {
    switch (this) {
      case BatteryOptimizationStrategy.none:
      case BatteryOptimizationStrategy.minimal:
      case BatteryOptimizationStrategy.moderate:
        return false;
      case BatteryOptimizationStrategy.aggressive:
        return true; // Defer non-critical processing
    }
  }
  
  /// Timeout multiplier for this strategy
  double get timeoutMultiplier {
    switch (this) {
      case BatteryOptimizationStrategy.none:
        return 1.0;
      case BatteryOptimizationStrategy.minimal:
        return 0.9;
      case BatteryOptimizationStrategy.moderate:
        return 0.7;
      case BatteryOptimizationStrategy.aggressive:
        return 0.5;
    }
  }
}