import 'package:flutter_test/flutter_test.dart';
import 'package:dailywallpaper/bloc_state/history_state.dart';
import 'package:dailywallpaper/models/image_item.dart';

void main() {
  group('HistoryState', () {
    late DateTime testDate;
    late List<ImageItem> testImages;
    late List<DateTime> testAvailableDates;

    setUp(() {
      testDate = DateTime(2024, 1, 15);
      testImages = [
        ImageItem(
          'test_source',
          'https://example.com/image1.jpg',
          'Test image 1',
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 16),
          'test_id_1',
          'https://example.com/trigger1',
          'Test copyright 1',
        ),
        ImageItem(
          'test_source',
          'https://example.com/image2.jpg',
          'Test image 2',
          DateTime(2024, 1, 15),
          DateTime(2024, 1, 16),
          'test_id_2',
          'https://example.com/trigger2',
          'Test copyright 2',
        ),
      ];
      testAvailableDates = [
        DateTime(2024, 1, 13),
        DateTime(2024, 1, 14),
        DateTime(2024, 1, 15),
      ];
    });

    group('Constructor', () {
      test('should create HistoryState with required parameters', () {
        final state = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );

        expect(state.images, equals(testImages));
        expect(state.selectedDate, equals(testDate));
        expect(state.availableDates, equals(testAvailableDates));
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
      });

      test('should create HistoryState with optional parameters', () {
        final state = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          isLoading: true,
          error: 'Test error',
        );

        expect(state.isLoading, isTrue);
        expect(state.error, equals('Test error'));
      });
    });

    group('Factory constructors', () {
      test('initial() should create state with today\'s date and empty lists',
          () {
        final state = HistoryState.initial();
        final today = DateTime.now();
        final expectedDate = DateTime(today.year, today.month, today.day);

        expect(state.images, isEmpty);
        expect(state.selectedDate, equals(expectedDate));
        expect(state.availableDates, isEmpty);
        expect(state.isLoading, isFalse);
        expect(state.error, isNull);
      });
    });

    group('State transformation methods', () {
      late HistoryState baseState;

      setUp(() {
        baseState = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );
      });

      test('loading() should return state with isLoading true and no error',
          () {
        final loadingState = baseState.loading();

        expect(loadingState.isLoading, isTrue);
        expect(loadingState.error, isNull);
        expect(loadingState.images, equals(baseState.images));
        expect(loadingState.selectedDate, equals(baseState.selectedDate));
        expect(loadingState.availableDates, equals(baseState.availableDates));
      });

      test('withError() should return state with error and isLoading false',
          () {
        const errorMessage = 'Test error message';
        final errorState = baseState.withError(errorMessage);

        expect(errorState.error, equals(errorMessage));
        expect(errorState.isLoading, isFalse);
        expect(errorState.images, equals(baseState.images));
        expect(errorState.selectedDate, equals(baseState.selectedDate));
        expect(errorState.availableDates, equals(baseState.availableDates));
      });

      test(
          'withImages() should return state with new images and no error/loading',
          () {
        final newImages = [testImages.first];
        final successState = baseState.withImages(newImages);

        expect(successState.images, equals(newImages));
        expect(successState.isLoading, isFalse);
        expect(successState.error, isNull);
        expect(successState.selectedDate, equals(baseState.selectedDate));
        expect(successState.availableDates, equals(baseState.availableDates));
      });
    });

    group('copyWith', () {
      late HistoryState baseState;

      setUp(() {
        baseState = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          isLoading: false,
          error: null,
        );
      });

      test('should return identical state when no parameters provided', () {
        final copiedState = baseState.copyWith();

        expect(copiedState.images, equals(baseState.images));
        expect(copiedState.selectedDate, equals(baseState.selectedDate));
        expect(copiedState.availableDates, equals(baseState.availableDates));
        expect(copiedState.isLoading, equals(baseState.isLoading));
        expect(copiedState.error, equals(baseState.error));
      });

      test('should update only provided parameters', () {
        final newDate = DateTime(2024, 1, 20);
        final newImages = [testImages.first];

        final copiedState = baseState.copyWith(
          selectedDate: newDate,
          images: newImages,
          isLoading: true,
        );

        expect(copiedState.selectedDate, equals(newDate));
        expect(copiedState.images, equals(newImages));
        expect(copiedState.isLoading, isTrue);
        expect(copiedState.availableDates, equals(baseState.availableDates));
        expect(copiedState.error, equals(baseState.error));
      });

      test('should handle null error parameter correctly', () {
        final stateWithError = baseState.copyWith(error: 'Some error');
        final stateWithoutError = stateWithError.copyWith(clearError: true);

        expect(stateWithError.error, equals('Some error'));
        expect(stateWithoutError.error, isNull);
      });

      test('should clear error when clearError is true', () {
        final stateWithError = baseState.copyWith(error: 'Test error');
        final clearedState = stateWithError.copyWith(clearError: true);

        expect(stateWithError.error, equals('Test error'));
        expect(clearedState.error, isNull);
        expect(clearedState.images, equals(stateWithError.images));
        expect(clearedState.selectedDate, equals(stateWithError.selectedDate));
      });

      test('should not clear error when clearError is false', () {
        final stateWithError = baseState.copyWith(error: 'Test error');
        final notClearedState = stateWithError.copyWith(
          isLoading: true,
          clearError: false,
        );

        expect(notClearedState.error, equals('Test error'));
        expect(notClearedState.isLoading, isTrue);
      });
    });

    group('Equality', () {
      test('should be equal when all properties are the same', () {
        final state1 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          isLoading: false,
          error: null,
        );

        final state2 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          isLoading: false,
          error: null,
        );

        expect(state1, equals(state2));
        expect(state1.hashCode, equals(state2.hashCode));
      });

      test('should not be equal when images differ', () {
        final state1 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );

        final state2 = HistoryState(
          images: [testImages.first],
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal when selectedDate differs', () {
        final state1 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );

        final state2 = HistoryState(
          images: testImages,
          selectedDate: DateTime(2024, 1, 16),
          availableDates: testAvailableDates,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal when availableDates differ', () {
        final state1 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );

        final state2 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: [DateTime(2024, 1, 15)],
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal when isLoading differs', () {
        final state1 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          isLoading: false,
        );

        final state2 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          isLoading: true,
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should not be equal when error differs', () {
        final state1 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          error: null,
        );

        final state2 = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          error: 'Some error',
        );

        expect(state1, isNot(equals(state2)));
      });

      test('should handle identical objects', () {
        final state = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );

        expect(state, equals(state));
      });

      test('should not be equal to different type', () {
        final state = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
        );

        expect(state, isNot(equals('not a HistoryState')));
      });
    });

    group('toString', () {
      test('should provide meaningful string representation', () {
        final state = HistoryState(
          images: testImages,
          selectedDate: testDate,
          availableDates: testAvailableDates,
          isLoading: true,
          error: 'Test error',
        );

        final stringRepresentation = state.toString();

        expect(stringRepresentation, contains('HistoryState'));
        expect(stringRepresentation, contains('images: 2 items'));
        expect(stringRepresentation, contains('selectedDate: $testDate'));
        expect(stringRepresentation, contains('availableDates: 3 dates'));
        expect(stringRepresentation, contains('isLoading: true'));
        expect(stringRepresentation, contains('error: Test error'));
      });

      test('should handle null error in string representation', () {
        final state = HistoryState(
          images: [],
          selectedDate: testDate,
          availableDates: [],
        );

        final stringRepresentation = state.toString();

        expect(stringRepresentation, contains('error: null'));
      });
    });

    group('Edge cases', () {
      test('should handle empty lists correctly', () {
        final state = HistoryState(
          images: [],
          selectedDate: testDate,
          availableDates: [],
        );

        expect(state.images, isEmpty);
        expect(state.availableDates, isEmpty);

        final copiedState = state.copyWith(images: []);
        expect(state, equals(copiedState));
      });

      test('should handle date normalization correctly', () {
        final dateWithTime = DateTime(2024, 1, 15, 14, 30, 45);
        final dateWithoutTime = DateTime(2024, 1, 15);

        final state1 = HistoryState(
          images: [],
          selectedDate: dateWithTime,
          availableDates: [],
        );

        final state2 = HistoryState(
          images: [],
          selectedDate: dateWithoutTime,
          availableDates: [],
        );

        // These should not be equal since we're not normalizing dates
        expect(state1, isNot(equals(state2)));
      });
    });
  });
}
