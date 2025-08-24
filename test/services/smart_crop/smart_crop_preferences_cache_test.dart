import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../lib/services/smart_crop/smart_crop_preferences.dart';

void main() {
  group('SmartCropPreferences Cache Management', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('should get cache statistics', () async {
      final stats = await SmartCropPreferences.getCacheStatistics();
      
      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('totalEntries'), true);
      expect(stats.containsKey('totalSizeMB'), true);
      expect(stats.containsKey('hitRatePercentage'), true);
      expect(stats.containsKey('cacheAgeDays'), true);
      
      // Should have default values for empty cache
      expect(stats['totalEntries'], 0);
      expect(stats['totalSizeMB'], 0.0);
      expect(stats['hitRatePercentage'], 0.0);
      expect(stats['cacheAgeDays'], 0);
    });

    test('should clear cache', () async {
      final deletedCount = await SmartCropPreferences.clearCropCache();
      
      // Should return 0 for empty cache
      expect(deletedCount, 0);
    });

    test('should optimize cache', () async {
      final optimizedCount = await SmartCropPreferences.optimizeCropCache();
      
      // Should return 0 for empty cache
      expect(optimizedCount, 0);
    });

    test('should perform cache maintenance', () async {
      final result = await SmartCropPreferences.performCacheMaintenance();
      
      expect(result, isA<Map<String, dynamic>>());
      expect(result.containsKey('expiredDeleted'), true);
      expect(result.containsKey('lruDeleted'), true);
      expect(result.containsKey('totalDeleted'), true);
      expect(result.containsKey('success'), true);
      
      // Should have default values for empty cache
      expect(result['expiredDeleted'], 0);
      expect(result['lruDeleted'], 0);
      expect(result['totalDeleted'], 0);
    });
  });
}