import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import '../../../fakes/fake_image_preloader_service.dart';

class MockFetchDailyImagesUseCase extends Mock implements FetchDailyImagesUseCase {}
class MockApplyWallpaperUseCase extends Mock implements ApplyWallpaperUseCase {}
class MockPreferencesReader extends Mock implements PreferencesReader {}
class ImageItemFake extends Fake implements ImageItem {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(ImageItemFake());
  });

  late MockFetchDailyImagesUseCase mockFetchUseCase;
  late MockApplyWallpaperUseCase mockApplyUseCase;
  late MockPreferencesReader mockPrefs;
  late FakeImagePreloaderService fakePreloader;
  late HomeBloc homeBloc;

  setUp(() {
    mockFetchUseCase = MockFetchDailyImagesUseCase();
    mockApplyUseCase = MockApplyWallpaperUseCase();
    mockPrefs = MockPreferencesReader();
    fakePreloader = FakeImagePreloaderService();

    // Default mock setup for Prefs to avoid null errors on HomeBloc init
    when(() => mockPrefs.getIntWithDefault(sp_LastViewedIndex, 0)).thenAnswer((_) async => 0);
    when(() => mockPrefs.getString(sp_LastSetWallpaperId)).thenAnswer((_) async => null);
    when(() => mockPrefs.getIntWithDefault(sp_LastSetWallpaperTime, 0)).thenAnswer((_) async => 0);
    when(() => mockPrefs.setInt(any(), any())).thenAnswer((_) async => true);
    when(() => mockPrefs.setString(any(), any())).thenAnswer((_) async => true);

    homeBloc = HomeBloc(
      fetchDailyImagesUseCase: mockFetchUseCase,
      applyWallpaperUseCase: mockApplyUseCase,
      preloaderService: fakePreloader,
      prefs: mockPrefs,
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

  final mockImage2 = ImageItem(
    "Source",
    "https://example.com/image2.jpg",
    "Description 2",
    DateTime.now(),
    DateTime.now().add(const Duration(days: 1)),
    "image_ident_2",
    null,
    "Copyright 2",
  );

  group('HomeBloc', () {
    test('initial state is HomeState.initial()', () {
      expect(homeBloc.state, const HomeState.initial());
    });

    blocTest<HomeBloc, HomeState>(
      'recovers applied wallpaper state using imageIdent instead of corrupted sp_LastViewedIndex',
      build: () {
        // Simuler un faux index 0 (corrompu) mais un lastSetId correspondant à l'image à l'index 1
        when(() => mockPrefs.getIntWithDefault(sp_LastViewedIndex, 0)).thenAnswer((_) async => 0);
        when(() => mockPrefs.getString(sp_LastSetWallpaperId)).thenAnswer((_) async => "image_ident_2");
        when(() => mockPrefs.getIntWithDefault(sp_LastSetWallpaperTime, 0))
            .thenAnswer((_) async => DateTime.now().millisecondsSinceEpoch - 10000); // Il y a 10 secondes (< 30s)
        
        when(() => mockFetchUseCase(forceRefresh: false))
            .thenAnswer((_) async => [mockImage, mockImage2]);
        
        return homeBloc;
      },
      act: (bloc) => bloc.add(const HomeEvent.started()),
      expect: () => [
        // L'index doit être 1, et on doit avoir le message de succès !
        HomeState.loaded(list: [mockImage, mockImage2], imageIndex: 1, wallpaperMessage: 'wallpaperSetSuccess'),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'ignores outdated sp_LastSetWallpaperTime (older than 30s)',
      build: () {
        when(() => mockPrefs.getIntWithDefault(sp_LastViewedIndex, 0)).thenAnswer((_) async => 0);
        when(() => mockPrefs.getString(sp_LastSetWallpaperId)).thenAnswer((_) async => "image_ident");
        when(() => mockPrefs.getIntWithDefault(sp_LastSetWallpaperTime, 0))
            .thenAnswer((_) async => DateTime.now().millisecondsSinceEpoch - 40000); // Il y a 40 secondes (> 30s)
        
        when(() => mockFetchUseCase(forceRefresh: false))
            .thenAnswer((_) async => [mockImage]);
        
        return homeBloc;
      },
      act: (bloc) => bloc.add(const HomeEvent.started()),
      expect: () => [
        // Le message doit être null car expiré
        HomeState.loaded(list: [mockImage], imageIndex: 0, wallpaperMessage: null),
      ],
    );

    blocTest<HomeBloc, HomeState>(
      'emits [loaded] when HomeEventStarted is successful',
      build: () {
        when(() => mockFetchUseCase(forceRefresh: false))
            .thenAnswer((_) async => [mockImage]);
        return homeBloc;
      },
      act: (bloc) => bloc.add(const HomeEvent.started()),
      expect: () => [
        HomeState.loaded(list: [mockImage], imageIndex: 0),
      ],
      verify: (_) {
        verify(() => mockFetchUseCase(forceRefresh: false)).called(1);
        expect(fakePreloader.preloadCallCount, 1);
      },
    );

    blocTest<HomeBloc, HomeState>(
      'emits [error] when FetchDailyImagesUseCase fails',
      build: () {
        when(() => mockFetchUseCase(forceRefresh: false))
            .thenThrow(Exception('Fetch error'));
        return homeBloc;
      },
      act: (bloc) => bloc.add(const HomeEvent.started()),
      expect: () => [
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
