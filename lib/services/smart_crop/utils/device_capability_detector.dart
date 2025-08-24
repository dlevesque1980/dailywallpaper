import 'dart:io' as io;
import 'dart:ui' as ui;
import 'dart:math' as math;

/// Detects device capabilities and provides performance scaling recommendations
class DeviceCapabilityDetector {
  static DeviceCapability? _cachedCapability;
  
  /// Gets the device capability assessment
  static Future<DeviceCapability> getDeviceCapability() async {
    if (_cachedCapability != null) {
      return _cachedCapability!;
    }
    
    _cachedCapability = await _assessDeviceCapability();
    return _cachedCapability!;
  }
  
  /// Clears cached capability (useful for testing or when device state changes)
  static void clearCache() {
    _cachedCapability = null;
  }
  
  /// Assesses device capability based on available metrics
  static Future<DeviceCapability> _assessDeviceCapability() async {
    try {
      final platform = _detectPlatform();
      final memoryTier = await _assessMemoryTier();
      final processingTier = await _assessProcessingTier();
      final batteryOptimized = _shouldOptimizeForBattery();
      
      final overallTier = _calculateOverallTier(memoryTier, processingTier);
      
      return DeviceCapability(
        platform: platform,
        memoryTier: memoryTier,
        processingTier: processingTier,
        overallTier: overallTier,
        batteryOptimized: batteryOptimized,
        maxConcurrentAnalyzers: _getMaxConcurrentAnalyzers(overallTier),
        maxImageDimension: _getMaxImageDimension(overallTier),
        useIsolateThreshold: _getIsolateThreshold(overallTier),
        timeoutMultiplier: _getTimeoutMultiplier(overallTier),
      );
    } catch (e) {
      // Return conservative defaults if assessment fails
      return DeviceCapability.conservative();
    }
  }
  
  /// Detects the platform type
  static DevicePlatform _detectPlatform() {
    if (io.Platform.isAndroid) {
      return DevicePlatform.android;
    } else if (io.Platform.isIOS) {
      return DevicePlatform.ios;
    } else if (io.Platform.isMacOS) {
      return DevicePlatform.macos;
    } else if (io.Platform.isWindows) {
      return DevicePlatform.windows;
    } else if (io.Platform.isLinux) {
      return DevicePlatform.linux;
    } else {
      return DevicePlatform.unknown;
    }
  }
  
  /// Assesses memory tier based on available indicators
  static Future<PerformanceTier> _assessMemoryTier() async {
    try {
      // Get screen size as a proxy for device capability
      final screenSize = ui.window.physicalSize;
      final screenPixels = screenSize.width * screenSize.height;
      
      // Higher resolution screens typically indicate more capable devices
      if (screenPixels > 2000000) { // > 2MP (e.g., 1440x1440+)
        return PerformanceTier.high;
      } else if (screenPixels > 1000000) { // > 1MP (e.g., 1080x1080+)
        return PerformanceTier.medium;
      } else {
        return PerformanceTier.low;
      }
    } catch (e) {
      return PerformanceTier.low;
    }
  }
  
  /// Assesses processing tier using a simple benchmark
  static Future<PerformanceTier> _assessProcessingTier() async {
    try {
      // Simple CPU benchmark - measure time to perform calculations
      final stopwatch = Stopwatch()..start();
      
      // Perform some mathematical operations
      double result = 0.0;
      for (int i = 0; i < 100000; i++) {
        result += math.sin(i.toDouble()) * math.cos(i.toDouble());
      }
      
      stopwatch.stop();
      final durationMs = stopwatch.elapsedMilliseconds;
      
      // Classify based on benchmark time
      if (durationMs < 50) {
        return PerformanceTier.high;
      } else if (durationMs < 150) {
        return PerformanceTier.medium;
      } else {
        return PerformanceTier.low;
      }
    } catch (e) {
      return PerformanceTier.low;
    }
  }
  
  /// Determines if battery optimization should be prioritized
  static bool _shouldOptimizeForBattery() {
    // Mobile platforms should prioritize battery optimization
    return io.Platform.isAndroid || io.Platform.isIOS;
  }
  
  /// Calculates overall performance tier
  static PerformanceTier _calculateOverallTier(
    PerformanceTier memoryTier,
    PerformanceTier processingTier,
  ) {
    // Take the lower of the two tiers for conservative assessment
    final memoryIndex = memoryTier.index;
    final processingIndex = processingTier.index;
    final minIndex = math.min(memoryIndex, processingIndex);
    
    return PerformanceTier.values[minIndex];
  }
  
  /// Gets maximum concurrent analyzers based on tier
  static int _getMaxConcurrentAnalyzers(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.high:
        return 4;
      case PerformanceTier.medium:
        return 2;
      case PerformanceTier.low:
        return 1;
    }
  }
  
  /// Gets maximum image dimension for analysis based on tier
  static int _getMaxImageDimension(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.high:
        return 1024;
      case PerformanceTier.medium:
        return 512;
      case PerformanceTier.low:
        return 256;
    }
  }
  
  /// Gets isolate usage threshold based on tier
  static int _getIsolateThreshold(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.high:
        return 1024 * 1024; // 1MP
      case PerformanceTier.medium:
        return 512 * 512; // 0.25MP
      case PerformanceTier.low:
        return 2048 * 2048; // 4MP (higher threshold = less likely to use isolate)
    }
  }
  
  /// Gets timeout multiplier based on tier
  static double _getTimeoutMultiplier(PerformanceTier tier) {
    switch (tier) {
      case PerformanceTier.high:
        return 1.0;
      case PerformanceTier.medium:
        return 1.5;
      case PerformanceTier.low:
        return 2.0;
    }
  }
}

/// Device capability assessment result
class DeviceCapability {
  final DevicePlatform platform;
  final PerformanceTier memoryTier;
  final PerformanceTier processingTier;
  final PerformanceTier overallTier;
  final bool batteryOptimized;
  final int maxConcurrentAnalyzers;
  final int maxImageDimension;
  final int useIsolateThreshold;
  final double timeoutMultiplier;
  
  const DeviceCapability({
    required this.platform,
    required this.memoryTier,
    required this.processingTier,
    required this.overallTier,
    required this.batteryOptimized,
    required this.maxConcurrentAnalyzers,
    required this.maxImageDimension,
    required this.useIsolateThreshold,
    required this.timeoutMultiplier,
  });
  
  /// Creates a conservative capability profile for unknown devices
  factory DeviceCapability.conservative() {
    return const DeviceCapability(
      platform: DevicePlatform.unknown,
      memoryTier: PerformanceTier.low,
      processingTier: PerformanceTier.low,
      overallTier: PerformanceTier.low,
      batteryOptimized: true,
      maxConcurrentAnalyzers: 1,
      maxImageDimension: 256,
      useIsolateThreshold: 2048 * 2048,
      timeoutMultiplier: 2.0,
    );
  }
  
  /// Checks if the device is considered high performance
  bool get isHighPerformance => overallTier == PerformanceTier.high;
  
  /// Checks if the device is considered low performance
  bool get isLowPerformance => overallTier == PerformanceTier.low;
  
  /// Checks if the device is mobile
  bool get isMobile => platform == DevicePlatform.android || platform == DevicePlatform.ios;
  
  /// Checks if the device is desktop
  bool get isDesktop => platform == DevicePlatform.macos || 
                       platform == DevicePlatform.windows || 
                       platform == DevicePlatform.linux;
  
  @override
  String toString() {
    return 'DeviceCapability('
        'platform: $platform, '
        'overallTier: $overallTier, '
        'batteryOptimized: $batteryOptimized, '
        'maxConcurrentAnalyzers: $maxConcurrentAnalyzers, '
        'maxImageDimension: $maxImageDimension'
        ')';
  }
}

/// Device platform types
enum DevicePlatform {
  android,
  ios,
  macos,
  windows,
  linux,
  unknown,
}

/// Performance tier classification
enum PerformanceTier {
  low,
  medium,
  high,
}