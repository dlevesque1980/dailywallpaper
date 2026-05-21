import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/smart_crop/cache/crop_cache_hit_rate.dart';

void main() {
  group('CropCacheHitRate', () {
    test('hitRatePercentage calculates correctly', () {
      const hitRate = CropCacheHitRate(
        totalEntries: 100,
        averageAccessCount: 2.5,
        maxAccessCount: 10,
        minAccessCount: 1,
        estimatedHitRate: 0.75,
      );

      expect(hitRate.hitRatePercentage, 75.0);
    });

    test('toString formats correctly', () {
      const hitRate = CropCacheHitRate(
        totalEntries: 100,
        averageAccessCount: 2.5,
        maxAccessCount: 10,
        minAccessCount: 1,
        estimatedHitRate: 0.75,
      );

      expect(hitRate.toString(),
          'CropCacheHitRate(entries: 100, hitRate: 75.0%, avgAccess: 2.5)');
    });
  });
}
