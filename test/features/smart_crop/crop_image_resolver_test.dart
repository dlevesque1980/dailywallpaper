import 'dart:ui' as ui;
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sqflite/sqflite.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_settings.dart';
import 'package:dailywallpaper/features/smart_crop/services/crop_image_resolver.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import '../../fakes/fake_image_cache_service.dart';
import '../../fakes/fake_image.dart';

Future<ui.Image> createRealImage() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 100, 100), ui.Paint()..color = const ui.Color(0xFF000000));
  final picture = recorder.endRecording();
  return await picture.toImage(100, 100);
}
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  late FakeImageCacheService fakeImageCache;
  late ImageItem mockImage;
  late ui.Image mockSourceImage;
  late CropSettings defaultSettings;

  setUp(() async {
    SmartCropper.clearCache();
    fakeImageCache = FakeImageCacheService();
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
    mockSourceImage = await createRealImage();
    defaultSettings = CropSettings();
  });

  group('CropImageResolver', () {
    test('applies saved coords when PNG missing but cropResultJson present', () async {
      // Arrange
      final fakeCoords = CropCoordinates(
        x: 0.1, y: 0.1, width: 0.8, height: 0.8,
        confidence: 0.9, strategy: 'test',
        subjectBounds: null,
      );
      final fakeCropResult = CropResult(
        bestCrop: fakeCoords,
        allScores: [],
        processingTime: const Duration(milliseconds: 10),
        fromCache: true,
        performanceMetrics: PerformanceMetrics.empty(),
        analyzerMetadata: {},
        scoringBreakdown: {},
      );

      mockImage.cropResultJson = fakeCropResult.serialize();

      // Act
      final result = await CropImageResolver.resolve(
        image: mockImage,
        sourceImage: mockSourceImage,
        targetSize: const ui.Size(800, 800),
        settings: defaultSettings,
        imageCache: fakeImageCache,
      );

      // Assert
      expect(result.isFromCoords, isTrue);
      expect(result.isFromPipeline, isFalse);
    });

    test('falls back to full pipeline only when no coords anywhere', () async {
      mockImage.imageIdent = "image_ident_test_2";
      
      // Act
      final result = await CropImageResolver.resolve(
        image: mockImage,
        sourceImage: mockSourceImage,
        targetSize: const ui.Size(800, 800),
        settings: defaultSettings,
        imageCache: fakeImageCache,
      );

      // Assert
      expect(result.isFromPipeline, isTrue);
    });
  });
}
