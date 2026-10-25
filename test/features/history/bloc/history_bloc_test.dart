import 'package:bloc_test/bloc_test.dart';
import 'package:dailywallpaper/data/models/image_item.dart';
import 'package:dailywallpaper/features/history/bloc/history_bloc.dart';
import 'package:dailywallpaper/features/history/bloc/history_event.dart';
import 'package:dailywallpaper/features/history/bloc/history_state.dart';
import 'package:dailywallpaper/features/history/domain/usecases/fetch_history_usecase.dart';
import 'package:dailywallpaper/features/wallpaper/domain/usecases/apply_wallpaper.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFetchHistoryUseCase extends Mock implements FetchHistoryUseCase {}

class MockApplyWallpaperUseCase extends Mock implements ApplyWallpaperUseCase {}

class FakeImageItem extends Fake implements ImageItem {}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeImageItem());
  });

  late MockFetchHistoryUseCase fetchHistory;
  late MockApplyWallpaperUseCase applyWallpaper;
  late HistoryBloc bloc;

  final image = ImageItem(
    id: 'wallpaper-1',
    date: DateTime(2026, 10, 25),
    source: 'external-service',
    imageUrl: 'https://res.cloudinary.com/example/wallpaper.avif',
    createdAt: DateTime.utc(2026, 10, 25),
  );

  setUp(() {
    fetchHistory = MockFetchHistoryUseCase();
    applyWallpaper = MockApplyWallpaperUseCase();
    bloc = HistoryBloc(
      fetchHistoryUseCase: fetchHistory,
      applyWallpaperUseCase: applyWallpaper,
    );
  });

  tearDown(() => bloc.close());

  blocTest<HistoryBloc, HistoryState>(
    'loads available Supabase dates and today records',
    build: () {
      when(() => fetchHistory.getAvailableDates())
          .thenAnswer((_) async => [DateTime(2026, 10, 25)]);
      when(() => fetchHistory.getImagesForDate(any()))
          .thenAnswer((_) async => [image]);
      return bloc;
    },
    act: (bloc) => bloc.add(const HistoryEvent.started()),
    expect: () => [
      isA<HistoryState>().having(
        (state) => state.maybeMap(loading: (_) => true, orElse: () => false),
        'loading state',
        true,
      ),
      isA<HistoryState>().having(
        (state) => state.maybeMap(
          loaded: (state) =>
              state.images.single.id == 'wallpaper-1' &&
              state.availableDates.length == 1,
          orElse: () => false,
        ),
        'loaded state',
        true,
      ),
    ],
  );

  blocTest<HistoryBloc, HistoryState>(
    'loads the selected date from Supabase',
    build: () {
      when(() => fetchHistory.getImagesForDate(any()))
          .thenAnswer((_) async => [image]);
      return bloc;
    },
    seed: () => HistoryState.loaded(
      images: const [],
      selectedDate: DateTime(2026, 10, 24),
      availableDates: [DateTime(2026, 10, 24)],
    ),
    act: (bloc) => bloc.add(
      HistoryEvent.dateSelected(DateTime(2026, 10, 25)),
    ),
    expect: () => [
      isA<HistoryState>().having(
        (state) => state.maybeMap(loading: (_) => true, orElse: () => false),
        'loading state',
        true,
      ),
      isA<HistoryState>().having(
        (state) => state.maybeMap(
          loaded: (state) =>
              state.images.single.id == 'wallpaper-1' &&
              state.availableDates.single == DateTime(2026, 10, 24),
          orElse: () => false,
        ),
        'loaded state retains available dates',
        true,
      ),
    ],
    verify: (_) {
      verifyNever(() => fetchHistory.getAvailableDates());
    },
  );

  blocTest<HistoryBloc, HistoryState>(
    'reports history service errors',
    build: () {
      when(() => fetchHistory.getAvailableDates())
          .thenThrow(Exception('offline'));
      when(() => fetchHistory.getImagesForDate(any()))
          .thenAnswer((_) async => []);
      return bloc;
    },
    act: (bloc) => bloc.add(const HistoryEvent.started()),
    expect: () => [
      isA<HistoryState>().having(
        (state) => state.maybeMap(loading: (_) => true, orElse: () => false),
        'loading state',
        true,
      ),
      isA<HistoryState>().having(
        (state) => state.maybeMap(error: (_) => true, orElse: () => false),
        'error state',
        true,
      ),
    ],
  );
}
