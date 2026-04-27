import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/services/intelligent_cache_service.dart';
import 'package:dailywallpaper/data/models/image_item.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('Preloader Integration Tests', () {
    late ImagePreloaderService preloaderService;
    late IntelligentCacheService cacheService;
    late List<ImageItem> testImages;

    setUp(() {
      preloaderService = ImagePreloaderService();
      cacheService = IntelligentCacheService();

      // Nettoyer les caches
      preloaderService.clearCache();
      cacheService.clear();

      // Créer des images de test
      final now = DateTime.now();
      testImages = [
        ImageItem(
          'Bing',
          'https://picsum.photos/800/600?random=1',
          'Test Bing Image',
          now,
          now.add(Duration(days: 1)),
          'bing_test_1',
          null,
          'Bing Copyright',
        ),
        ImageItem(
          'Pexels',
          'https://picsum.photos/800/600?random=2',
          'Test Pexels Image',
          now,
          now.add(Duration(days: 1)),
          'pexels_test_2',
          null,
          'Pexels Copyright',
        ),
        ImageItem(
          'NASA',
          'https://picsum.photos/800/600?random=3',
          'Test NASA Image',
          now,
          now.add(Duration(days: 1)),
          'nasa_test_3',
          null,
          'NASA Copyright',
        ),
      ];
    });

    tearDown(() {
      preloaderService.clearCache();
      cacheService.clear();
    });

    test('should work together without conflicts', () async {
      // Test que les deux services peuvent coexister
      expect(preloaderService, isNotNull);
      expect(cacheService, isNotNull);

      // Test des opérations de base
      await preloaderService.preloadImages(testImages, 0);

      final stats = cacheService.getStats();
      expect(stats, isNotNull);
      expect(stats['size'], isA<int>());
    });

    test('should handle multiple preload requests', () async {
      // Premier préchargement
      await preloaderService.preloadImages(testImages, 0);

      // Deuxième préchargement avec un index différent
      await preloaderService.preloadImages(testImages, 1);

      // Troisième préchargement
      await preloaderService.preloadImages(testImages, 2);

      // Aucune exception ne devrait être levée
      expect(true, isTrue);
    });

    test('should handle cache operations during preloading', () async {
      // Démarrer le préchargement
      final preloadFuture = preloaderService.preloadImages(testImages, 0);

      // Effectuer des opérations de cache en parallèle
      final stats1 = cacheService.getStats();
      cacheService.clear();
      final stats2 = cacheService.getStats();

      // Attendre la fin du préchargement
      await preloadFuture;

      expect(stats1, isNotNull);
      expect(stats2, isNotNull);
      expect(stats2['size'], equals(0)); // Cache vidé
    });

    test('should maintain singleton behavior', () {
      final preloader1 = ImagePreloaderService();
      final preloader2 = ImagePreloaderService();
      final cache1 = IntelligentCacheService();
      final cache2 = IntelligentCacheService();

      expect(identical(preloader1, preloader2), isTrue);
      expect(identical(cache1, cache2), isTrue);
    });

    test('should handle empty and null scenarios gracefully', () async {
      // Test avec liste vide
      await preloaderService.preloadImages([], 0);

      // Test avec index négatif
      await preloaderService.preloadImages(testImages, -1);

      // Test avec index trop grand
      await preloaderService.preloadImages(testImages, 999);

      // Aucune exception ne devrait être levée
      expect(true, isTrue);
    });
  });
}
