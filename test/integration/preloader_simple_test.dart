import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/services/intelligent_cache_service.dart';
import 'package:dailywallpaper/models/image_item.dart';

void main() {
  group('Preloader Simple Tests', () {
    test('should create services without errors', () {
      final preloaderService = ImagePreloaderService();
      final cacheService = IntelligentCacheService();

      expect(preloaderService, isNotNull);
      expect(cacheService, isNotNull);
    });

    test('should handle basic operations', () {
      final preloaderService = ImagePreloaderService();
      final cacheService = IntelligentCacheService();

      // Test des opérations de base sans chargement d'images
      final now = DateTime.now();
      final testImage = ImageItem(
        'Test Source',
        'https://example.com/test.jpg',
        'Test Image',
        now,
        now.add(Duration(days: 1)),
        'test_1',
        null,
        'Test Copyright',
      );

      // Ces méthodes ne devraient pas lever d'exception
      expect(preloaderService.getPreloadedImage(testImage), isNull);
      expect(preloaderService.getProcessedImage(testImage), isNull);
      expect(preloaderService.isLoading(testImage), isFalse);
      expect(preloaderService.isProcessing(testImage), isFalse);

      expect(cacheService.contains('test_key'), isFalse);
      expect(cacheService.get('test_key'), isNull);
    });

    test('should maintain singleton pattern', () {
      final preloader1 = ImagePreloaderService();
      final preloader2 = ImagePreloaderService();
      final cache1 = IntelligentCacheService();
      final cache2 = IntelligentCacheService();

      expect(identical(preloader1, preloader2), isTrue);
      expect(identical(cache1, cache2), isTrue);
    });

    test('should handle stats correctly', () {
      final cacheService = IntelligentCacheService();
      final stats = cacheService.getStats();

      expect(stats, isA<Map<String, dynamic>>());
      expect(stats.containsKey('size'), isTrue);
      expect(stats.containsKey('maxSize'), isTrue);
      expect(stats.containsKey('hitRate'), isTrue);
      expect(stats.containsKey('memoryUsage'), isTrue);
    });
  });
}
