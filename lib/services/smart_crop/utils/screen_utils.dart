import 'dart:ui' as ui;
import 'dart:math' as math;

/// Utility functions for screen ratio detection and target size calculation
class ScreenUtils {
  /// Common screen aspect ratios for fallback scenarios
  static const Map<String, double> commonAspectRatios = {
    '16:9': 16.0 / 9.0,
    '18:9': 18.0 / 9.0,
    '19.5:9': 19.5 / 9.0,
    '20:9': 20.0 / 9.0,
    '21:9': 21.0 / 9.0,
    '4:3': 4.0 / 3.0,
    '3:2': 3.0 / 2.0,
    '1:1': 1.0,
  };
  
  /// Default fallback aspect ratio
  static const double defaultAspectRatio = 16.0 / 9.0; // 16:9
  
  /// Detects the current device screen ratio
  /// 
  /// Returns the screen aspect ratio (width / height)
  static double detectScreenRatio() {
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final size = view.physicalSize;
      
      if (size.width <= 0 || size.height <= 0) {
        return defaultAspectRatio;
      }
      
      // Always use the larger dimension as width for consistency
      final width = math.max(size.width, size.height);
      final height = math.min(size.width, size.height);
      
      return width / height;
    } catch (e) {
      // Fallback to default ratio if detection fails
      return defaultAspectRatio;
    }
  }
  
  /// Gets the device screen size in logical pixels
  /// 
  /// Returns screen size as ui.Size
  static ui.Size getScreenSize() {
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final physicalSize = view.physicalSize;
      final devicePixelRatio = view.devicePixelRatio;
      
      return ui.Size(
        physicalSize.width / devicePixelRatio,
        physicalSize.height / devicePixelRatio,
      );
    } catch (e) {
      // Fallback to common screen size
      return const ui.Size(390, 844); // iPhone 12 size as fallback
    }
  }

  /// Gets the full physical screen size including system bars
  /// 
  /// This is useful for wallpaper applications where you want to cover
  /// the entire screen including status bar and navigation areas
  /// 
  /// Returns physical screen size as ui.Size
  static ui.Size getPhysicalScreenSize() {
    try {
      final view = ui.PlatformDispatcher.instance.views.first;
      final physicalSize = view.physicalSize;
      
      return ui.Size(
        physicalSize.width,
        physicalSize.height,
      );
    } catch (e) {
      // Fallback to common physical screen size (iPhone 12 Pro Max as example)
      return const ui.Size(1284, 2778);
    }
  }
  
  /// Calculates target crop size based on screen dimensions and desired aspect ratio
  /// 
  /// [sourceSize] Size of the source image
  /// [targetAspectRatio] Desired aspect ratio (width / height)
  /// [maxDimension] Maximum dimension for the target size (optional)
  /// 
  /// Returns optimal target size for cropping
  static ui.Size calculateTargetSize(
    ui.Size sourceSize,
    double targetAspectRatio, {
    int? maxDimension,
  }) {
    if (sourceSize.width <= 0 || sourceSize.height <= 0) {
      throw ArgumentError('Source size must have positive dimensions');
    }
    
    final sourceAspectRatio = sourceSize.width / sourceSize.height;
    
    double targetWidth, targetHeight;
    
    if (sourceAspectRatio > targetAspectRatio) {
      // Source is wider than target - crop width, keep height
      targetHeight = sourceSize.height;
      targetWidth = targetHeight * targetAspectRatio;
    } else {
      // Source is taller than target - crop height, keep width
      targetWidth = sourceSize.width;
      targetHeight = targetWidth / targetAspectRatio;
    }
    
    // Apply maximum dimension constraint if specified
    if (maxDimension != null) {
      if (targetWidth > maxDimension || targetHeight > maxDimension) {
        final scale = maxDimension / math.max(targetWidth, targetHeight);
        targetWidth *= scale;
        targetHeight *= scale;
      }
    }
    
    return ui.Size(targetWidth, targetHeight);
  }
  
  /// Finds the closest matching aspect ratio from common ratios
  /// 
  /// [aspectRatio] The aspect ratio to match
  /// [tolerance] Tolerance for matching (default 0.1)
  /// 
  /// Returns the name and value of the closest common aspect ratio
  static MapEntry<String, double> findClosestAspectRatio(
    double aspectRatio, {
    double tolerance = 0.1,
  }) {
    MapEntry<String, double>? closest;
    double minDifference = double.infinity;
    
    for (final entry in commonAspectRatios.entries) {
      final difference = (entry.value - aspectRatio).abs();
      if (difference < minDifference) {
        minDifference = difference;
        closest = entry;
      }
    }
    
    // If no close match found within tolerance, return the input ratio
    if (closest == null || minDifference > tolerance) {
      return MapEntry('custom', aspectRatio);
    }
    
    return closest;
  }
  
  /// Determines if an aspect ratio is considered ultra-wide
  /// 
  /// [aspectRatio] The aspect ratio to check
  /// 
  /// Returns true if the ratio is considered ultra-wide (> 2.0)
  static bool isUltraWideRatio(double aspectRatio) {
    return aspectRatio > 2.0;
  }
  
  /// Determines if an aspect ratio is considered tall/narrow
  /// 
  /// [aspectRatio] The aspect ratio to check
  /// 
  /// Returns true if the ratio is considered tall (< 1.0)
  static bool isTallRatio(double aspectRatio) {
    return aspectRatio < 1.0;
  }
  
  /// Calculates the crop factor needed to fit source into target ratio
  /// 
  /// [sourceSize] Size of the source image
  /// [targetAspectRatio] Desired aspect ratio
  /// 
  /// Returns crop factor as a percentage (0.0 to 1.0)
  static double calculateCropFactor(ui.Size sourceSize, double targetAspectRatio) {
    final sourceAspectRatio = sourceSize.width / sourceSize.height;
    
    if ((sourceAspectRatio - targetAspectRatio).abs() < 0.01) {
      return 1.0; // No cropping needed
    }
    
    final targetSize = calculateTargetSize(sourceSize, targetAspectRatio);
    final targetArea = targetSize.width * targetSize.height;
    final sourceArea = sourceSize.width * sourceSize.height;
    
    return targetArea / sourceArea;
  }
  
  /// Gets fallback crop dimensions when smart cropping fails
  /// 
  /// [sourceSize] Size of the source image
  /// [targetAspectRatio] Desired aspect ratio
  /// 
  /// Returns fallback crop coordinates as [x, y, width, height] in relative units
  static List<double> getFallbackCropCoordinates(
    ui.Size sourceSize,
    double targetAspectRatio,
  ) {
    final sourceAspectRatio = sourceSize.width / sourceSize.height;
    
    if (sourceAspectRatio > targetAspectRatio) {
      // Source is wider - crop from sides (center crop)
      final cropWidth = targetAspectRatio / sourceAspectRatio;
      final cropX = (1.0 - cropWidth) / 2.0;
      return [cropX, 0.0, cropWidth, 1.0];
    } else {
      // Source is taller - crop from top/bottom (center crop)
      final cropHeight = sourceAspectRatio / targetAspectRatio;
      final cropY = (1.0 - cropHeight) / 2.0;
      return [0.0, cropY, 1.0, cropHeight];
    }
  }
  
  /// Validates that an aspect ratio is reasonable for display
  /// 
  /// [aspectRatio] The aspect ratio to validate
  /// 
  /// Returns true if the ratio is within reasonable bounds
  static bool isValidAspectRatio(double aspectRatio) {
    // Allow ratios from 0.1 (very tall) to 10.0 (very wide)
    return aspectRatio > 0.1 && aspectRatio < 10.0 && aspectRatio.isFinite;
  }
  
  /// Gets the orientation of an aspect ratio
  /// 
  /// [aspectRatio] The aspect ratio to check
  /// 
  /// Returns 'landscape', 'portrait', or 'square'
  static String getOrientation(double aspectRatio) {
    if ((aspectRatio - 1.0).abs() < 0.001) {
      return 'square';
    } else if (aspectRatio > 1.0) {
      return 'landscape';
    } else {
      return 'portrait';
    }
  }
  
  /// Calculates optimal processing dimensions for analysis
  /// 
  /// [sourceSize] Size of the source image
  /// [maxAnalysisSize] Maximum size for analysis (default 512)
  /// 
  /// Returns optimal size for crop analysis
  static ui.Size getOptimalAnalysisSize(
    ui.Size sourceSize, {
    int maxAnalysisSize = 512,
  }) {
    final aspectRatio = sourceSize.width / sourceSize.height;
    
    if (sourceSize.width <= maxAnalysisSize && sourceSize.height <= maxAnalysisSize) {
      return sourceSize;
    }
    
    if (aspectRatio > 1.0) {
      // Landscape - limit by width
      final width = maxAnalysisSize.toDouble();
      final height = width / aspectRatio;
      return ui.Size(width, height);
    } else {
      // Portrait or square - limit by height
      final height = maxAnalysisSize.toDouble();
      final width = height * aspectRatio;
      return ui.Size(width, height);
    }
  }
}