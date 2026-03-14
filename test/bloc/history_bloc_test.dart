import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/bloc/history_bloc.dart';
import 'package:dailywallpaper/bloc_state/history_state.dart';
import 'package:dailywallpaper/models/image_item.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    // Initialize the database factory for testing
    databaseFactory = databaseFactoryFfi;
  });

  group('HistoryBloc', () {
    late HistoryBloc historyBloc;

    setUp(() {
      historyBloc = HistoryBloc();
    });

    tearDown(() {
      historyBloc.dispose();
    });

    group('initialization', () {
      test('should create HistoryBloc with empty streams', () {
        expect(historyBloc.results, isA<Stream<HistoryState>>());
        expect(historyBloc.wallpaper, isA<Stream<String>>());
        expect(historyBloc.selectDate, isA<Sink<DateTime>>());
        expect(historyBloc.setWallpaper, isA<Sink<int>>());
      });

      test('should have null current state initially', () {
        expect(historyBloc.currentState, isNull);
      });
    });

    group('getAvailableDates', () {
      test('should return list of available dates from database', () async {
        // Act
        final result = await historyBloc.getAvailableDates();

        // Assert - Should return a list (may be empty if no data in test DB)
        expect(result, isA<List<DateTime>>());
      });
    });

    group('date selection', () {
      test('should emit state when selecting date', () async {
        // Arrange
        final selectedDate = DateTime(2024, 1, 1);

        // Act
        historyBloc.selectDate.add(selectedDate);

        // Assert - Should emit a state with the selected date
        await expectLater(
          historyBloc.results,
          emits(predicate<HistoryState>((state) =>
              state.selectedDate == selectedDate && !state.isLoading)),
        );
      });

      test('should handle multiple date selections correctly', () async {
        // Arrange
        final date1 = DateTime(2024, 1, 1);
        final date2 = DateTime(2024, 1, 2);

        // Act & Assert
        historyBloc.selectDate.add(date1);
        await expectLater(
          historyBloc.results,
          emits(
              predicate<HistoryState>((state) => state.selectedDate == date1)),
        );

        historyBloc.selectDate.add(date2);
        await expectLater(
          historyBloc.results,
          emits(
              predicate<HistoryState>((state) => state.selectedDate == date2)),
        );
      });
    });

    group('wallpaper setting', () {
      test('should return error message when no images available', () async {
        // Act
        historyBloc.setWallpaper.add(0);

        // Assert
        await expectLater(
          historyBloc.wallpaper,
          emits(contains('No images available')),
        );
      });

      test('should return error message when invalid index provided', () async {
        // Arrange - Set up state with one image by selecting a date first
        final selectedDate = DateTime(2024, 1, 1);

        // Load images first (this will likely be empty in test environment)
        historyBloc.selectDate.add(selectedDate);
        await historyBloc.results.first;

        // Act - Try to set wallpaper with invalid index
        historyBloc.setWallpaper.add(5);

        // Assert - Should handle the error gracefully
        await expectLater(
          historyBloc.wallpaper,
          emits(isA<String>()),
        );
      });
    });

    group('stream behavior', () {
      test('should emit distinct date selections only', () async {
        // Arrange
        final selectedDate = DateTime(2024, 1, 1);

        // Act - Add same date multiple times
        historyBloc.selectDate.add(selectedDate);
        historyBloc.selectDate.add(selectedDate);
        historyBloc.selectDate.add(selectedDate);

        // Assert - Should only emit once due to distinct()
        final states = <HistoryState>[];
        final subscription = historyBloc.results.listen(states.add);

        await Future.delayed(Duration(milliseconds: 100));
        subscription.cancel();

        expect(states.length, equals(1));
        expect(states.first.selectedDate, equals(selectedDate));
      });

      test('should be broadcast streams', () {
        expect(historyBloc.results.isBroadcast, isTrue);
        expect(historyBloc.wallpaper.isBroadcast, isTrue);
      });
    });

    group('dispose', () {
      test('should close all streams when disposed', () {
        // Act
        historyBloc.dispose();

        // Assert - Should throw when adding to closed sinks (this is expected behavior)
        expect(
            () => historyBloc.selectDate.add(DateTime.now()), throwsStateError);
        expect(() => historyBloc.setWallpaper.add(0), throwsStateError);
      });
    });

    group('state management', () {
      test('should update current state when processing date selection',
          () async {
        // Arrange
        final selectedDate = DateTime(2024, 1, 1);

        // Act
        historyBloc.selectDate.add(selectedDate);
        await historyBloc.results.first;

        // Assert
        expect(historyBloc.currentState, isNotNull);
        expect(historyBloc.currentState!.selectedDate, equals(selectedDate));
        expect(historyBloc.currentState!.isLoading, isFalse);
      });
    });

    group('ImageItem creation', () {
      test('should create ImageItem with correct constructor', () {
        // Test the ImageItem constructor to ensure our understanding is correct
        final now = DateTime.now();
        final image = ImageItem(
            'test_source',
            'https://example.com/image.jpg',
            'Test description',
            now,
            now.add(Duration(days: 1)),
            'test.image.1',
            'https://example.com/trigger',
            'Test Copyright');

        expect(image.source, equals('test_source'));
        expect(image.url, equals('https://example.com/image.jpg'));
        expect(image.description, equals('Test description'));
        expect(image.startTime, equals(now));
        expect(image.endTime, equals(now.add(Duration(days: 1))));
        expect(image.imageIdent, equals('test.image.1'));
        expect(image.triggerUrl, equals('https://example.com/trigger'));
        expect(image.copyright, equals('Test Copyright'));
      });
    });

    group('error handling', () {
      test('should handle date selection gracefully', () async {
        // Arrange
        final selectedDate = DateTime(2024, 1, 1);

        // Act
        historyBloc.selectDate.add(selectedDate);

        // Assert - Should emit a state without throwing
        await expectLater(
          historyBloc.results,
          emits(predicate<HistoryState>(
              (state) => state.selectedDate == selectedDate)),
        );
      });
    });
  });
}
