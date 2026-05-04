import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_bloc.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_event.dart';
import 'package:dailywallpaper/features/settings/bloc/settings_state.dart';
import 'package:dailywallpaper/core/preferences/pref_consts.dart';
import 'package:dailywallpaper/data/models/bing/bing_region_enum.dart';
import 'package:dailywallpaper/data/repositories/image_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../fakes/fake_preferences_reader.dart';
import '../../../fakes/fake_image_data_source.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late FakePreferencesReader fakePrefs;
  late FakeImageDataSource fakeDataSource;
  late ImageRepository imageRepository;
  late SettingsBloc settingsBloc;

  setUp(() {
    fakePrefs = FakePreferencesReader();
    fakeDataSource = FakeImageDataSource();
    imageRepository = ImageRepository(
      bingDataSource: fakeDataSource,
      pexelsDataSource: fakeDataSource,
      nasaDataSource: fakeDataSource,
    );
    settingsBloc = SettingsBloc(
      prefHelper: fakePrefs,
      imageRepository: imageRepository,
    );
  });

  tearDown(() {
    settingsBloc.close();
  });

  group('SettingsBloc', () {
    test('initial state has loading=true', () {
      expect(settingsBloc.state.isLoading, true);
    });

    blocTest<SettingsBloc, SettingsState>(
      'emits loaded state with preferences when started',
      build: () {
        fakePrefs.put(sp_BingRegion, 'US');
        fakePrefs.put(sp_IncludeLockWallpaper, true);
        return settingsBloc;
      },
      act: (bloc) => bloc.add(const SettingsEvent.started()),
      expect: () => [
        isA<SettingsState>().having((s) => s.isLoading, 'loading', true),
        isA<SettingsState>().having((s) => s.selectedRegion, 'region', BingRegionEnum.US)
                           .having((s) => s.includeLockWallpaper, 'lock', true)
                           .having((s) => s.isLoading, 'loading', false),
      ],
    );

    blocTest<SettingsBloc, SettingsState>(
      'updates region when SettingsEventRegionChanged is called',
      build: () => settingsBloc,
      act: (bloc) => bloc.add(const SettingsEvent.regionChanged(BingRegionEnum.France)),
      expect: () => [
        isA<SettingsState>().having((s) => s.selectedRegion, 'region', BingRegionEnum.France),
      ],
      verify: (_) async {
        expect(await fakePrefs.getString(sp_BingRegion), 'fr-FR');
      },
    );
  });
}
