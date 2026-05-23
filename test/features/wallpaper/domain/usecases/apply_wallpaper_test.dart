import 'dart:typed_data';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/services/wallpaper/wallpaper_service.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/features/smart_crop/crop_render_cache.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'dart:ui' as ui;
import 'package:dailywallpaper/features/smart_crop/models/crop_coordinates.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';
import 'package:dailywallpaper/features/smart_crop/smart_cropper.dart';
import 'package:mocktail/mocktail.dart';
import 'package:flutter/services.dart';

class MockWallpaperService extends Mock implements WallpaperService {}

class MockPreferencesReader extends Mock implements PreferencesReader {}

class MockCropRenderCache extends Mock implements CropRenderCache {}

class MockImageCacheService extends Mock implements ImageCacheService {}

class FakeImage extends Fake implements ui.Image {}

class FakeCropResult extends Fake implements CropResult {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApplyWallpaperUseCase useCase;
  late MockWallpaperService mockWallpaperService;
  late MockPreferencesReader mockPreferencesReader;
  late MockCropRenderCache mockCropRenderCache;
  late MockImageCacheService mockImageCache;
  late Directory tempDir;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('apply_wallpaper_test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory' ||
            methodCall.method == 'getApplicationDocumentsDirectory') {
          return tempDir.path;
        }
        return null;
      },
    );

    registerFallbackValue('fallback');
    registerFallbackValue(Uint8List(0));
    registerFallbackValue(FakeImage());
    registerFallbackValue(FakeCropResult());
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {}
    }
  });

  Future<ui.Image> createRealImage() async {
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 100, 100), ui.Paint()..color = const ui.Color(0xFF000000));
    final picture = recorder.endRecording();
    return await picture.toImage(100, 100);
  }

  setUp(() {
    mockWallpaperService = MockWallpaperService();
    mockPreferencesReader = MockPreferencesReader();
    mockCropRenderCache = MockCropRenderCache();
    mockImageCache = MockImageCacheService();

    useCase = ApplyWallpaperUseCase(
      wallpaperService: mockWallpaperService,
      prefHelper: mockPreferencesReader,
      cropCache: mockCropRenderCache,
      imageCache: mockImageCache,
    );

    // Default behaviors
    when(() => mockPreferencesReader.getBoolWithDefault(any(), any()))
        .thenAnswer((_) async => true);
    when(() => mockPreferencesReader.getIntWithDefault(any(), any()))
        .thenAnswer((_) async => 1);
    when(() => mockCropRenderCache.getRenderedBytes(any())).thenReturn(null);
    when(() => mockImageCache.saveProcessedImage(any(), any()))
        .thenAnswer((_) async => 'fake_path.png');
    when(() => mockImageCache.downloadAndSaveSourceImage(any(), any()))
        .thenAnswer((_) async => 'fake_source.jpg');
    when(() => mockImageCache.loadCropResultJson(any()))
        .thenAnswer((_) async => null);
    when(() => mockImageCache.loadProcessedImage(any()))
        .thenAnswer((_) async => null);
    when(() => mockImageCache.saveCropResult(any(), any()))
        .thenAnswer((_) async => {});
    when(() => mockWallpaperService.setBothWallpaper(any()))
        .thenAnswer((_) async => 'Success');
    when(() => mockWallpaperService.setSystemWallpaper(any()))
        .thenAnswer((_) async => 'Success');
    when(() => mockImageCache.loadImageFromUrl(any()))
        .thenAnswer((_) async => null);
    when(() => mockImageCache.loadImageFromUrl(any(), client: any(named: 'client')))
        .thenAnswer((_) async => null);
    when(() => mockImageCache.loadSourceImage(any()))
        .thenAnswer((_) async => null);
    when(() => mockImageCache.getProcessedImageBytes(any()))
        .thenAnswer((_) async => null);
  });

  group('ApplyWallpaperUseCase Cache Integration', () {
    final testImage = ImageItem(
      'bing',
      'https://example.com/test.jpg',
      'desc',
      DateTime.parse('2023-05-08'),
      DateTime.parse('2023-05-08'),
      'test_123',
      '',
      '',
      displayOrder: 1,
    );

    test('should use local processed bytes if available', () async {
      final file = File('${tempDir.path}/wallpapers/test_123_processed.png');
      await file.create(recursive: true);
      await file.writeAsString('fake png');

      try {
        final result = await useCase(testImage);
        expect(result, 'wallpaperSetSuccess');
        verify(() => mockWallpaperService.setBothWallpaper('file://${tempDir.path}/wallpapers/test_123_processed.png')).called(1);
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });

    test('should try loading source from disk if processed bytes are missing',
        () async {
      when(() => mockImageCache.loadSourceImage(any()))
          .thenAnswer((_) => Future.value(null));
      when(() => mockImageCache.loadImageFromUrl(any()))
          .thenAnswer((_) => Future.value(null));

      await useCase(testImage);

      verify(() => mockImageCache.loadSourceImage(testImage.imageIdent))
          .called(1);
      verify(() => mockImageCache.loadImageFromUrl(testImage.url)).called(1);
    });

    test('should apply saved CropCoordinates when processed PNG missing (source on disk)', () async {
      final sourceImg = await createRealImage();
      
      final fakeCrop = CropResult(
        bestCrop: CropCoordinates(x: 0, y: 0, width: 1, height: 1, confidence: 1, strategy: 'test', subjectBounds: null),
        allScores: [],
        processingTime: Duration.zero,
        fromCache: true,
        performanceMetrics: PerformanceMetrics.empty(),
        analyzerMetadata: {},
        scoringBreakdown: {},
      );
      final imageWithCoords = testImage.copyWith(cropResultJson: fakeCrop.serialize());

      when(() => mockImageCache.getProcessedImageBytes(any())).thenAnswer((_) => Future.value(null));
      when(() => mockImageCache.loadSourceImage(any())).thenAnswer((_) => Future.value(sourceImg));
      when(() => mockWallpaperService.setBothWallpaper(any())).thenAnswer((_) => Future.value('Success'));

      final result = await useCase(imageWithCoords);

      expect(result, 'wallpaperSetSuccess');
      verify(() => mockWallpaperService.setBothWallpaper(any())).called(1);
      verifyNever(() => mockImageCache.loadImageFromUrl(any()));
    });

    test('should apply coords after download when source missing but cropResultJson in DB (History > 2j)', () async {
      final downloadedImg = await createRealImage();
      
      final fakeCrop = CropResult(
        bestCrop: CropCoordinates(x: 0, y: 0, width: 1, height: 1, confidence: 1, strategy: 'test', subjectBounds: null),
        allScores: [],
        processingTime: Duration.zero,
        fromCache: true,
        performanceMetrics: PerformanceMetrics.empty(),
        analyzerMetadata: {},
        scoringBreakdown: {},
      );
      final imageWithCoords = testImage.copyWith(cropResultJson: fakeCrop.serialize());

      when(() => mockImageCache.getProcessedImageBytes(any())).thenAnswer((_) => Future.value(null));
      when(() => mockImageCache.loadSourceImage(any())).thenAnswer((_) => Future.value(null));
      when(() => mockImageCache.loadImageFromUrl(any())).thenAnswer((_) => Future.value(downloadedImg));
      when(() => mockWallpaperService.setBothWallpaper(any())).thenAnswer((_) => Future.value('Success'));

      final result = await useCase(imageWithCoords);

      expect(result, 'wallpaperSetSuccess');
      verify(() => mockImageCache.loadImageFromUrl(imageWithCoords.url)).called(1);
      verify(() => mockWallpaperService.setBothWallpaper(any())).called(1);
    });

    test('should use raw source bytes when coords and PNG both missing', () async {
      final sourceImg = await createRealImage();
      // testImage has no cropResultJson
      when(() => mockImageCache.getProcessedImageBytes(any())).thenAnswer((_) => Future.value(null));
      when(() => mockImageCache.loadSourceImage(any())).thenAnswer((_) => Future.value(sourceImg));
      when(() => mockWallpaperService.setBothWallpaper(any())).thenAnswer((_) => Future.value('Success'));

      final result = await useCase(testImage);

      expect(result, 'wallpaperSetSuccess');
      verify(() => mockWallpaperService.setBothWallpaper(any())).called(1);
    });

    test('should return failedToSetWallpaper when wallpaper service throws', () async {
      final file = File('${tempDir.path}/wallpapers/test_123_processed.png');
      await file.create(recursive: true);
      await file.writeAsString('fake png');

      when(() => mockWallpaperService.setBothWallpaper(any()))
          .thenThrow(Exception('Failed to set'));

      try {
        final result = await useCase(testImage);
        expect(result, 'failedToSetWallpaper');
      } finally {
        if (await file.exists()) {
          await file.delete();
        }
      }
    });
  });
}
