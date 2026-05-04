import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/features/history/domain/usecases/fetch_history_usecase.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import '../../../fakes/fake_image_preloader_service.dart';

class MockFetchHistoryUseCase extends Mock implements FetchHistoryUseCase {}
class MockApplyWallpaperUseCase extends Mock implements ApplyWallpaperUseCase {}
class ImageItemFake extends Fake implements ImageItem {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(ImageItemFake());
    registerFallbackValue(DateTime.now());
  });

  late MockFetchHistoryUseCase mockFetchUseCase;
  late MockApplyWallpaperUseCase mockApplyUseCase;
  late FakeImagePreloaderService fakePreloader;
  late HistoryBloc historyBloc;

  setUp(() {
    mockFetchUseCase = MockFetchHistoryUseCase();
    mockApplyUseCase = MockApplyWallpaperUseCase();
    fakePreloader = FakeImagePreloaderService();
    historyBloc = HistoryBloc(
      fetchHistoryUseCase: mockFetchUseCase,
      applyWallpaperUseCase: mockApplyUseCase,
      preloaderService: fakePreloader,
    );
  });

  tearDown(() {
    historyBloc.close();
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

  group('HistoryBloc', () {
    blocTest<HistoryBloc, HistoryState>(
      'emits [loading, loaded] when started successfully',
      build: () {
        when(() => mockFetchUseCase.getAvailableDates())
            .thenAnswer((_) async => [DateTime(2026, 5, 3)]);
        when(() => mockFetchUseCase.getImagesForDate(any()))
            .thenAnswer((_) async => [mockImage]);
        return historyBloc;
      },
      act: (bloc) => bloc.add(const HistoryEvent.started()),
      expect: () => [
        isA<HistoryState>().having((s) => s.maybeMap(loading: (_) => true, orElse: () => false), 'loading', true),
        isA<HistoryState>().having((s) => s.maybeMap(
          loaded: (s) => s.images.length == 1 && s.availableDates.length == 1,
          orElse: () => false,
        ), 'loaded', true),
      ],
    );

    blocTest<HistoryBloc, HistoryState>(
      'emits loaded with new images when date is selected',
      build: () {
        when(() => mockFetchUseCase.getImagesForDate(any()))
            .thenAnswer((_) async => [mockImage]);
        when(() => mockFetchUseCase.getAvailableDates())
            .thenAnswer((_) async => [DateTime(2026, 5, 3)]);
        return historyBloc;
      },
      seed: () => HistoryState.loaded(
        images: [],
        selectedDate: DateTime(2026, 5, 2),
        availableDates: [DateTime(2026, 5, 2)],
      ),
      act: (bloc) => bloc.add(HistoryEvent.dateSelected(DateTime(2026, 5, 3))),
      expect: () => [
        isA<HistoryState>().having((s) => s.maybeMap(loading: (_) => true, orElse: () => false), 'loading', true),
        isA<HistoryState>().having((s) => s.maybeMap(
          loaded: (s) => s.selectedDate.day == 3,
          orElse: () => false,
        ), 'loaded', true),
      ],
    );
  });
}
