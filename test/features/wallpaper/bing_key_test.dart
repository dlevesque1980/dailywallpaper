import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/data/datasources/bing_service.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/core/utils/datetime_helper.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import '../../fakes/fake_image_storage.dart';
import '../../fakes/fake_image_data_source.dart';
import '../../fakes/fake_preferences_reader.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(Uri());
  });

  group('Bing Date-Based Key Tests', () {
    late MockHttpClient mockClient;
    late BingService bingService;

    setUp(() {
      mockClient = MockHttpClient();
      bingService = BingService(client: mockClient);
    });

    test('BingService._convertBingImageToItem should generate date-specific imageIdent', () async {
      // Mock Bing API response JSON
      final jsonResponse = '''
      {
        "images": [
          {
            "startdate": "20260523",
            "fullstartdate": "202605230400",
            "enddate": "20260524",
            "url": "/th?id=OHR.TestImage_EN-US1234567890_1920x1080.jpg",
            "urlbase": "/th?id=OHR.TestImage_EN-US1234567890",
            "copyright": "Test Copyright Description (Photographer Name)",
            "copyrightlink": "https://example.com",
            "quiz": "quiz",
            "wp": true,
            "hsh": "hash",
            "drk": 1,
            "top": 1,
            "bot": 1
          }
        ]
      }
      ''';

      when(() => mockClient.get(any()))
          .thenAnswer((_) async => http.Response(jsonResponse, 200));

      final imageItem = await bingService.fetchFromBing('en-US');

      // The expected identifier format is bing.$region.$dateStr (bing.en-US.2026-05-23)
      expect(imageItem.imageIdent, 'bing.en-US.2026-05-23');
      expect(imageItem.source, 'Bing image of the day');
      expect(imageItem.copyright, 'Photographer Name');
      expect(imageItem.description, 'Test Copyright Description');
    });

    test('FetchDailyImagesUseCase._bingHandler should generate and enforce the date-specific identifier', () async {
      final fakeStorage = FakeImageStorage();
      final fakeDataSource = FakeImageDataSource();
      final fakePrefs = FakePreferencesReader();
      
      final imageRepository = ImageRepository(
        bingDataSource: fakeDataSource,
        pexelsDataSource: fakeDataSource,
        nasaDataSource: fakeDataSource,
      );

      final useCase = FetchDailyImagesUseCase(
        dbHelper: fakeStorage,
        imageRepository: imageRepository,
        prefHelper: fakePrefs,
      );

      // Seed mock Bing result in data source
      final testImage = ImageItem(
        "Source",
        "https://example.com/image.jpg",
        "Description",
        DateTime.now(),
        DateTime.now().add(const Duration(days: 1)),
        "bing.en-US", // old format returned by repository
        null,
        "Copyright",
      );
      fakeDataSource.bingResult = testImage;

      // Execute use case handler
      final result = await useCase(forceRefresh: false);

      final dateStr = DateTimeHelper.formatDateKey(DateTime.now());
      final expectedIdent = 'bing.en-US.$dateStr';

      // Assert that the returned Bing image has the correct date-based identifier
      final bingImg = result.firstWhere((img) => img.imageIdent.contains('bing'));
      expect(bingImg.imageIdent, expectedIdent);
    });
  });
}
