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
    TResult Function(SettingsEventRegionChanged value)? regionChanged,
    TResult Function(SettingsEventLockWallpaperToggled value)?
        lockWallpaperToggled,
    TResult Function(SettingsEventSmartCropToggled value)? smartCropToggled,
    TResult Function(SettingsEventSmartCropLevelChanged value)?
        smartCropLevelChanged,
    TResult Function(SettingsEventSubjectScalingToggled value)?
        subjectScalingToggled,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started(_that);
      case SettingsEventRegionChanged() when regionChanged != null:
        return regionChanged(_that);
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that);
      case SettingsEventSmartCropToggled() when smartCropToggled != null:
        return smartCropToggled(_that);
      case SettingsEventSmartCropLevelChanged()
          when smartCropLevelChanged != null:
        return smartCropLevelChanged(_that);
      case SettingsEventSubjectScalingToggled()
          when subjectScalingToggled != null:
        return subjectScalingToggled(_that);
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
    required TResult Function(SettingsEventRegionChanged value) regionChanged,
    required TResult Function(SettingsEventLockWallpaperToggled value)
        lockWallpaperToggled,
    required TResult Function(SettingsEventSmartCropToggled value)
        smartCropToggled,
    required TResult Function(SettingsEventSmartCropLevelChanged value)
        smartCropLevelChanged,
    required TResult Function(SettingsEventSubjectScalingToggled value)
        subjectScalingToggled,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted():
        return started(_that);
      case SettingsEventRegionChanged():
        return regionChanged(_that);
      case SettingsEventLockWallpaperToggled():
        return lockWallpaperToggled(_that);
      case SettingsEventSmartCropToggled():
        return smartCropToggled(_that);
      case SettingsEventSmartCropLevelChanged():
        return smartCropLevelChanged(_that);
      case SettingsEventSubjectScalingToggled():
        return subjectScalingToggled(_that);
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
    TResult? Function(SettingsEventRegionChanged value)? regionChanged,
    TResult? Function(SettingsEventLockWallpaperToggled value)?
        lockWallpaperToggled,
    TResult? Function(SettingsEventSmartCropToggled value)? smartCropToggled,
    TResult? Function(SettingsEventSmartCropLevelChanged value)?
        smartCropLevelChanged,
    TResult? Function(SettingsEventSubjectScalingToggled value)?
        subjectScalingToggled,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started(_that);
      case SettingsEventRegionChanged() when regionChanged != null:
        return regionChanged(_that);
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that);
      case SettingsEventSmartCropToggled() when smartCropToggled != null:
        return smartCropToggled(_that);
      case SettingsEventSmartCropLevelChanged()
          when smartCropLevelChanged != null:
        return smartCropLevelChanged(_that);
      case SettingsEventSubjectScalingToggled()
          when subjectScalingToggled != null:
        return subjectScalingToggled(_that);
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
    TResult Function(BingRegionEnum region)? regionChanged,
    TResult Function(bool value)? lockWallpaperToggled,
    TResult Function(bool value)? smartCropToggled,
    TResult Function(int level)? smartCropLevelChanged,
    TResult Function(bool value)? subjectScalingToggled,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started();
      case SettingsEventRegionChanged() when regionChanged != null:
        return regionChanged(_that.region);
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that.value);
      case SettingsEventSmartCropToggled() when smartCropToggled != null:
        return smartCropToggled(_that.value);
      case SettingsEventSmartCropLevelChanged()
          when smartCropLevelChanged != null:
        return smartCropLevelChanged(_that.level);
      case SettingsEventSubjectScalingToggled()
          when subjectScalingToggled != null:
        return subjectScalingToggled(_that.value);
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
    required TResult Function(BingRegionEnum region) regionChanged,
    required TResult Function(bool value) lockWallpaperToggled,
    required TResult Function(bool value) smartCropToggled,
    required TResult Function(int level) smartCropLevelChanged,
    required TResult Function(bool value) subjectScalingToggled,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted():
        return started();
      case SettingsEventRegionChanged():
        return regionChanged(_that.region);
      case SettingsEventLockWallpaperToggled():
        return lockWallpaperToggled(_that.value);
      case SettingsEventSmartCropToggled():
        return smartCropToggled(_that.value);
      case SettingsEventSmartCropLevelChanged():
        return smartCropLevelChanged(_that.level);
      case SettingsEventSubjectScalingToggled():
        return subjectScalingToggled(_that.value);
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
    TResult? Function(BingRegionEnum region)? regionChanged,
    TResult? Function(bool value)? lockWallpaperToggled,
    TResult? Function(bool value)? smartCropToggled,
    TResult? Function(int level)? smartCropLevelChanged,
    TResult? Function(bool value)? subjectScalingToggled,
  }) {
    final _that = this;
    switch (_that) {
      case SettingsEventStarted() when started != null:
        return started();
      case SettingsEventRegionChanged() when regionChanged != null:
        return regionChanged(_that.region);
      case SettingsEventLockWallpaperToggled()
          when lockWallpaperToggled != null:
        return lockWallpaperToggled(_that.value);
      case SettingsEventSmartCropToggled() when smartCropToggled != null:
        return smartCropToggled(_that.value);
      case SettingsEventSmartCropLevelChanged()
          when smartCropLevelChanged != null:
        return smartCropLevelChanged(_that.level);
      case SettingsEventSubjectScalingToggled()
          when subjectScalingToggled != null:
        return subjectScalingToggled(_that.value);
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

class SettingsEventRegionChanged implements SettingsEvent {
  const SettingsEventRegionChanged(this.region);

  final BingRegionEnum region;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsEventRegionChangedCopyWith<SettingsEventRegionChanged>
      get copyWith =>
          _$SettingsEventRegionChangedCopyWithImpl<SettingsEventRegionChanged>(
              this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsEventRegionChanged &&
            (identical(other.region, region) || other.region == region));
  }

  @override
  int get hashCode => Object.hash(runtimeType, region);

  @override
  String toString() {
    return 'SettingsEvent.regionChanged(region: $region)';
  }
}

/// @nodoc
abstract mixin class $SettingsEventRegionChangedCopyWith<$Res>
    implements $SettingsEventCopyWith<$Res> {
  factory $SettingsEventRegionChangedCopyWith(SettingsEventRegionChanged value,
          $Res Function(SettingsEventRegionChanged) _then) =
      _$SettingsEventRegionChangedCopyWithImpl;
  @useResult
  $Res call({BingRegionEnum region});
}

/// @nodoc
class _$SettingsEventRegionChangedCopyWithImpl<$Res>
    implements $SettingsEventRegionChangedCopyWith<$Res> {
  _$SettingsEventRegionChangedCopyWithImpl(this._self, this._then);

  final SettingsEventRegionChanged _self;
  final $Res Function(SettingsEventRegionChanged) _then;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? region = null,
  }) {
    return _then(SettingsEventRegionChanged(
      null == region
          ? _self.region
          : region // ignore: cast_nullable_to_non_nullable
              as BingRegionEnum,
    ));
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

class SettingsEventSmartCropToggled implements SettingsEvent {
  const SettingsEventSmartCropToggled(this.value);

  final bool value;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsEventSmartCropToggledCopyWith<SettingsEventSmartCropToggled>
      get copyWith => _$SettingsEventSmartCropToggledCopyWithImpl<
          SettingsEventSmartCropToggled>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsEventSmartCropToggled &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() {
    return 'SettingsEvent.smartCropToggled(value: $value)';
  }
}

/// @nodoc
abstract mixin class $SettingsEventSmartCropToggledCopyWith<$Res>
    implements $SettingsEventCopyWith<$Res> {
  factory $SettingsEventSmartCropToggledCopyWith(
          SettingsEventSmartCropToggled value,
          $Res Function(SettingsEventSmartCropToggled) _then) =
      _$SettingsEventSmartCropToggledCopyWithImpl;
  @useResult
  $Res call({bool value});
}

/// @nodoc
class _$SettingsEventSmartCropToggledCopyWithImpl<$Res>
    implements $SettingsEventSmartCropToggledCopyWith<$Res> {
  _$SettingsEventSmartCropToggledCopyWithImpl(this._self, this._then);

  final SettingsEventSmartCropToggled _self;
  final $Res Function(SettingsEventSmartCropToggled) _then;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? value = null,
  }) {
    return _then(SettingsEventSmartCropToggled(
      null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class SettingsEventSmartCropLevelChanged implements SettingsEvent {
  const SettingsEventSmartCropLevelChanged(this.level);

  final int level;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsEventSmartCropLevelChangedCopyWith<
          SettingsEventSmartCropLevelChanged>
      get copyWith => _$SettingsEventSmartCropLevelChangedCopyWithImpl<
          SettingsEventSmartCropLevelChanged>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsEventSmartCropLevelChanged &&
            (identical(other.level, level) || other.level == level));
  }

  @override
  int get hashCode => Object.hash(runtimeType, level);

  @override
  String toString() {
    return 'SettingsEvent.smartCropLevelChanged(level: $level)';
  }
}

/// @nodoc
abstract mixin class $SettingsEventSmartCropLevelChangedCopyWith<$Res>
    implements $SettingsEventCopyWith<$Res> {
  factory $SettingsEventSmartCropLevelChangedCopyWith(
          SettingsEventSmartCropLevelChanged value,
          $Res Function(SettingsEventSmartCropLevelChanged) _then) =
      _$SettingsEventSmartCropLevelChangedCopyWithImpl;
  @useResult
  $Res call({int level});
}

/// @nodoc
class _$SettingsEventSmartCropLevelChangedCopyWithImpl<$Res>
    implements $SettingsEventSmartCropLevelChangedCopyWith<$Res> {
  _$SettingsEventSmartCropLevelChangedCopyWithImpl(this._self, this._then);

  final SettingsEventSmartCropLevelChanged _self;
  final $Res Function(SettingsEventSmartCropLevelChanged) _then;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? level = null,
  }) {
    return _then(SettingsEventSmartCropLevelChanged(
      null == level
          ? _self.level
          : level // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class SettingsEventSubjectScalingToggled implements SettingsEvent {
  const SettingsEventSubjectScalingToggled(this.value);

  final bool value;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsEventSubjectScalingToggledCopyWith<
          SettingsEventSubjectScalingToggled>
      get copyWith => _$SettingsEventSubjectScalingToggledCopyWithImpl<
          SettingsEventSubjectScalingToggled>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsEventSubjectScalingToggled &&
            (identical(other.value, value) || other.value == value));
  }

  @override
  int get hashCode => Object.hash(runtimeType, value);

  @override
  String toString() {
    return 'SettingsEvent.subjectScalingToggled(value: $value)';
  }
}

/// @nodoc
abstract mixin class $SettingsEventSubjectScalingToggledCopyWith<$Res>
    implements $SettingsEventCopyWith<$Res> {
  factory $SettingsEventSubjectScalingToggledCopyWith(
          SettingsEventSubjectScalingToggled value,
          $Res Function(SettingsEventSubjectScalingToggled) _then) =
      _$SettingsEventSubjectScalingToggledCopyWithImpl;
  @useResult
  $Res call({bool value});
}

/// @nodoc
class _$SettingsEventSubjectScalingToggledCopyWithImpl<$Res>
    implements $SettingsEventSubjectScalingToggledCopyWith<$Res> {
  _$SettingsEventSubjectScalingToggledCopyWithImpl(this._self, this._then);

  final SettingsEventSubjectScalingToggled _self;
  final $Res Function(SettingsEventSubjectScalingToggled) _then;

  /// Create a copy of SettingsEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? value = null,
  }) {
    return _then(SettingsEventSubjectScalingToggled(
      null == value
          ? _self.value
          : value // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

// dart format on
