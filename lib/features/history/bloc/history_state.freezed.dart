// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'history_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HistoryState {
  DateTime get selectedDate;
  List<DateTime> get availableDates;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HistoryStateCopyWith<HistoryState> get copyWith =>
      _$HistoryStateCopyWithImpl<HistoryState>(
          this as HistoryState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HistoryState &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            const DeepCollectionEquality()
                .equals(other.availableDates, availableDates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, selectedDate,
      const DeepCollectionEquality().hash(availableDates));

  @override
  String toString() {
    return 'HistoryState(selectedDate: $selectedDate, availableDates: $availableDates)';
  }
}

/// @nodoc
abstract mixin class $HistoryStateCopyWith<$Res> {
  factory $HistoryStateCopyWith(
          HistoryState value, $Res Function(HistoryState) _then) =
      _$HistoryStateCopyWithImpl;
  @useResult
  $Res call({DateTime selectedDate, List<DateTime> availableDates});
}

/// @nodoc
class _$HistoryStateCopyWithImpl<$Res> implements $HistoryStateCopyWith<$Res> {
  _$HistoryStateCopyWithImpl(this._self, this._then);

  final HistoryState _self;
  final $Res Function(HistoryState) _then;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedDate = null,
    Object? availableDates = null,
  }) {
    return _then(_self.copyWith(
      selectedDate: null == selectedDate
          ? _self.selectedDate
          : selectedDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      availableDates: null == availableDates
          ? _self.availableDates
          : availableDates // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
    ));
  }
}

/// Adds pattern-matching-related methods to [HistoryState].
extension HistoryStatePatterns on HistoryState {
  /// A variant of `map` that fallback to returning `orElse`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeMap<TResult extends Object?>({
    TResult Function(_Initial value)? initial,
    TResult Function(_Loading value)? loading,
    TResult Function(_Loaded value)? loaded,
    TResult Function(_Error value)? error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial(_that);
      case _Loading() when loading != null:
        return loading(_that);
      case _Loaded() when loaded != null:
        return loaded(_that);
      case _Error() when error != null:
        return error(_that);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// Callbacks receives the raw object, upcasted.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case final Subclass2 value:
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult map<TResult extends Object?>({
    required TResult Function(_Initial value) initial,
    required TResult Function(_Loading value) loading,
    required TResult Function(_Loaded value) loaded,
    required TResult Function(_Error value) error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial():
        return initial(_that);
      case _Loading():
        return loading(_that);
      case _Loaded():
        return loaded(_that);
      case _Error():
        return error(_that);
    }
  }

  /// A variant of `map` that fallback to returning `null`.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case final Subclass value:
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? mapOrNull<TResult extends Object?>({
    TResult? Function(_Initial value)? initial,
    TResult? Function(_Loading value)? loading,
    TResult? Function(_Loaded value)? loaded,
    TResult? Function(_Error value)? error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial(_that);
      case _Loading() when loading != null:
        return loading(_that);
      case _Loaded() when loaded != null:
        return loaded(_that);
      case _Error() when error != null:
        return error(_that);
      case _:
        return null;
    }
  }

  /// A variant of `when` that fallback to an `orElse` callback.
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return orElse();
  /// }
  /// ```

  @optionalTypeArgs
  TResult maybeWhen<TResult extends Object?>({
    TResult Function(DateTime selectedDate, List<DateTime> availableDates)?
        initial,
    TResult Function(DateTime selectedDate, List<DateTime> availableDates)?
        loading,
    TResult Function(
            List<ImageItem> images,
            DateTime selectedDate,
            List<DateTime> availableDates,
            String? wallpaperMessage,
            bool isSettingWallpaper)?
        loaded,
    TResult Function(String message, DateTime selectedDate,
            List<DateTime> availableDates)?
        error,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial(_that.selectedDate, _that.availableDates);
      case _Loading() when loading != null:
        return loading(_that.selectedDate, _that.availableDates);
      case _Loaded() when loaded != null:
        return loaded(_that.images, _that.selectedDate, _that.availableDates,
            _that.wallpaperMessage, _that.isSettingWallpaper);
      case _Error() when error != null:
        return error(_that.message, _that.selectedDate, _that.availableDates);
      case _:
        return orElse();
    }
  }

  /// A `switch`-like method, using callbacks.
  ///
  /// As opposed to `map`, this offers destructuring.
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case Subclass2(:final field2):
  ///     return ...;
  /// }
  /// ```

  @optionalTypeArgs
  TResult when<TResult extends Object?>({
    required TResult Function(
            DateTime selectedDate, List<DateTime> availableDates)
        initial,
    required TResult Function(
            DateTime selectedDate, List<DateTime> availableDates)
        loading,
    required TResult Function(
            List<ImageItem> images,
            DateTime selectedDate,
            List<DateTime> availableDates,
            String? wallpaperMessage,
            bool isSettingWallpaper)
        loaded,
    required TResult Function(String message, DateTime selectedDate,
            List<DateTime> availableDates)
        error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial():
        return initial(_that.selectedDate, _that.availableDates);
      case _Loading():
        return loading(_that.selectedDate, _that.availableDates);
      case _Loaded():
        return loaded(_that.images, _that.selectedDate, _that.availableDates,
            _that.wallpaperMessage, _that.isSettingWallpaper);
      case _Error():
        return error(_that.message, _that.selectedDate, _that.availableDates);
    }
  }

  /// A variant of `when` that fallback to returning `null`
  ///
  /// It is equivalent to doing:
  /// ```dart
  /// switch (sealedClass) {
  ///   case Subclass(:final field):
  ///     return ...;
  ///   case _:
  ///     return null;
  /// }
  /// ```

  @optionalTypeArgs
  TResult? whenOrNull<TResult extends Object?>({
    TResult? Function(DateTime selectedDate, List<DateTime> availableDates)?
        initial,
    TResult? Function(DateTime selectedDate, List<DateTime> availableDates)?
        loading,
    TResult? Function(
            List<ImageItem> images,
            DateTime selectedDate,
            List<DateTime> availableDates,
            String? wallpaperMessage,
            bool isSettingWallpaper)?
        loaded,
    TResult? Function(String message, DateTime selectedDate,
            List<DateTime> availableDates)?
        error,
  }) {
    final _that = this;
    switch (_that) {
      case _Initial() when initial != null:
        return initial(_that.selectedDate, _that.availableDates);
      case _Loading() when loading != null:
        return loading(_that.selectedDate, _that.availableDates);
      case _Loaded() when loaded != null:
        return loaded(_that.images, _that.selectedDate, _that.availableDates,
            _that.wallpaperMessage, _that.isSettingWallpaper);
      case _Error() when error != null:
        return error(_that.message, _that.selectedDate, _that.availableDates);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _Initial implements HistoryState {
  const _Initial(
      {required this.selectedDate,
      final List<DateTime> availableDates = const []})
      : _availableDates = availableDates;

  @override
  final DateTime selectedDate;
  final List<DateTime> _availableDates;
  @override
  @JsonKey()
  List<DateTime> get availableDates {
    if (_availableDates is EqualUnmodifiableListView) return _availableDates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableDates);
  }

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$InitialCopyWith<_Initial> get copyWith =>
      __$InitialCopyWithImpl<_Initial>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Initial &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            const DeepCollectionEquality()
                .equals(other._availableDates, _availableDates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, selectedDate,
      const DeepCollectionEquality().hash(_availableDates));

  @override
  String toString() {
    return 'HistoryState.initial(selectedDate: $selectedDate, availableDates: $availableDates)';
  }
}

/// @nodoc
abstract mixin class _$InitialCopyWith<$Res>
    implements $HistoryStateCopyWith<$Res> {
  factory _$InitialCopyWith(_Initial value, $Res Function(_Initial) _then) =
      __$InitialCopyWithImpl;
  @override
  @useResult
  $Res call({DateTime selectedDate, List<DateTime> availableDates});
}

/// @nodoc
class __$InitialCopyWithImpl<$Res> implements _$InitialCopyWith<$Res> {
  __$InitialCopyWithImpl(this._self, this._then);

  final _Initial _self;
  final $Res Function(_Initial) _then;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? selectedDate = null,
    Object? availableDates = null,
  }) {
    return _then(_Initial(
      selectedDate: null == selectedDate
          ? _self.selectedDate
          : selectedDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      availableDates: null == availableDates
          ? _self._availableDates
          : availableDates // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
    ));
  }
}

/// @nodoc

class _Loading implements HistoryState {
  const _Loading(
      {required this.selectedDate,
      required final List<DateTime> availableDates})
      : _availableDates = availableDates;

  @override
  final DateTime selectedDate;
  final List<DateTime> _availableDates;
  @override
  List<DateTime> get availableDates {
    if (_availableDates is EqualUnmodifiableListView) return _availableDates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableDates);
  }

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LoadingCopyWith<_Loading> get copyWith =>
      __$LoadingCopyWithImpl<_Loading>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Loading &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            const DeepCollectionEquality()
                .equals(other._availableDates, _availableDates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, selectedDate,
      const DeepCollectionEquality().hash(_availableDates));

  @override
  String toString() {
    return 'HistoryState.loading(selectedDate: $selectedDate, availableDates: $availableDates)';
  }
}

/// @nodoc
abstract mixin class _$LoadingCopyWith<$Res>
    implements $HistoryStateCopyWith<$Res> {
  factory _$LoadingCopyWith(_Loading value, $Res Function(_Loading) _then) =
      __$LoadingCopyWithImpl;
  @override
  @useResult
  $Res call({DateTime selectedDate, List<DateTime> availableDates});
}

/// @nodoc
class __$LoadingCopyWithImpl<$Res> implements _$LoadingCopyWith<$Res> {
  __$LoadingCopyWithImpl(this._self, this._then);

  final _Loading _self;
  final $Res Function(_Loading) _then;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? selectedDate = null,
    Object? availableDates = null,
  }) {
    return _then(_Loading(
      selectedDate: null == selectedDate
          ? _self.selectedDate
          : selectedDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      availableDates: null == availableDates
          ? _self._availableDates
          : availableDates // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
    ));
  }
}

/// @nodoc

class _Loaded implements HistoryState {
  const _Loaded(
      {required final List<ImageItem> images,
      required this.selectedDate,
      required final List<DateTime> availableDates,
      this.wallpaperMessage,
      this.isSettingWallpaper = false})
      : _images = images,
        _availableDates = availableDates;

  final List<ImageItem> _images;
  List<ImageItem> get images {
    if (_images is EqualUnmodifiableListView) return _images;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_images);
  }

  @override
  final DateTime selectedDate;
  final List<DateTime> _availableDates;
  @override
  List<DateTime> get availableDates {
    if (_availableDates is EqualUnmodifiableListView) return _availableDates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableDates);
  }

  final String? wallpaperMessage;
  @JsonKey()
  final bool isSettingWallpaper;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$LoadedCopyWith<_Loaded> get copyWith =>
      __$LoadedCopyWithImpl<_Loaded>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Loaded &&
            const DeepCollectionEquality().equals(other._images, _images) &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            const DeepCollectionEquality()
                .equals(other._availableDates, _availableDates) &&
            (identical(other.wallpaperMessage, wallpaperMessage) ||
                other.wallpaperMessage == wallpaperMessage) &&
            (identical(other.isSettingWallpaper, isSettingWallpaper) ||
                other.isSettingWallpaper == isSettingWallpaper));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_images),
      selectedDate,
      const DeepCollectionEquality().hash(_availableDates),
      wallpaperMessage,
      isSettingWallpaper);

  @override
  String toString() {
    return 'HistoryState.loaded(images: $images, selectedDate: $selectedDate, availableDates: $availableDates, wallpaperMessage: $wallpaperMessage, isSettingWallpaper: $isSettingWallpaper)';
  }
}

/// @nodoc
abstract mixin class _$LoadedCopyWith<$Res>
    implements $HistoryStateCopyWith<$Res> {
  factory _$LoadedCopyWith(_Loaded value, $Res Function(_Loaded) _then) =
      __$LoadedCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<ImageItem> images,
      DateTime selectedDate,
      List<DateTime> availableDates,
      String? wallpaperMessage,
      bool isSettingWallpaper});
}

/// @nodoc
class __$LoadedCopyWithImpl<$Res> implements _$LoadedCopyWith<$Res> {
  __$LoadedCopyWithImpl(this._self, this._then);

  final _Loaded _self;
  final $Res Function(_Loaded) _then;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? images = null,
    Object? selectedDate = null,
    Object? availableDates = null,
    Object? wallpaperMessage = freezed,
    Object? isSettingWallpaper = null,
  }) {
    return _then(_Loaded(
      images: null == images
          ? _self._images
          : images // ignore: cast_nullable_to_non_nullable
              as List<ImageItem>,
      selectedDate: null == selectedDate
          ? _self.selectedDate
          : selectedDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      availableDates: null == availableDates
          ? _self._availableDates
          : availableDates // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
      wallpaperMessage: freezed == wallpaperMessage
          ? _self.wallpaperMessage
          : wallpaperMessage // ignore: cast_nullable_to_non_nullable
              as String?,
      isSettingWallpaper: null == isSettingWallpaper
          ? _self.isSettingWallpaper
          : isSettingWallpaper // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _Error implements HistoryState {
  const _Error(
      {required this.message,
      required this.selectedDate,
      required final List<DateTime> availableDates})
      : _availableDates = availableDates;

  final String message;
  @override
  final DateTime selectedDate;
  final List<DateTime> _availableDates;
  @override
  List<DateTime> get availableDates {
    if (_availableDates is EqualUnmodifiableListView) return _availableDates;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_availableDates);
  }

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$ErrorCopyWith<_Error> get copyWith =>
      __$ErrorCopyWithImpl<_Error>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _Error &&
            (identical(other.message, message) || other.message == message) &&
            (identical(other.selectedDate, selectedDate) ||
                other.selectedDate == selectedDate) &&
            const DeepCollectionEquality()
                .equals(other._availableDates, _availableDates));
  }

  @override
  int get hashCode => Object.hash(runtimeType, message, selectedDate,
      const DeepCollectionEquality().hash(_availableDates));

  @override
  String toString() {
    return 'HistoryState.error(message: $message, selectedDate: $selectedDate, availableDates: $availableDates)';
  }
}

/// @nodoc
abstract mixin class _$ErrorCopyWith<$Res>
    implements $HistoryStateCopyWith<$Res> {
  factory _$ErrorCopyWith(_Error value, $Res Function(_Error) _then) =
      __$ErrorCopyWithImpl;
  @override
  @useResult
  $Res call(
      {String message, DateTime selectedDate, List<DateTime> availableDates});
}

/// @nodoc
class __$ErrorCopyWithImpl<$Res> implements _$ErrorCopyWith<$Res> {
  __$ErrorCopyWithImpl(this._self, this._then);

  final _Error _self;
  final $Res Function(_Error) _then;

  /// Create a copy of HistoryState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? message = null,
    Object? selectedDate = null,
    Object? availableDates = null,
  }) {
    return _then(_Error(
      message: null == message
          ? _self.message
          : message // ignore: cast_nullable_to_non_nullable
              as String,
      selectedDate: null == selectedDate
          ? _self.selectedDate
          : selectedDate // ignore: cast_nullable_to_non_nullable
              as DateTime,
      availableDates: null == availableDates
          ? _self._availableDates
          : availableDates // ignore: cast_nullable_to_non_nullable
              as List<DateTime>,
    ));
  }
}

// dart format on
