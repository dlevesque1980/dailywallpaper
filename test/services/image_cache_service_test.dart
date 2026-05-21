import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/services/image_cache_service.dart';
import 'package:dailywallpaper/features/smart_crop/models/crop_result.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:mocktail/mocktail.dart';
import 'package:http/http.dart' as http;

class MockPathProviderPlatform extends Mock
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {}

class MockClient extends Mock implements http.Client {}

class MockCropResult extends Mock implements CropResult {}

void main() {
  late MockPathProviderPlatform mockPathProvider;
  late Directory tempDir;
  late ImageCacheService imageCache;

  setUpAll(() {
    tempDir = Directory.systemTemp.createTempSync('image_cache_test');
  });

  tearDownAll(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  setUp(() {
    mockPathProvider = MockPathProviderPlatform();
    PathProviderPlatform.instance = mockPathProvider;
    imageCache = ImageCacheServiceImpl();

    when(() => mockPathProvider.getApplicationDocumentsPath())
        .thenAnswer((_) async => tempDir.path);
    when(() => mockPathProvider.getTemporaryPath())
        .thenAnswer((_) async => tempDir.path);
  });

  group('ImageCacheService Tests', () {
    const testIdent = 'test_image_123';
    const testUrl = 'https://example.com/image.jpg';

    test('downloadAndSaveSourceImage should save bytes to disk', () async {
      final client = MockClient();
      final bytes = Uint8List.fromList([1, 2, 3, 4]);

      when(() => client.get(Uri.parse(testUrl)))
          .thenAnswer((_) async => http.Response.bytes(bytes, 200));

      final path = await imageCache
          .downloadAndSaveSourceImage(testUrl, testIdent, client: client);

      expect(path, contains(testIdent));
      final file = File(path!);
      expect(await file.exists(), isTrue);
      expect(await file.readAsBytes(), bytes);
    });

    test('saveCropResult and loadCropResultJson should work together',
        () async {
      final mockResult = MockCropResult();
      when(() => mockResult.serialize()).thenReturn('{"bestCrop": {"x": 0.5}}');

      await imageCache.saveCropResult(mockResult, testIdent);

      final loadedJson = await imageCache.loadCropResultJson(testIdent);
      expect(loadedJson, contains('"bestCrop"'));
      expect(loadedJson, contains('0.5'));
    });

    test('cleanupOldWallpapers should only delete old files', () async {
      final wallpaperDir = Directory('${tempDir.path}/wallpapers');
      if (!wallpaperDir.existsSync()) wallpaperDir.createSync(recursive: true);

      // Clear dir first
      for (final f in wallpaperDir.listSync()) {
        f.deleteSync();
      }

      // Create a fresh file
      final freshFile = File('${wallpaperDir.path}/fresh.jpg');
      freshFile.writeAsBytesSync([0]);

      // Create an old file
      final oldFile = File('${wallpaperDir.path}/old.jpg');
      oldFile.writeAsBytesSync([0]);
      // Set modification time to 3 days ago
      final oldDate = DateTime.now().subtract(const Duration(days: 3));
      await oldFile.setLastModified(oldDate);

      final deletedCount = await imageCache.cleanupOldWallpapers(
        maxAge: const Duration(days: 2),
      );

      expect(deletedCount, 1);
      expect(freshFile.existsSync(), isTrue);
      expect(oldFile.existsSync(), isFalse);
    });
  });
}
