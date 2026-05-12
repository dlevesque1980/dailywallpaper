import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/services/wallpaper/wallpaper_service.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/services/smart_crop/crop_render_cache.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:mocktail/mocktail.dart';

import 'package:flutter/services.dart';

class MockWallpaperService extends Mock implements WallpaperService {}
class MockPreferencesReader extends Mock implements PreferencesReader {}
class MockCropRenderCache extends Mock implements CropRenderCache {}
class MockImageCacheService extends Mock implements ImageCacheService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApplyWallpaperUseCase useCase;
  late MockWallpaperService mockWallpaperService;
  late MockPreferencesReader mockPreferencesReader;
  late MockCropRenderCache mockCropRenderCache;
  late MockImageCacheService mockImageCache;

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (MethodCall methodCall) async {
        if (methodCall.method == 'getTemporaryDirectory') {
          return '.';
        }
        return null;
      },
    );

    registerFallbackValue('fallback');
    registerFallbackValue(Uint8List(0));
  });

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
    when(() => mockCropRenderCache.getRenderedBytes(any()))
        .thenReturn(null);
    when(() => mockWallpaperService.setBothWallpaper(any()))
        .thenAnswer((_) async => 'Success');
    when(() => mockWallpaperService.setSystemWallpaper(any()))
        .thenAnswer((_) async => 'Success');
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
      final cachedBytes = Uint8List.fromList([10, 20, 30]);
      
      when(() => mockImageCache.getProcessedImageBytes(any()))
          .thenAnswer((_) => Future.value(cachedBytes));
      when(() => mockWallpaperService.setBothWallpaper(any()))
          .thenAnswer((_) => Future.value('Success'));

      final result = await useCase(testImage);

      expect(result, 'wallpaperSetSuccess');
      verify(() => mockImageCache.getProcessedImageBytes(testImage.imageIdent)).called(1);
      verify(() => mockWallpaperService.setBothWallpaper(any())).called(1);
      // Should NOT attempt to load source image if processed bytes are found
      verifyNever(() => mockImageCache.loadSourceImage(any()));
    });

    test('should try loading source from disk if processed bytes are missing', () async {
      when(() => mockImageCache.getProcessedImageBytes(any()))
          .thenAnswer((_) => Future.value(null));
      when(() => mockImageCache.loadSourceImage(any()))
          .thenAnswer((_) => Future.value(null));
      when(() => mockImageCache.loadImageFromUrl(any()))
          .thenAnswer((_) => Future.value(null));

      await useCase(testImage);

      verify(() => mockImageCache.getProcessedImageBytes(testImage.imageIdent)).called(1);
      verify(() => mockImageCache.loadSourceImage(testImage.imageIdent)).called(1);
      verify(() => mockImageCache.loadImageFromUrl(testImage.url)).called(1);
    });
  });
}
