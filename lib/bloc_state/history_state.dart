import 'package:dailywallpaper/models/image_item.dart';

class HistoryState {
  final List<ImageItem> images;
  final DateTime selectedDate;
  final List<DateTime> availableDates;
  final bool isLoading;
  final String? error;

  const HistoryState({
    required this.images,
    required this.selectedDate,
    required this.availableDates,
    this.isLoading = false,
    this.error,
  });

  /// Creates an initial state with today's date
  factory HistoryState.initial() {
    final today = DateTime.now();
    return HistoryState(
      images: [],
      selectedDate: DateTime(today.year, today.month, today.day),
      availableDates: [],
      isLoading: false,
    );
  }

  /// Creates a loading state
  HistoryState loading() {
    return copyWith(isLoading: true, clearError: true);
  }

  /// Creates an error state
  HistoryState withError(String errorMessage) {
    return copyWith(isLoading: false, error: errorMessage);
  }

  /// Creates a success state with images
  HistoryState withImages(List<ImageItem> newImages) {
    return copyWith(
      images: newImages,
      isLoading: false,
      clearError: true,
    );
  }

  /// Creates a copy of this state with updated values
  HistoryState copyWith({
    List<ImageItem>? images,
    DateTime? selectedDate,
    List<DateTime>? availableDates,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return HistoryState(
      images: images ?? this.images,
      selectedDate: selectedDate ?? this.selectedDate,
      availableDates: availableDates ?? this.availableDates,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! HistoryState) return false;

    return _listEquals(images, other.images) &&
        selectedDate == other.selectedDate &&
        _listEquals(availableDates, other.availableDates) &&
        isLoading == other.isLoading &&
        error == other.error;
  }

  @override
  int get hashCode {
    return Object.hash(
      _listHashCode(images),
      selectedDate,
      _listHashCode(availableDates),
      isLoading,
      error,
    );
  }

  @override
  String toString() {
    return 'HistoryState('
        'images: ${images.length} items, '
        'selectedDate: $selectedDate, '
        'availableDates: ${availableDates.length} dates, '
        'isLoading: $isLoading, '
        'error: $error'
        ')';
  }

  /// Helper method to compare lists for equality
  bool _listEquals<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  /// Helper method to generate hash code for lists
  int _listHashCode<T>(List<T> list) {
    int hash = 0;
    for (final item in list) {
      hash = hash ^ item.hashCode;
    }
    return hash;
  }
}
