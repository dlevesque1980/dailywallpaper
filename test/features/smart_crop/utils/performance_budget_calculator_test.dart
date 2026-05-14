import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/smart_crop/utils/performance_budget_calculator.dart';
import 'package:dailywallpaper/features/smart_crop/utils/device_capability_detector.dart';

void main() {
  group('PerformanceBudgetCalculator', () {
    late PerformanceBudgetCalculator calculator;

    setUp(() {
      calculator = PerformanceBudgetCalculator();
    });

    test('calculateProcessingBudget applies multiplier and memory reduction', () {
      final capabilities = const DeviceCapability(
        platform: DevicePlatform.android,
        isEmulator: false,
        memoryTier: PerformanceTier.high,
        processingTier: PerformanceTier.high,
        overallTier: PerformanceTier.high,
        batteryOptimized: false,
        maxConcurrentAnalyzers: 4,
        maxImageDimension: 2048,
        useIsolateThreshold: 1000,
        timeoutMultiplier: 1.5,
      );

      final budgetLowMemory = calculator.calculateProcessingBudget(capabilities, false);
      // High perf -> 3s * 1.5 = 4500ms
      expect(budgetLowMemory.inMilliseconds, 4500);

      final budgetHighMemory = calculator.calculateProcessingBudget(capabilities, true);
      // High perf -> 4500ms * 0.8 = 3600ms
      expect(budgetHighMemory.inMilliseconds, 3600);
    });

    test('calculateProcessingBudget reduces base budget for low performance', () {
      final capabilities = const DeviceCapability(
        platform: DevicePlatform.android,
        isEmulator: false,
        memoryTier: PerformanceTier.low,
        processingTier: PerformanceTier.low,
        overallTier: PerformanceTier.low,
        batteryOptimized: false,
        maxConcurrentAnalyzers: 1,
        maxImageDimension: 1024,
        useIsolateThreshold: 500,
        timeoutMultiplier: 1.0,
      );

      final budget = calculator.calculateProcessingBudget(capabilities, false);
      // Low perf -> 1500ms
      expect(budget.inMilliseconds, 1500);
    });
  });
}
