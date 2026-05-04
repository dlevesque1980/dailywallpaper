import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import '../../../fakes/fake_image_preloader_service.dart';

class MockFetchDailyImagesUseCase extends Mock implements FetchDailyImagesUseCase {}
class MockApplyWallpaperUseCase extends Mock implements ApplyWallpaperUseCase {}
class ImageItemFake extends Fake implements ImageItem {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(ImageItemFake());
  });

  late MockFetchDailyImagesUseCase mockFetchUseCase;
  late MockApplyWallpaperUseCase mockApplyUseCase;
  late FakeImagePreloaderService fakePreloader;
  late HomeBloc homeBloc;

  setUp(() {
    mockFetchUseCase = MockFetchDailyImagesUseCase();
    mockApplyUseCase = MockApplyWallpaperUseCase();
    fakePreloader = FakeImagePreloaderService();
    homeBloc = HomeBloc(
      fetchDailyImagesUseCase: mockFetchUseCase,
      applyWallpaperUseCase: mockApplyUseCase,
      preloaderService: fakePreloader,
    );
  });

  tearDown(() {
    homeBloc.close();
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

  group('HomeBloc', () {
    test('initial state is HomeState.initial()', () {
      expect(homeBloc.state, const HomeState.initial());
    });

    blocTest<HomeBloc, HomeState>(
      'emits [loading, loaded] when HomeEventStarted is successful',
      build: () {
        when(() => mockFetchUseCase(forceRefresh: false))
            .thenAnswer((_) async => [mockImage]);
        return homeBloc;
      },
      act: (bloc) => bloc.add(const HomeEvent.started()),
      expect: () => [
        const HomeState.loading(),
        HomeState.loaded(list: [mockImage], imageIndex: 0),
      ],
      verify: (_) {
        verify(() => mockFetchUseCase(forceRefresh: false)).called(1);
        expect(fakePreloader.preloadCallCount, 1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits [loading, error] when FetchDailyImagesUseCase fails',
      build: () {
        when(() => mockFetchUseCase(forceRefresh: false))
            .thenThrow(Exception('Fetch error'));
        return homeBloc;
      },
      act: (bloc) => bloc.add(const HomeEvent.started()),
      expect: () => [
        const HomeState.loading(),
        const HomeState.error('failedToFetchWallpapers: Exception: Fetch error'),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits loaded with new index when HomeEventIndexChanged is called',
      build: () => homeBloc,
      seed: () => HomeState.loaded(list: [mockImage, mockImage], imageIndex: 0),
      act: (bloc) => bloc.add(const HomeEvent.indexChanged(1)),
      expect: () => [
        HomeState.loaded(list: [mockImage, mockImage], imageIndex: 1, wallpaperMessage: null),
      ],
      verify: (_) {
        expect(fakePreloader.preloadCallCount, 1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits loaded with wallpaper message when HomeEventWallpaperUpdateRequested is successful',
      build: () {
        when(() => mockApplyUseCase(any()))
            .thenAnswer((_) async => 'Success');
        return homeBloc;
      },
      seed: () => HomeState.loaded(list: [mockImage], imageIndex: 0),
      act: (bloc) => bloc.add(const HomeEvent.wallpaperUpdateRequested()),
      expect: () => [
        HomeState.loaded(list: [mockImage], imageIndex: 0, isSettingWallpaper: true),
        HomeState.loaded(list: [mockImage], imageIndex: 0, isSettingWallpaper: false, wallpaperMessage: 'Success'),
      ],
    );
  });
}
