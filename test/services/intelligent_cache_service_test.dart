import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/intelligent_cache_service.dart';

void main() {
  group('IntelligentCacheService Tests', () {
    late IntelligentCacheService cacheService;

    setUp(() {
      cacheService = IntelligentCacheService();
      cacheService.clear(); // S'assurer que le cache est vide
    });

    tearDown(() {
      cacheService.clear();
    });

    test('should initialize as singleton', () {
      final instance1 = IntelligentCacheService();
      final instance2 = IntelligentCacheService();
      expect(identical(instance1, instance2), isTrue);
    });

    test('should handle empty cache', () {
      expect(cacheService.get('nonexistent'), isNull);
      expect(cacheService.contains('nonexistent'), isFalse);
    });

    test('should return correct stats for empty cache', () {
      final stats = cacheService.getStats();
      expect(stats['size'], equals(0));
      expect(stats['maxSize'], equals(15));
      expect(stats['hitRate'], equals(0.0));
      expect(stats['memoryUsage'], equals(0));
    });

    test('should clear cache properly', () {
      cacheService.clear();
      final stats = cacheService.getStats();
      expect(stats['size'], equals(0));
    });

    test('should handle cache operations without real images', () {
      // Test les opérations de base sans vraies images UI
      expect(cacheService.contains('test_key'), isFalse);
      cacheService
          .remove('nonexistent_key'); // Ne devrait pas lever d'exception
      expect(true, isTrue);
    });

    test('should calculate memory usage correctly for empty cache', () {
      final stats = cacheService.getStats();
      expect(stats['memoryUsage'], equals(0));
    });

    test('should handle multiple clear operations', () {
      cacheService.clear();
      cacheService.clear(); // Double clear ne devrait pas poser de problème
      expect(cacheService.getStats()['size'], equals(0));
    });
  });
}
