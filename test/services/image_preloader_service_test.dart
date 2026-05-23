import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/services/image_preloader_service.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import '../fakes/fake_image_cache_service.dart';

class MockImage extends Mock implements ui.Image {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ImagePreloaderService', () {
    late ImagePreloaderService service;
    late FakeImageCacheService fakeCache;
    late ImageItem mockImage;
    late File tempFile;
    final mockImageObj = MockImage();

    setUp(() async {
      fakeCache = FakeImageCacheService();
      service = ImagePreloaderService.forTesting(fakeCache);
      ImagePreloaderService.setInstance(service);

      // Create a temporary file to simulate that the cropped image is already present on disk
      final tempDir = Directory.systemTemp;
      tempFile = File('${tempDir.path}/fake_processed_image_ident_test_${DateTime.now().microsecondsSinceEpoch}.png');
      await tempFile.writeAsString('fake content');

      mockImage = ImageItem(
        "Source",
        "https://example.com/image.jpg",
        "Description",
        DateTime.now(),
        DateTime.now().add(const Duration(days: 1)),
        "image_ident_test",
        null,
        "Copyright",
        localProcessedPath: tempFile.path,
      );
    });

    tearDown(() async {
      if (await tempFile.exists()) {
        try {
          await tempFile.delete();
        } catch (_) {}
      }
    });

    test('preloadCurrentImageWithCrop successfully short-circuits when cropped image exists on disk', () async {
      // Setup the fake cache returns
      fakeCache.processedImages['image_ident_test'] = mockImageObj;
      
      const fakeCropResultJson = '{"bestCrop":{"x":0.1,"y":0.2,"width":0.3,"height":0.4,"confidence":0.95,"strategy":"test_strategy","scalingApplied":false},"allScores":[{"coordinates":{"x":0.1,"y":0.2,"width":0.3,"height":0.4,"confidence":0.95,"strategy":"test_strategy","scalingApplied":false},"score":0.95,"strategy":"test_strategy","metrics":{}}],"processingTime":100,"fromCache":false,"analyzerMetadata":{},"performanceMetrics":{"totalTime":100,"analyzerTimes":{},"memoryUsage":0,"analyzersExecuted":1,"analyzersSkipped":0,"cacheHitRate":0.0},"scoringBreakdown":{"test_strategy":0.95}}';
      fakeCache.cropResultJsons['image_ident_test'] = fakeCropResultJson;

      // Run preload
      await service.preloadCurrentImageWithCrop(mockImage);

      // Verify that getProcessedImage returns our mocked image
      final processedImg = service.getProcessedImage(mockImage);
      expect(processedImg, equals(mockImageObj));

      // Verify in SmartCropper cache too
      final smartCropperCachedImg = SmartCropper.getProcessedImage('image_ident_test');
      expect(smartCropperCachedImg, equals(mockImageObj));

      // Verify that crop result coordinates JSON & CropResult are correctly hydrated in memory
      expect(mockImage.cropResultJson, equals(fakeCropResultJson));
      expect(mockImage.smartCropResult, isNotNull);
      expect(mockImage.smartCropResult!.bestCrop.x, 0.1);
      expect(mockImage.smartCropResult!.bestCrop.y, 0.2);
      expect(mockImage.smartCropResult!.bestCrop.width, 0.3);
      expect(mockImage.smartCropResult!.bestCrop.height, 0.4);
      expect(mockImage.smartCropResult!.bestCrop.confidence, 0.95);
      expect(mockImage.smartCropResult!.bestCrop.strategy, "test_strategy");
    });
  });
}
