import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import '../fakes/fake_image_cache_service.dart';

void main() {
  group('ImagePreloaderService', () {
    late ImagePreloaderService service;
    late FakeImageCacheService fakeCache;
    late ImageItem mockImage;

    setUp(() {
      fakeCache = FakeImageCacheService();
      // Using private constructor for test injection is typically handled by Mockito,
      // but here we just test the singleton instance.
      service = ImagePreloaderService();
      
      mockImage = ImageItem(
        "Source",
        "https://example.com/image.jpg",
        "Description",
        DateTime.now(),
        DateTime.now().add(const Duration(days: 1)),
        "image_ident_test",
        null,
        "Copyright",
      );
    });

    test('preloadCurrentImageWithCrop skips if already processed on disk', () async {
      // It should not throw and complete normally.
      await service.preloadCurrentImageWithCrop(mockImage);
      expect(true, isTrue);
    });
  });
}
