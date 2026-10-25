import 'package:bloc_test/bloc_test.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/data/datasources/supabase_downloader_settings_data_source.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_event.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_state.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../fakes/fake_preferences_reader.dart';

class MockDownloaderSettingsDataSource extends Mock
    implements DownloaderSettingsDataSource {}

void main() {
  late FakePreferencesReader preferences;
  late MockDownloaderSettingsDataSource downloaderSettings;
  late SettingsBloc bloc;

  setUp(() {
    preferences = FakePreferencesReader();
    downloaderSettings = MockDownloaderSettingsDataSource();
    when(() => downloaderSettings.fetchSettings()).thenAnswer(
      (_) async => const DownloaderSettings(
        includeNasa: true,
        pexelsCategories: ['portrait', 'people', 'animals'],
      ),
    );
    when(() => downloaderSettings.updateSettings(
          includeNasa: any(named: 'includeNasa'),
          pexelsCategories: any(named: 'pexelsCategories'),
        )).thenAnswer((_) async {});
    bloc = SettingsBloc(
      prefHelper: preferences,
      downloaderSettings: downloaderSettings,
    );
  });

  tearDown(() => bloc.close());

  test('starts in a loading state', () {
    expect(bloc.state.isLoading, isTrue);
  });

  blocTest<SettingsBloc, SettingsState>(
    'loads local and Supabase settings',
    build: () {
      preferences.put(includeLockWallpaperPreference, false);
      return bloc;
    },
    act: (bloc) => bloc.add(const SettingsEvent.started()),
    expect: () => [
      isA<SettingsState>().having((state) => state.isLoading, 'loading', true),
      isA<SettingsState>()
          .having(
            (state) => state.includeLockWallpaper,
            'lock wallpaper',
            false,
          )
          .having((state) => state.includeNasa, 'include NASA', true)
          .having(
        (state) => state.selectedCategories,
        'Pexels categories',
        ['portrait', 'people', 'animals'],
      ).having((state) => state.isLoading, 'loading', false),
    ],
  );

  blocTest<SettingsBloc, SettingsState>(
    'updates the shared NASA setting through Supabase',
    build: () => bloc,
    seed: () => const SettingsState(
      includeLockWallpaper: true,
      includeNasa: true,
    ),
    act: (bloc) => bloc.add(const SettingsEvent.nasaToggled(false)),
    expect: () => [
      isA<SettingsState>().having(
        (state) => state.isSavingNasa,
        'saving',
        true,
      ),
      isA<SettingsState>()
          .having((state) => state.includeNasa, 'include NASA', false)
          .having((state) => state.isSavingNasa, 'saving', false),
    ],
    verify: (_) {
      verify(
        () => downloaderSettings.updateSettings(includeNasa: false),
      ).called(1);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'saves selected Pexels categories to Supabase',
    build: () => bloc,
    act: (bloc) => bloc.add(
      const SettingsEvent.categoriesChanged(['nature', 'architecture']),
    ),
    expect: () => [
      isA<SettingsState>().having(
        (state) => state.isSavingCategories,
        'saving categories',
        true,
      ),
      isA<SettingsState>().having(
        (state) => state.selectedCategories,
        'Pexels categories',
        ['nature', 'architecture'],
      ).having(
        (state) => state.isSavingCategories,
        'saving categories',
        false,
      ),
    ],
    verify: (_) {
      verify(
        () => downloaderSettings.updateSettings(
          pexelsCategories: ['nature', 'architecture'],
        ),
      ).called(1);
    },
  );

  blocTest<SettingsBloc, SettingsState>(
    'persists a lock-screen preference change',
    build: () => bloc,
    act: (bloc) => bloc.add(const SettingsEvent.lockWallpaperToggled(false)),
    expect: () => [
      isA<SettingsState>().having(
        (state) => state.includeLockWallpaper,
        'lock wallpaper',
        false,
      ),
    ],
    verify: (_) async {
      expect(
        await preferences.getBoolWithDefault(
          includeLockWallpaperPreference,
          true,
        ),
        isFalse,
      );
    },
  );
}
