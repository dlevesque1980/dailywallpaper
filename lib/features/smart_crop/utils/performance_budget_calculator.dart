import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/features/smart_crop/utils/device_capability_detector.dart';

class PerformanceBudgetCalculator {
  /// Determines optimal quality based on device capabilities
  Future<CropAggressiveness> determineOptimalQuality() async {
    final capabilities = await DeviceCapabilityDetector.getDeviceCapability();

    if (capabilities.isHighPerformance) {
      return CropAggressiveness.aggressive;
    } else if (capabilities.overallTier == PerformanceTier.medium) {
      return CropAggressiveness.balanced;
    } else {
      return CropAggressiveness.conservative;
    }
  }

  /// Calculates processing budget based on conditions
  Duration calculateProcessingBudget(
    DeviceCapability capabilities,
    bool isMemoryHigh,
  ) {
    var baseBudget = const Duration(seconds: 2);

    // Adjust based on device capabilities
    if (capabilities.isHighPerformance) {
      baseBudget = const Duration(seconds: 3);
    } else if (capabilities.isLowPerformance) {
      baseBudget = const Duration(milliseconds: 1500);
    }

    // Apply timeout multiplier from device capabilities
    baseBudget = Duration(
      milliseconds:
          (baseBudget.inMilliseconds * capabilities.timeoutMultiplier).round(),
    );

    // Reduce budget if memory is constrained
    if (isMemoryHigh) {
      baseBudget = Duration(
        milliseconds: (baseBudget.inMilliseconds * 0.8).round(),
      );
    }

    return baseBudget;
  }
}
