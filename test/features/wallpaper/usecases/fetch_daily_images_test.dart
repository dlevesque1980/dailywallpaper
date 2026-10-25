import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockImageRepository extends Mock implements ImageRepository {}

void main() {
  late MockImageRepository repository;
  late FetchDailyImagesUseCase useCase;

  final images = [
    ImageItem(
      id: 'daily',
      date: DateTime(2026, 10, 25),
      source: 'external-service',
      imageUrl: 'https://res.cloudinary.com/example/daily.avif',
      createdAt: DateTime.utc(2026, 10, 25),
    ),
  ];

  setUp(() {
    repository = MockImageRepository();
    useCase = FetchDailyImagesUseCase(imageRepository: repository);
  });

  test('returns the latest wallpapers from the repository', () async {
    when(() => repository.fetchLatestWallpapers())
        .thenAnswer((_) async => images);

    expect(await useCase(), images);
    verify(() => repository.fetchLatestWallpapers()).called(1);
  });

  test('propagates repository errors', () async {
    when(() => repository.fetchLatestWallpapers())
        .thenAnswer((_) async => throw Exception('Supabase is unavailable'));

    await expectLater(useCase(), throwsException);
  });
}
