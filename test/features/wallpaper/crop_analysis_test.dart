import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/services/smart_crop/models/crop_coordinates.dart';

void main() {
  group('Crop Analysis Functional Tests', () {
    PerformanceMetrics createMockMetrics() => PerformanceMetrics(
          totalTime: const Duration(milliseconds: 100),
          analyzerTimes: {'test': const Duration(milliseconds: 100)},
          memoryUsage: 1024,
          analyzersExecuted: 1,
          analyzersSkipped: 0,
          cacheHitRate: 0.0,
        );

    test('ImageItem should correctly store and retrieve smartCropResult', () {
      // Setup
      final image = ImageItem(
        "Source",
        "https://example.com/image.jpg",
        "Description",
        DateTime.now(),
        DateTime.now().add(const Duration(days: 1)),
        "image_ident",
        null,
        "Copyright",
      );

      final mockCropResult = CropResult(
        bestCrop: CropCoordinates(
          x: 0.1,
          y: 0.1,
          width: 0.8,
          height: 0.8,
          confidence: 0.95,
          strategy: 'test_strategy',
        ),
        allScores: [],
        processingTime: const Duration(milliseconds: 100),
        fromCache: false,
        analyzerMetadata: {'test': 'data'},
        performanceMetrics: createMockMetrics(),
        scoringBreakdown: {'test_strategy': 0.95},
      );

      // Verify initial state
      expect(image.smartCropResult, isNull);

      // Act: Simulate what ImagePreloaderService now does
      image.smartCropResult = mockCropResult;

      // Assert
      expect(image.smartCropResult, isNotNull);
      expect(image.smartCropResult!.bestCrop.strategy, 'test_strategy');
      expect(image.smartCropResult!.bestCrop.confidence, 0.95);
    });

    test('ImageItem.copyWith should preserve smartCropResult', () {
      // Setup
      final image = ImageItem(
        "Source",
        "url",
        "desc",
        DateTime.now(),
        DateTime.now(),
        "id",
        null,
        "copy",
      );
      
      final mockCropResult = CropResult(
        bestCrop: CropCoordinates(
          x: 0, y: 0, width: 1, height: 1, 
          confidence: 1.0, strategy: 'full'
        ),
        allScores: [],
        processingTime: Duration.zero,
        fromCache: true,
        analyzerMetadata: {},
        performanceMetrics: createMockMetrics(),
        scoringBreakdown: {'full': 1.0},
      );
      
      image.smartCropResult = mockCropResult;

      // Act
      final copiedImage = image.copyWith(description: "new desc");

      // Assert
      expect(copiedImage.description, "new desc");
      expect(copiedImage.smartCropResult, isNotNull);
      expect(copiedImage.smartCropResult!.bestCrop.strategy, 'full');
    });
  });
}
