// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'home_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$HomeEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is HomeEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'HomeEvent()';
  }
}

/// @nodoc
class $HomeEventCopyWith<$Res> {
  $HomeEventCopyWith(HomeEvent _, $Res Function(HomeEvent) __);
}

/// Adds pattern-matching-related methods to [HomeEvent].
extension HomeEventPatterns on HomeEvent {
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
    TResult Function(HomeEventStarted value)? started,
    TResult Function(HomeEventRefreshRequested value)? refreshRequested,
    TResult Function(HomeEventIndexChanged value)? indexChanged,
    TResult Function(HomeEventWallpaperUpdateRequested value)?
        wallpaperUpdateRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case HomeEventStarted() when started != null:
        return started(_that);
      case HomeEventRefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case HomeEventIndexChanged() when indexChanged != null:
        return indexChanged(_that);
      case HomeEventWallpaperUpdateRequested()
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
    required TResult Function(HomeEventStarted value) started,
    required TResult Function(HomeEventRefreshRequested value) refreshRequested,
    required TResult Function(HomeEventIndexChanged value) indexChanged,
    required TResult Function(HomeEventWallpaperUpdateRequested value)
        wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HomeEventStarted():
        return started(_that);
      case HomeEventRefreshRequested():
        return refreshRequested(_that);
      case HomeEventIndexChanged():
        return indexChanged(_that);
      case HomeEventWallpaperUpdateRequested():
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
    TResult? Function(HomeEventStarted value)? started,
    TResult? Function(HomeEventRefreshRequested value)? refreshRequested,
    TResult? Function(HomeEventIndexChanged value)? indexChanged,
    TResult? Function(HomeEventWallpaperUpdateRequested value)?
        wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HomeEventStarted() when started != null:
        return started(_that);
      case HomeEventRefreshRequested() when refreshRequested != null:
        return refreshRequested(_that);
      case HomeEventIndexChanged() when indexChanged != null:
        return indexChanged(_that);
      case HomeEventWallpaperUpdateRequested()
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
    TResult Function()? refreshRequested,
    TResult Function(int newIndex)? indexChanged,
    TResult Function()? wallpaperUpdateRequested,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case HomeEventStarted() when started != null:
        return started();
      case HomeEventRefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case HomeEventIndexChanged() when indexChanged != null:
        return indexChanged(_that.newIndex);
      case HomeEventWallpaperUpdateRequested()
          when wallpaperUpdateRequested != null:
        return wallpaperUpdateRequested();
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
    required TResult Function() refreshRequested,
    required TResult Function(int newIndex) indexChanged,
    required TResult Function() wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HomeEventStarted():
        return started();
      case HomeEventRefreshRequested():
        return refreshRequested();
      case HomeEventIndexChanged():
        return indexChanged(_that.newIndex);
      case HomeEventWallpaperUpdateRequested():
        return wallpaperUpdateRequested();
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
    TResult? Function()? refreshRequested,
    TResult? Function(int newIndex)? indexChanged,
    TResult? Function()? wallpaperUpdateRequested,
  }) {
    final _that = this;
    switch (_that) {
      case HomeEventStarted() when started != null:
        return started();
      case HomeEventRefreshRequested() when refreshRequested != null:
        return refreshRequested();
      case HomeEventIndexChanged() when indexChanged != null:
        return indexChanged(_that.newIndex);
      case HomeEventWallpaperUpdateRequested()
          when wallpaperUpdateRequested != null:
        return wallpaperUpdateRequested();
      case _:
        return null;
    }
  }
}

/// @nodoc

class HomeEventStarted implements HomeEvent {
  const HomeEventStarted();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is HomeEventStarted);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'HomeEvent.started()';
  }
}

/// @nodoc

class HomeEventRefreshRequested implements HomeEvent {
  const HomeEventRefreshRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HomeEventRefreshRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'HomeEvent.refreshRequested()';
  }
}

/// @nodoc

class HomeEventIndexChanged implements HomeEvent {
  const HomeEventIndexChanged(this.newIndex);

  final int newIndex;

  /// Create a copy of HomeEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $HomeEventIndexChangedCopyWith<HomeEventIndexChanged> get copyWith =>
      _$HomeEventIndexChangedCopyWithImpl<HomeEventIndexChanged>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HomeEventIndexChanged &&
            (identical(other.newIndex, newIndex) ||
                other.newIndex == newIndex));
  }

  @override
  int get hashCode => Object.hash(runtimeType, newIndex);

  @override
  String toString() {
    return 'HomeEvent.indexChanged(newIndex: $newIndex)';
  }
}

/// @nodoc
abstract mixin class $HomeEventIndexChangedCopyWith<$Res>
    implements $HomeEventCopyWith<$Res> {
  factory $HomeEventIndexChangedCopyWith(HomeEventIndexChanged value,
          $Res Function(HomeEventIndexChanged) _then) =
      _$HomeEventIndexChangedCopyWithImpl;
  @useResult
  $Res call({int newIndex});
}

/// @nodoc
class _$HomeEventIndexChangedCopyWithImpl<$Res>
    implements $HomeEventIndexChangedCopyWith<$Res> {
  _$HomeEventIndexChangedCopyWithImpl(this._self, this._then);

  final HomeEventIndexChanged _self;
  final $Res Function(HomeEventIndexChanged) _then;

  /// Create a copy of HomeEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? newIndex = null,
  }) {
    return _then(HomeEventIndexChanged(
      null == newIndex
          ? _self.newIndex
          : newIndex // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class HomeEventWallpaperUpdateRequested implements HomeEvent {
  const HomeEventWallpaperUpdateRequested();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is HomeEventWallpaperUpdateRequested);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'HomeEvent.wallpaperUpdateRequested()';
  }
}

// dart format on
