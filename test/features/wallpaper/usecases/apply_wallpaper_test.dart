import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart';
import '../../../fakes/fake_wallpaper_service.dart';
import '../../../fakes/fake_preferences_reader.dart';
import '../../../fakes/fake_crop_render_cache.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});
  
  late FakeWallpaperService fakeWallpaperService;
  late FakePreferencesReader fakePrefs;
  late FakeCropRenderCache fakeCropCache;
  late ApplyWallpaperUseCase useCase;

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
  });

  setUp(() {
    fakeWallpaperService = FakeWallpaperService();
    fakePrefs = FakePreferencesReader();
    fakeCropCache = FakeCropRenderCache();
    useCase = ApplyWallpaperUseCase(
      wallpaperService: fakeWallpaperService,
      prefHelper: fakePrefs,
      cropCache: fakeCropCache,
    );
  });

  final mockImage = ImageItem(
    "Source",
    "https://example.com/image.jpg",
    "Description",
    DateTime.now(),
    DateTime.now().add(const Duration(days: 1)),
    "image_ident",
    null,
    "Copyright",
  );

  group('ApplyWallpaperUseCase', () {
    test('should set both wallpapers when sp_IncludeLockWallpaper is true', () async {
      // Arrange
      fakePrefs.put(sp_IncludeLockWallpaper, true);

      // Act
      final result = await useCase(mockImage);

      // Assert
      expect(result, 'wallpaperSetSuccess');
      expect(fakeWallpaperService.lastSetUrl, mockImage.url);
    });

    test('should throw when wallpaper service fails', () async {
      // Arrange
      fakePrefs.put(sp_IncludeLockWallpaper, true);
      fakeWallpaperService.shouldThrow = true;
      fakeWallpaperService.throwMessage = 'Failed to set';

      // Act & Assert
      expect(() => useCase(mockImage), throwsException);
    });

    group('WYSIWYG (What You See Is What You Get)', () {
      test('should apply EXACT carousel bytes when available', () async {
        // Arrange: Carousel has already rendered this image with its crop/scale
        final carouselBytes = Uint8List.fromList([1, 2, 3, 4, 5]);
        fakeCropCache.setRenderedBytes(mockImage.imageIdent, carouselBytes);
        fakePrefs.put(sp_IncludeLockWallpaper, true);

        // Act
        await useCase(mockImage);

        // Assert: Service receives a file URL pointing to the written bytes
        expect(fakeWallpaperService.lastSetUrl, startsWith('file://./temp_wallpaper_'));
        expect(fakeWallpaperService.lastSetBytes, isNull);
      });

      test('should fallback to URL when carousel bytes are missing', () async {
        // Arrange: Cache is empty (image never displayed in carousel)
        fakeCropCache.clearAll();
        fakePrefs.put(sp_IncludeLockWallpaper, true);

        // Act
        await useCase(mockImage);

        // Assert: Fell back to URL path
        expect(fakeWallpaperService.lastSetUrl, mockImage.url);
        expect(fakeWallpaperService.lastSetBytes, isNull);
      });
    });
  });
}
