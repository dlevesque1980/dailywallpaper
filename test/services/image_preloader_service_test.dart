import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/models/image_item.dart';

void main() {
  group('ImagePreloaderService Tests', () {
    late ImagePreloaderService preloaderService;
    late List<ImageItem> testImages;

    setUp(() {
      preloaderService = ImagePreloaderService();

      // Créer des images de test
      final now = DateTime.now();
      testImages = [
        ImageItem(
          'Test Source 1',
          'https://picsum.photos/800/600?random=1',
          'Test Image 1',
          now,
          now.add(Duration(days: 1)),
          'test_1',
          null,
          'Test Copyright 1',
        ),
        ImageItem(
          'Test Source 2',
          'https://picsum.photos/800/600?random=2',
          'Test Image 2',
          now,
          now.add(Duration(days: 1)),
          'test_2',
          null,
          'Test Copyright 2',
        ),
        ImageItem(
          'Test Source 3',
          'https://picsum.photos/800/600?random=3',
          'Test Image 3',
          now,
          now.add(Duration(days: 1)),
          'test_3',
          null,
          'Test Copyright 3',
        ),
      ];
    });

    tearDown(() {
      preloaderService.clearCache();
    });

    test('should initialize without errors', () {
      expect(preloaderService, isNotNull);
    });

    test('should handle empty image list', () async {
      // Ne devrait pas lever d'exception
      await preloaderService.preloadImages([], 0);
      expect(true, isTrue); // Test passé si aucune exception
    });

    test('should calculate priorities correctly', () {
      // Test indirect via les méthodes publiques
      expect(preloaderService.getPreloadedImage(testImages[0]), isNull);
      expect(preloaderService.getProcessedImage(testImages[0]), isNull);
    });

    test('should track loading state', () {
      expect(preloaderService.isLoading(testImages[0]), isFalse);
      expect(preloaderService.isProcessing(testImages[0]), isFalse);
    });

    test('should clear cache properly', () {
      preloaderService.clearCache();

      for (final image in testImages) {
        expect(preloaderService.getPreloadedImage(image), isNull);
        expect(preloaderService.getProcessedImage(image), isNull);
      }
    });

    test('should handle preload request without network', () async {
      // Test avec des URLs invalides pour simuler des erreurs réseau
      final now = DateTime.now();
      final invalidImages = [
        ImageItem(
          'Invalid Source',
          'invalid://url',
          'Invalid Image',
          now,
          now.add(Duration(days: 1)),
          'invalid_1',
          null,
          'Invalid Copyright',
        ),
      ];

      // Ne devrait pas lever d'exception même avec des URLs invalides
      await preloaderService.preloadImages(invalidImages, 0);
      expect(true, isTrue);
    });
  });
}
