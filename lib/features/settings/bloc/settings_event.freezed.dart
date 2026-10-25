// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SettingsEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is SettingsEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SettingsEvent()';
  }
}

/// @nodoc
class $SettingsEventCopyWith<$Res> {
  $SettingsEventCopyWith(SettingsEvent _, $Res Function(SettingsEvent) __);
}

/// Adds pattern-matching-related methods to [SettingsEvent].
extension SettingsEventPatterns on SettingsEvent {
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
    TResult Function(SettingsEventStarted value)? started,
    TResult Function(SettingsEventLockWallpaperToggled value)?
        lockWallpaperToggled,
    TResult Function(SettingsEventNasaToggled value)? nasaToggled,
    TResult Function(SettingsEventCategoriesChanged value)? categoriesChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started(_that);
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that);
      case SettingsEventNasaToggled() when nasaToggled != null:
        return nasaToggled(_that);
      case SettingsEventCategoriesChanged() when categoriesChanged != null:
        return categoriesChanged(_that);
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
    required TResult Function(SettingsEventStarted value) started,
    required TResult Function(SettingsEventLockWallpaperToggled value)
        lockWallpaperToggled,
    required TResult Function(SettingsEventNasaToggled value) nasaToggled,
    required TResult Function(SettingsEventCategoriesChanged value)
        categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted():
        return started(_that);
      case SettingsEventLockWallpaperToggled():
        return lockWallpaperToggled(_that);
      case SettingsEventNasaToggled():
        return nasaToggled(_that);
      case SettingsEventCategoriesChanged():
        return categoriesChanged(_that);
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
    TResult? Function(SettingsEventStarted value)? started,
    TResult? Function(SettingsEventLockWallpaperToggled value)?
        lockWallpaperToggled,
    TResult? Function(SettingsEventNasaToggled value)? nasaToggled,
    TResult? Function(SettingsEventCategoriesChanged value)? categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started(_that);
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that);
      case SettingsEventNasaToggled() when nasaToggled != null:
        return nasaToggled(_that);
      case SettingsEventCategoriesChanged() when categoriesChanged != null:
        return categoriesChanged(_that);
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
    TResult Function(bool value)? lockWallpaperToggled,
    TResult Function(bool value)? nasaToggled,
    TResult Function(List<String> categories)? categoriesChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started();
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that.value);
      case SettingsEventNasaToggled() when nasaToggled != null:
        return nasaToggled(_that.value);
      case SettingsEventCategoriesChanged() when categoriesChanged != null:
        return categoriesChanged(_that.categories);
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
    required TResult Function(bool value) lockWallpaperToggled,
    required TResult Function(bool value) nasaToggled,
    required TResult Function(List<String> categories) categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted():
        return started();
      case SettingsEventLockWallpaperToggled():
        return lockWallpaperToggled(_that.value);
      case SettingsEventNasaToggled():
        return nasaToggled(_that.value);
      case SettingsEventCategoriesChanged():
        return categoriesChanged(_that.categories);
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
    TResult? Function(bool value)? lockWallpaperToggled,
    TResult? Function(bool value)? nasaToggled,
    TResult? Function(List<String> categories)? categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started();
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that.value);
      case SettingsEventNasaToggled() when nasaToggled != null:
        return nasaToggled(_that.value);
      case SettingsEventCategoriesChanged() when categoriesChanged != null:
        return categoriesChanged(_that.categories);
      case _:
        return null;
    }
  }
}

/// @nodoc

class SettingsEventStarted implements SettingsEvent {
  const SettingsEventStarted();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is SettingsEventStarted);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'SettingsEvent.started()';
  }
}

/// @nodoc

class SettingsEventLockWallpaperToggled implements SettingsEvent {
  const SettingsEventLockWallpaperToggled(this.value);

  final bool value;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsEventLockWallpaperToggledCopyWith<SettingsEventLockWallpaperToggled>
      get copyWith => _$SettingsEventLockWallpaperToggledCopyWithImpl<
          SettingsEventLockWallpaperToggled>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsEventLockWallpaperToggled &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() {
    return 'SettingsEvent.lockWallpaperToggled(value: $value)';
  }
}

/// @nodoc
abstract mixin class $SettingsEventLockWallpaperToggledCopyWith<$Res>
    implements $SettingsEventCopyWith<$Res> {
  factory $SettingsEventLockWallpaperToggledCopyWith(
          SettingsEventLockWallpaperToggled value,
          $Res Function(SettingsEventLockWallpaperToggled) _then) =
      _$SettingsEventLockWallpaperToggledCopyWithImpl;
  @useResult
  $Res call({bool value});
}

/// @nodoc
class _$SettingsEventLockWallpaperToggledCopyWithImpl<$Res>
    implements $SettingsEventLockWallpaperToggledCopyWith<$Res> {
  _$SettingsEventLockWallpaperToggledCopyWithImpl(this._self, this._then);

  final SettingsEventLockWallpaperToggled _self;
  final $Res Function(SettingsEventLockWallpaperToggled) _then;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? value = null,
  }) {
    return _then(SettingsEventLockWallpaperToggled(
      null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class SettingsEventNasaToggled implements SettingsEvent {
  const SettingsEventNasaToggled(this.value);

  final bool value;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsEventNasaToggledCopyWith<SettingsEventNasaToggled> get copyWith =>
      _$SettingsEventNasaToggledCopyWithImpl<SettingsEventNasaToggled>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsEventNasaToggled &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() {
    return 'SettingsEvent.nasaToggled(value: $value)';
  }
}

/// @nodoc
abstract mixin class $SettingsEventNasaToggledCopyWith<$Res>
    implements $SettingsEventCopyWith<$Res> {
  factory $SettingsEventNasaToggledCopyWith(SettingsEventNasaToggled value,
          $Res Function(SettingsEventNasaToggled) _then) =
      _$SettingsEventNasaToggledCopyWithImpl;
  @useResult
  $Res call({bool value});
}

/// @nodoc
class _$SettingsEventNasaToggledCopyWithImpl<$Res>
    implements $SettingsEventNasaToggledCopyWith<$Res> {
  _$SettingsEventNasaToggledCopyWithImpl(this._self, this._then);

  final SettingsEventNasaToggled _self;
  final $Res Function(SettingsEventNasaToggled) _then;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? value = null,
  }) {
    return _then(SettingsEventNasaToggled(
      null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class SettingsEventCategoriesChanged implements SettingsEvent {
  const SettingsEventCategoriesChanged(final List<String> categories)
      : _categories = categories;

  final List<String> _categories;
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsEventCategoriesChangedCopyWith<SettingsEventCategoriesChanged>
      get copyWith => _$SettingsEventCategoriesChangedCopyWithImpl<
          SettingsEventCategoriesChanged>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsEventCategoriesChanged &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_categories));

  @override
  String toString() {
    return 'SettingsEvent.categoriesChanged(categories: $categories)';
  }
}

/// @nodoc
abstract mixin class $SettingsEventCategoriesChangedCopyWith<$Res>
    implements $SettingsEventCopyWith<$Res> {
  factory $SettingsEventCategoriesChangedCopyWith(
          SettingsEventCategoriesChanged value,
          $Res Function(SettingsEventCategoriesChanged) _then) =
      _$SettingsEventCategoriesChangedCopyWithImpl;
  @useResult
  $Res call({List<String> categories});
}

/// @nodoc
class _$SettingsEventCategoriesChangedCopyWithImpl<$Res>
    implements $SettingsEventCategoriesChangedCopyWith<$Res> {
  _$SettingsEventCategoriesChangedCopyWithImpl(this._self, this._then);

  final SettingsEventCategoriesChanged _self;
  final $Res Function(SettingsEventCategoriesChanged) _then;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? categories = null,
  }) {
    return _then(SettingsEventCategoriesChanged(
      null == categories
          ? _self._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
