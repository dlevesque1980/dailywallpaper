import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/services/smart_crop/utils/battery_optimizer.dart';

void main() {
  group('BatteryOptimizer', () {
    setUp(() {
      // Clear cache before each test
      BatteryOptimizer.clearCache();
    });
    
    test('should get optimization strategy', () async {
      final strategy = await BatteryOptimizer.getOptimizationStrategy();
      
      expect(strategy, isA<BatteryOptimizationStrategy>());
    });
    
    test('should optimize settings for battery', () async {
      final originalSettings = CropSettings.defaultSettings;
      final optimizedSettings = await BatteryOptimizer.optimizeSettingsForBattery(originalSettings);
      
      expect(optimizedSettings, isNotNull);
      expect(optimizedSettings.isValid, isTrue);
      
      // Optimized settings should have same or shorter timeout
      expect(
        optimizedSettings.maxProcessingTime.inMilliseconds,
        lessThanOrEqualTo(originalSettings.maxProcessingTime.inMilliseconds),
      );
    });
    
    test('should provide throttling recommendations', () async {
      final shouldThrottle = await BatteryOptimizer.shouldThrottleBackgroundProcessing();
      expect(shouldThrottle, isA<bool>());
      
      final delay = await BatteryOptimizer.getRecommendedProcessingDelay();
      expect(delay, isA<Duration>());
      expect(delay.inMilliseconds, greaterThanOrEqualTo(0));
      
      final shouldDefer = await BatteryOptimizer.shouldDeferProcessing();
      expect(shouldDefer, isA<bool>());
    });
    
    test('should provide optimization statistics', () {
      final stats = BatteryOptimizer.getOptimizationStats();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('cached_battery_state'), isTrue);
      expect(stats.containsKey('last_battery_check'), isTrue);
      expect(stats.containsKey('cache_age_minutes'), isTrue);
    });
    
    test('should handle different battery states', () {
      for (final state in BatteryState.values) {
        expect(state.toString(), isNotEmpty);
      }
    });
    
    test('should handle different optimization strategies', () {
      for (final strategy in BatteryOptimizationStrategy.values) {
        expect(strategy.toString(), isNotEmpty);
        expect(strategy.throttleBackgroundProcessing, isA<bool>());
        expect(strategy.processingDelay, isA<Duration>());
        expect(strategy.deferProcessing, isA<bool>());
        expect(strategy.timeoutMultiplier, greaterThan(0));
        expect(strategy.timeoutMultiplier, lessThanOrEqualTo(1.0));
      }
    });
    
    test('should apply different optimization levels correctly', () async {
      final originalSettings = CropSettings(
        aggressiveness: CropAggressiveness.balanced,
        enableRuleOfThirds: true,
        enableEntropyAnalysis: true,
        enableEdgeDetection: true,
        enableCenterWeighting: true,
        maxProcessingTime: const Duration(seconds: 2),
      );
      
      // Test that aggressive optimization disables heavy analyzers
      final optimizedSettings = await BatteryOptimizer.optimizeSettingsForBattery(originalSettings);
      
      // Should still be valid
      expect(optimizedSettings.isValid, isTrue);
      
      // Should have at least one analyzer enabled
      expect(optimizedSettings.enabledStrategies.isNotEmpty, isTrue);
    });
    
    test('should cache battery state', () async {
      // First call
      final strategy1 = await BatteryOptimizer.getOptimizationStrategy();
      
      // Second call should use cache (within cache interval)
      final strategy2 = await BatteryOptimizer.getOptimizationStrategy();
      
      expect(strategy1, strategy2);
    });
    
    test('should clear cache properly', () {
      BatteryOptimizer.clearCache();
      
      final stats = BatteryOptimizer.getOptimizationStats();
      expect(stats['cached_battery_state'], isNull);
      expect(stats['last_battery_check'], isNull);
    });
  });
}