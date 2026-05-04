import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import '../../../fakes/fake_image_storage.dart';
import '../../../fakes/fake_image_data_source.dart';
import '../../../fakes/fake_preferences_reader.dart';

void main() {
  late FakeImageStorage fakeStorage;
  late FakeImageDataSource fakeDataSource;
  late FakePreferencesReader fakePrefs;
  late ImageRepository imageRepository;
  late FetchDailyImagesUseCase useCase;

  setUp(() {
    fakeStorage = FakeImageStorage();
    fakeDataSource = FakeImageDataSource();
    fakePrefs = FakePreferencesReader();
    imageRepository = ImageRepository(
      bingDataSource: fakeDataSource,
      pexelsDataSource: fakeDataSource,
      nasaDataSource: fakeDataSource,
    );
    useCase = FetchDailyImagesUseCase(
      dbHelper: fakeStorage,
      imageRepository: imageRepository,
      prefHelper: fakePrefs,
    );
  });

  final mockImage = ImageItem(
    "Source",
    "https://example.com/image.jpg",
    "Description",
    DateTime.now(),
    DateTime.now().add(const Duration(days: 1)),
    "bing.en-US",
    null,
    "Copyright",
  );

  group('FetchDailyImagesUseCase', () {
    test('should return images from repository when cache is empty', () async {
      // Arrange
      fakePrefs.put(sp_BingRegion, 'en-US');
      fakePrefs.put(sp_PexelsCategories, ['nature']);
      fakeDataSource.bingResult = mockImage.copyWith(imageIdent: 'bing.en-US');
      fakeDataSource.pexelsResult = mockImage.copyWith(imageIdent: 'pexels.nature');
      fakeDataSource.nasaResult = mockImage.copyWith(imageIdent: 'nasa.apod');

      // Act
      final result = await useCase(forceRefresh: false);

      // Assert
      expect(result.length, 3);
      expect(fakeStorage.insertCallCount, 3);
      expect(result.any((img) => img.imageIdent.contains('bing')), true);
      expect(result.any((img) => img.imageIdent.contains('pexels')), true);
      expect(result.any((img) => img.imageIdent.contains('nasa')), true);
    });

    test('should return images from storage when they exist and not force refresh', () async {
      // Arrange
      fakePrefs.put(sp_BingRegion, 'en-US');
      fakePrefs.put(sp_PexelsCategories, []); // No pexels for simplicity
      final storedImage = mockImage.copyWith(imageIdent: 'bing.en-US');
      fakeStorage.seed(storedImage);

      // Act
      final result = await useCase(forceRefresh: false);

      // Assert
      expect(result.length, 2); // Bing from storage + NASA from source (since NASA wasn't in storage)
      expect(fakeStorage.insertCallCount, 1); // Only NASA was inserted
      expect(result.any((img) => img.imageIdent == 'bing.en-US'), true);
    });

    test('should force refresh from repository even if images exist in storage', () async {
      // Arrange
      fakePrefs.put(sp_BingRegion, 'en-US');
      fakePrefs.put(sp_PexelsCategories, []);
      final storedImage = mockImage.copyWith(imageIdent: 'bing.en-US', description: 'Old');
      fakeStorage.seed(storedImage);
      fakeDataSource.bingResult = mockImage.copyWith(imageIdent: 'bing.en-US', description: 'New');

      // Act
      final result = await useCase(forceRefresh: true);

      // Assert
      expect(fakeStorage.deleteCallCount, 2); // Bing + NASA deleted before fetch
      expect(result.any((img) => img.description == 'New'), true);
    });

    test('should return partial list if one provider fails', () async {
      // Arrange
      fakePrefs.put(sp_BingRegion, 'en-US');
      fakePrefs.put(sp_PexelsCategories, []);
      fakeDataSource.nasaShouldThrow = true;
      fakeDataSource.throwMessage = 'NASA Error';
      
      // Act
      final result = await useCase(forceRefresh: false);

      // Assert
      // Bing succeeds, NASA fails (has try-catch)
      expect(result.length, 1);
      expect(result.first.imageIdent.contains('bing'), true);
    });
  });
}
