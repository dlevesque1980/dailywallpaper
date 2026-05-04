// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'history_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HistoryEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is HistoryEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'HistoryEvent()';
  }
}

/// @nodoc
class $HistoryEventCopyWith<$Res> {
  $HistoryEventCopyWith(HistoryEvent _, $Res Function(HistoryEvent) __);
}

/// Adds pattern-matching-related methods to [HistoryEvent].
extension HistoryEventPatterns on HistoryEvent {
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
    TResult Function(HistoryEventStarted value)? started,
    TResult Function(HistoryEventDateSelected value)? dateSelected,
    TResult Function(HistoryEventWallpaperUpdateRequested value)?
        wallpaperUpdateRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case HistoryEventStarted() when started != null:
        return started(_that);
      case HistoryEventDateSelected() when dateSelected != null:
        return dateSelected(_that);
      case HistoryEventWallpaperUpdateRequested()
          when wallpaperUpdateRequested != null:
        return wallpaperUpdateRequested(_that);
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
    required TResult Function(HistoryEventStarted value) started,
    required TResult Function(HistoryEventDateSelected value) dateSelected,
    required TResult Function(HistoryEventWallpaperUpdateRequested value)
        wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HistoryEventStarted():
        return started(_that);
      case HistoryEventDateSelected():
        return dateSelected(_that);
      case HistoryEventWallpaperUpdateRequested():
        return wallpaperUpdateRequested(_that);
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
    TResult? Function(HistoryEventStarted value)? started,
    TResult? Function(HistoryEventDateSelected value)? dateSelected,
    TResult? Function(HistoryEventWallpaperUpdateRequested value)?
        wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HistoryEventStarted() when started != null:
        return started(_that);
      case HistoryEventDateSelected() when dateSelected != null:
        return dateSelected(_that);
      case HistoryEventWallpaperUpdateRequested()
          when wallpaperUpdateRequested != null:
        return wallpaperUpdateRequested(_that);
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
    TResult Function()? started,
    TResult Function(DateTime date)? dateSelected,
    TResult Function(int index)? wallpaperUpdateRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case HistoryEventStarted() when started != null:
        return started();
      case HistoryEventDateSelected() when dateSelected != null:
        return dateSelected(_that.date);
      case HistoryEventWallpaperUpdateRequested()
          when wallpaperUpdateRequested != null:
        return wallpaperUpdateRequested(_that.index);
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
    required TResult Function() started,
    required TResult Function(DateTime date) dateSelected,
    required TResult Function(int index) wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HistoryEventStarted():
        return started();
      case HistoryEventDateSelected():
        return dateSelected(_that.date);
      case HistoryEventWallpaperUpdateRequested():
        return wallpaperUpdateRequested(_that.index);
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
    TResult? Function()? started,
    TResult? Function(DateTime date)? dateSelected,
    TResult? Function(int index)? wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HistoryEventStarted() when started != null:
        return started();
      case HistoryEventDateSelected() when dateSelected != null:
        return dateSelected(_that.date);
      case HistoryEventWallpaperUpdateRequested()
          when wallpaperUpdateRequested != null:
        return wallpaperUpdateRequested(_that.index);
      case _:
        return null;
    }
  }
}

/// @nodoc

class HistoryEventStarted implements HistoryEvent {
  const HistoryEventStarted();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is HistoryEventStarted);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'HistoryEvent.started()';
  }
}

/// @nodoc

class HistoryEventDateSelected implements HistoryEvent {
  const HistoryEventDateSelected(this.date);

  final DateTime date;

  /// Create a copy of HistoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HistoryEventDateSelectedCopyWith<HistoryEventDateSelected> get copyWith =>
      _$HistoryEventDateSelectedCopyWithImpl<HistoryEventDateSelected>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HistoryEventDateSelected &&
            (identical(other.date, date) || other.date == date));
  }

  @override
  int get hashCode => Object.hash(runtimeType, date);

  @override
  String toString() {
    return 'HistoryEvent.dateSelected(date: $date)';
  }
}

/// @nodoc
abstract mixin class $HistoryEventDateSelectedCopyWith<$Res>
    implements $HistoryEventCopyWith<$Res> {
  factory $HistoryEventDateSelectedCopyWith(HistoryEventDateSelected value,
          $Res Function(HistoryEventDateSelected) _then) =
      _$HistoryEventDateSelectedCopyWithImpl;
  @useResult
  $Res call({DateTime date});
}

/// @nodoc
class _$HistoryEventDateSelectedCopyWithImpl<$Res>
    implements $HistoryEventDateSelectedCopyWith<$Res> {
  _$HistoryEventDateSelectedCopyWithImpl(this._self, this._then);

  final HistoryEventDateSelected _self;
  final $Res Function(HistoryEventDateSelected) _then;

  /// Create a copy of HistoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? date = null,
  }) {
    return _then(HistoryEventDateSelected(
      null == date
          ? _self.date
          : date // ignore: cast_nullable_to_non_nullable
              as DateTime,
    ));
  }
}

/// @nodoc

class HistoryEventWallpaperUpdateRequested implements HistoryEvent {
  const HistoryEventWallpaperUpdateRequested(this.index);

  final int index;

  /// Create a copy of HistoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HistoryEventWallpaperUpdateRequestedCopyWith<
          HistoryEventWallpaperUpdateRequested>
      get copyWith => _$HistoryEventWallpaperUpdateRequestedCopyWithImpl<
          HistoryEventWallpaperUpdateRequested>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HistoryEventWallpaperUpdateRequested &&
            (identical(other.index, index) || other.index == index));
  }

  @override
  int get hashCode => Object.hash(runtimeType, index);

  @override
  String toString() {
    return 'HistoryEvent.wallpaperUpdateRequested(index: $index)';
  }
}

/// @nodoc
abstract mixin class $HistoryEventWallpaperUpdateRequestedCopyWith<$Res>
    implements $HistoryEventCopyWith<$Res> {
  factory $HistoryEventWallpaperUpdateRequestedCopyWith(
          HistoryEventWallpaperUpdateRequested value,
          $Res Function(HistoryEventWallpaperUpdateRequested) _then) =
      _$HistoryEventWallpaperUpdateRequestedCopyWithImpl;
  @useResult
  $Res call({int index});
}

/// @nodoc
class _$HistoryEventWallpaperUpdateRequestedCopyWithImpl<$Res>
    implements $HistoryEventWallpaperUpdateRequestedCopyWith<$Res> {
  _$HistoryEventWallpaperUpdateRequestedCopyWithImpl(this._self, this._then);

  final HistoryEventWallpaperUpdateRequested _self;
  final $Res Function(HistoryEventWallpaperUpdateRequested) _then;

  /// Create a copy of HistoryEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? index = null,
  }) {
    return _then(HistoryEventWallpaperUpdateRequested(
      null == index
          ? _self.index
          : index // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

// dart format on
