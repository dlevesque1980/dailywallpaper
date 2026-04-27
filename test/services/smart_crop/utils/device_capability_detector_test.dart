import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/smart_crop/utils/device_capability_detector.dart';

void main() {
  group('DeviceCapabilityDetector', () {
    setUp(() {
      // Clear cache before each test
      DeviceCapabilityDetector.clearCache();
    });
    
    test('should detect device capability', () async {
      final capability = await DeviceCapabilityDetector.getDeviceCapability();
      
      expect(capability, isNotNull);
      expect(capability.platform, isA<DevicePlatform>());
      expect(capability.overallTier, isA<PerformanceTier>());
      expect(capability.maxConcurrentAnalyzers, greaterThan(0));
      expect(capability.maxImageDimension, greaterThan(0));
      expect(capability.timeoutMultiplier, greaterThan(0));
    });
    
    test('should cache capability assessment', () async {
      final capability1 = await DeviceCapabilityDetector.getDeviceCapability();
      final capability2 = await DeviceCapabilityDetector.getDeviceCapability();
      
      // Should return the same instance (cached)
      expect(identical(capability1, capability2), isTrue);
    });
    
    test('should clear cache', () async {
      final capability1 = await DeviceCapabilityDetector.getDeviceCapability();
      
      DeviceCapabilityDetector.clearCache();
      
      final capability2 = await DeviceCapabilityDetector.getDeviceCapability();
      
      // Should return different instances after cache clear
      expect(identical(capability1, capability2), isFalse);
    });
    
    test('should create conservative capability on error', () {
      final conservative = DeviceCapability.conservative();
      
      expect(conservative.platform, DevicePlatform.unknown);
      expect(conservative.overallTier, PerformanceTier.low);
      expect(conservative.batteryOptimized, isTrue);
      expect(conservative.maxConcurrentAnalyzers, 1);
      expect(conservative.maxImageDimension, 256);
    });
    
    test('should provide correct capability properties', () async {
      final capability = await DeviceCapabilityDetector.getDeviceCapability();
      
      // Test boolean properties
      expect(capability.isHighPerformance, capability.overallTier == PerformanceTier.high);
      expect(capability.isLowPerformance, capability.overallTier == PerformanceTier.low);
      
      // Test platform detection
      final isMobile = capability.platform == DevicePlatform.android || 
                      capability.platform == DevicePlatform.ios;
      expect(capability.isMobile, isMobile);
      
      final isDesktop = capability.platform == DevicePlatform.macos || 
                       capability.platform == DevicePlatform.windows || 
                       capability.platform == DevicePlatform.linux;
      expect(capability.isDesktop, isDesktop);
    });
    
    test('should have valid performance tier values', () {
      for (final tier in PerformanceTier.values) {
        expect(tier.index, greaterThanOrEqualTo(0));
        expect(tier.index, lessThan(PerformanceTier.values.length));
      }
    });
    
    test('should have valid platform values', () {
      for (final platform in DevicePlatform.values) {
        expect(platform.toString(), isNotEmpty);
      }
    });
    
    test('should provide string representation', () async {
      final capability = await DeviceCapabilityDetector.getDeviceCapability();
      final stringRep = capability.toString();
      
      expect(stringRep, contains('DeviceCapability'));
      expect(stringRep, contains('platform'));
      expect(stringRep, contains('overallTier'));
    });
  });
}