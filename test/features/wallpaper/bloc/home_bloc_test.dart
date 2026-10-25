import 'package:bloc_test/bloc_test.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/core/preferences/preferences_reader.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_bloc.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_event.dart';
import 'package:dailywallpaper/features/wallpaper/bloc/home_state.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/fetch_daily_images.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFetchDailyImagesUseCase extends Mock
    implements FetchDailyImagesUseCase {}

class MockApplyWallpaperUseCase extends Mock implements ApplyWallpaperUseCase {}

class MockPreferencesReader extends Mock implements PreferencesReader {}

class FakeImageItem extends Fake implements ImageItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeImageItem());
  });

  late MockFetchDailyImagesUseCase fetchImages;
  late MockApplyWallpaperUseCase applyWallpaper;
  late MockPreferencesReader preferences;
  late HomeBloc bloc;

  final image = ImageItem(
    id: 'one',
    date: DateTime(2026, 10, 25),
    source: 'external-service',
    imageUrl: 'https://res.cloudinary.com/example/one.avif',
    createdAt: DateTime.utc(2026, 10, 25),
  );
  final secondImage = ImageItem(
    id: 'two',
    date: DateTime(2026, 10, 25),
    source: 'external-service',
    imageUrl: 'https://res.cloudinary.com/example/two.avif',
    createdAt: DateTime.utc(2026, 10, 25, 1),
  );

  setUp(() {
    fetchImages = MockFetchDailyImagesUseCase();
    applyWallpaper = MockApplyWallpaperUseCase();
    preferences = MockPreferencesReader();
    when(() => preferences.getString(lastSetWallpaperId))
        .thenAnswer((_) async => null);
    when(() => preferences.getIntWithDefault(lastViewedWallpaperIndex, 0))
        .thenAnswer((_) async => 0);
    when(() => preferences.getIntWithDefault(lastSetWallpaperTime, 0))
        .thenAnswer((_) async => 0);
    when(() => preferences.setInt(any(), any())).thenAnswer((_) async => true);
    when(() => preferences.setString(any(), any()))
        .thenAnswer((_) async => true);
    bloc = HomeBloc(
      fetchDailyImagesUseCase: fetchImages,
      applyWallpaperUseCase: applyWallpaper,
      prefs: preferences,
    );
  });

  tearDown(() => bloc.close());

  blocTest<HomeBloc, HomeState>(
    'loads latest wallpapers from the repository',
    build: () {
      when(() => fetchImages()).thenAnswer((_) async => [image]);
      return bloc;
    },
    act: (bloc) => bloc.add(const HomeEvent.started()),
    expect: () => [
      const HomeState.loading(),
      HomeState.loaded(list: [image]),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'restores the recently applied wallpaper by its Supabase id',
    build: () {
      when(() => fetchImages()).thenAnswer((_) async => [image, secondImage]);
      when(() => preferences.getString(lastSetWallpaperId))
          .thenAnswer((_) async => 'two');
      when(() => preferences.getIntWithDefault(lastSetWallpaperTime, 0))
          .thenAnswer(
        (_) async => DateTime.now().millisecondsSinceEpoch - 10000,
      );
      return bloc;
    },
    act: (bloc) => bloc.add(const HomeEvent.started()),
    expect: () => [
      const HomeState.loading(),
      HomeState.loaded(
        list: [image, secondImage],
        imageIndex: 1,
        wallpaperMessage: 'wallpaperSetSuccess',
      ),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'reports an empty Supabase response',
    build: () {
      when(() => fetchImages()).thenAnswer((_) async => []);
      return bloc;
    },
    act: (bloc) => bloc.add(const HomeEvent.started()),
    expect: () => [
      const HomeState.loading(),
      const HomeState.error(
        'failedToFetchWallpapers: Supabase returned no wallpapers.',
      ),
    ],
  );

  blocTest<HomeBloc, HomeState>(
    'persists the carousel index',
    build: () => bloc,
    seed: () => HomeState.loaded(list: [image, secondImage]),
    act: (bloc) => bloc.add(const HomeEvent.indexChanged(1)),
    expect: () => [
      HomeState.loaded(list: [image, secondImage], imageIndex: 1),
    ],
    verify: (_) {
      verify(() => preferences.setInt(lastViewedWallpaperIndex, 1)).called(1);
    },
  );

  blocTest<HomeBloc, HomeState>(
    'applies the selected URL without image processing',
    build: () {
      when(() => applyWallpaper(image))
          .thenAnswer((_) async => 'wallpaperSetSuccess');
      return bloc;
    },
    seed: () => HomeState.loaded(list: [image]),
    act: (bloc) => bloc.add(const HomeEvent.wallpaperUpdateRequested()),
    expect: () => [
      HomeState.loaded(list: [image], isSettingWallpaper: true),
      HomeState.loaded(
        list: [image],
        wallpaperMessage: 'wallpaperSetSuccess',
      ),
    ],
    verify: (_) {
      verify(() => preferences.setString(lastSetWallpaperId, 'one')).called(1);
      verify(() => applyWallpaper(image)).called(1);
    },
  );
}
