// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'settings_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SettingsState {
  BingRegionEnum get selectedRegion;
  bool get includeLockWallpaper;
  bool get isSmartCropEnabled;
  int get smartCropLevel;
  bool get enableSubjectScaling;
  DeviceCapability? get deviceCapability;
  List<RegionItem> get thumbnails;
  bool get isLoading;
  String? get error;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $SettingsStateCopyWith<SettingsState> get copyWith =>
      _$SettingsStateCopyWithImpl<SettingsState>(
          this as SettingsState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is SettingsState &&
            (identical(other.selectedRegion, selectedRegion) ||
                other.selectedRegion == selectedRegion) &&
            (identical(other.includeLockWallpaper, includeLockWallpaper) ||
                other.includeLockWallpaper == includeLockWallpaper) &&
            (identical(other.isSmartCropEnabled, isSmartCropEnabled) ||
                other.isSmartCropEnabled == isSmartCropEnabled) &&
            (identical(other.smartCropLevel, smartCropLevel) ||
                other.smartCropLevel == smartCropLevel) &&
            (identical(other.enableSubjectScaling, enableSubjectScaling) ||
                other.enableSubjectScaling == enableSubjectScaling) &&
            (identical(other.deviceCapability, deviceCapability) ||
                other.deviceCapability == deviceCapability) &&
            const DeepCollectionEquality()
                .equals(other.thumbnails, thumbnails) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedRegion,
      includeLockWallpaper,
      isSmartCropEnabled,
      smartCropLevel,
      enableSubjectScaling,
      deviceCapability,
      const DeepCollectionEquality().hash(thumbnails),
      isLoading,
      error);

  @override
  String toString() {
    return 'SettingsState(selectedRegion: $selectedRegion, includeLockWallpaper: $includeLockWallpaper, isSmartCropEnabled: $isSmartCropEnabled, smartCropLevel: $smartCropLevel, enableSubjectScaling: $enableSubjectScaling, deviceCapability: $deviceCapability, thumbnails: $thumbnails, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class $SettingsStateCopyWith<$Res> {
  factory $SettingsStateCopyWith(
          SettingsState value, $Res Function(SettingsState) _then) =
      _$SettingsStateCopyWithImpl;
  @useResult
  $Res call(
      {BingRegionEnum selectedRegion,
      bool includeLockWallpaper,
      bool isSmartCropEnabled,
      int smartCropLevel,
      bool enableSubjectScaling,
      DeviceCapability? deviceCapability,
      List<RegionItem> thumbnails,
      bool isLoading,
      String? error});
}

/// @nodoc
class _$SettingsStateCopyWithImpl<$Res>
    implements $SettingsStateCopyWith<$Res> {
  _$SettingsStateCopyWithImpl(this._self, this._then);

  final SettingsState _self;
  final $Res Function(SettingsState) _then;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? selectedRegion = null,
    Object? includeLockWallpaper = null,
    Object? isSmartCropEnabled = null,
    Object? smartCropLevel = null,
    Object? enableSubjectScaling = null,
    Object? deviceCapability = freezed,
    Object? thumbnails = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      selectedRegion: null == selectedRegion
          ? _self.selectedRegion
          : selectedRegion // ignore: cast_nullable_to_non_nullable
              as BingRegionEnum,
      includeLockWallpaper: null == includeLockWallpaper
          ? _self.includeLockWallpaper
          : includeLockWallpaper // ignore: cast_nullable_to_non_nullable
              as bool,
      isSmartCropEnabled: null == isSmartCropEnabled
          ? _self.isSmartCropEnabled
          : isSmartCropEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smartCropLevel: null == smartCropLevel
          ? _self.smartCropLevel
          : smartCropLevel // ignore: cast_nullable_to_non_nullable
              as int,
      enableSubjectScaling: null == enableSubjectScaling
          ? _self.enableSubjectScaling
          : enableSubjectScaling // ignore: cast_nullable_to_non_nullable
              as bool,
      deviceCapability: freezed == deviceCapability
          ? _self.deviceCapability
          : deviceCapability // ignore: cast_nullable_to_non_nullable
              as DeviceCapability?,
      thumbnails: null == thumbnails
          ? _self.thumbnails
          : thumbnails // ignore: cast_nullable_to_non_nullable
              as List<RegionItem>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// Adds pattern-matching-related methods to [SettingsState].
extension SettingsStatePatterns on SettingsState {
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
  TResult maybeMap<TResult extends Object?>(
    TResult Function(_SettingsState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(_that);
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
  TResult map<TResult extends Object?>(
    TResult Function(_SettingsState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState():
        return $default(_that);
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
  TResult? mapOrNull<TResult extends Object?>(
    TResult? Function(_SettingsState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(_that);
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
  TResult maybeWhen<TResult extends Object?>(
    TResult Function(
            BingRegionEnum selectedRegion,
            bool includeLockWallpaper,
            bool isSmartCropEnabled,
            int smartCropLevel,
            bool enableSubjectScaling,
            DeviceCapability? deviceCapability,
            List<RegionItem> thumbnails,
            bool isLoading,
            String? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(
            _that.selectedRegion,
            _that.includeLockWallpaper,
            _that.isSmartCropEnabled,
            _that.smartCropLevel,
            _that.enableSubjectScaling,
            _that.deviceCapability,
            _that.thumbnails,
            _that.isLoading,
            _that.error);
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
  TResult when<TResult extends Object?>(
    TResult Function(
            BingRegionEnum selectedRegion,
            bool includeLockWallpaper,
            bool isSmartCropEnabled,
            int smartCropLevel,
            bool enableSubjectScaling,
            DeviceCapability? deviceCapability,
            List<RegionItem> thumbnails,
            bool isLoading,
            String? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState():
        return $default(
            _that.selectedRegion,
            _that.includeLockWallpaper,
            _that.isSmartCropEnabled,
            _that.smartCropLevel,
            _that.enableSubjectScaling,
            _that.deviceCapability,
            _that.thumbnails,
            _that.isLoading,
            _that.error);
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
  TResult? whenOrNull<TResult extends Object?>(
    TResult? Function(
            BingRegionEnum selectedRegion,
            bool includeLockWallpaper,
            bool isSmartCropEnabled,
            int smartCropLevel,
            bool enableSubjectScaling,
            DeviceCapability? deviceCapability,
            List<RegionItem> thumbnails,
            bool isLoading,
            String? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _SettingsState() when $default != null:
        return $default(
            _that.selectedRegion,
            _that.includeLockWallpaper,
            _that.isSmartCropEnabled,
            _that.smartCropLevel,
            _that.enableSubjectScaling,
            _that.deviceCapability,
            _that.thumbnails,
            _that.isLoading,
            _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _SettingsState implements SettingsState {
  const _SettingsState(
      {required this.selectedRegion,
      required this.includeLockWallpaper,
      required this.isSmartCropEnabled,
      required this.smartCropLevel,
      required this.enableSubjectScaling,
      this.deviceCapability,
      required final List<RegionItem> thumbnails,
      this.isLoading = false,
      this.error})
      : _thumbnails = thumbnails;

  @override
  final BingRegionEnum selectedRegion;
  @override
  final bool includeLockWallpaper;
  @override
  final bool isSmartCropEnabled;
  @override
  final int smartCropLevel;
  @override
  final bool enableSubjectScaling;
  @override
  final DeviceCapability? deviceCapability;
  final List<RegionItem> _thumbnails;
  @override
  List<RegionItem> get thumbnails {
    if (_thumbnails is EqualUnmodifiableListView) return _thumbnails;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_thumbnails);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$SettingsStateCopyWith<_SettingsState> get copyWith =>
      __$SettingsStateCopyWithImpl<_SettingsState>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _SettingsState &&
            (identical(other.selectedRegion, selectedRegion) ||
                other.selectedRegion == selectedRegion) &&
            (identical(other.includeLockWallpaper, includeLockWallpaper) ||
                other.includeLockWallpaper == includeLockWallpaper) &&
            (identical(other.isSmartCropEnabled, isSmartCropEnabled) ||
                other.isSmartCropEnabled == isSmartCropEnabled) &&
            (identical(other.smartCropLevel, smartCropLevel) ||
                other.smartCropLevel == smartCropLevel) &&
            (identical(other.enableSubjectScaling, enableSubjectScaling) ||
                other.enableSubjectScaling == enableSubjectScaling) &&
            (identical(other.deviceCapability, deviceCapability) ||
                other.deviceCapability == deviceCapability) &&
            const DeepCollectionEquality()
                .equals(other._thumbnails, _thumbnails) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      selectedRegion,
      includeLockWallpaper,
      isSmartCropEnabled,
      smartCropLevel,
      enableSubjectScaling,
      deviceCapability,
      const DeepCollectionEquality().hash(_thumbnails),
      isLoading,
      error);

  @override
  String toString() {
    return 'SettingsState(selectedRegion: $selectedRegion, includeLockWallpaper: $includeLockWallpaper, isSmartCropEnabled: $isSmartCropEnabled, smartCropLevel: $smartCropLevel, enableSubjectScaling: $enableSubjectScaling, deviceCapability: $deviceCapability, thumbnails: $thumbnails, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$SettingsStateCopyWith<$Res>
    implements $SettingsStateCopyWith<$Res> {
  factory _$SettingsStateCopyWith(
          _SettingsState value, $Res Function(_SettingsState) _then) =
      __$SettingsStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {BingRegionEnum selectedRegion,
      bool includeLockWallpaper,
      bool isSmartCropEnabled,
      int smartCropLevel,
      bool enableSubjectScaling,
      DeviceCapability? deviceCapability,
      List<RegionItem> thumbnails,
      bool isLoading,
      String? error});
}

/// @nodoc
class __$SettingsStateCopyWithImpl<$Res>
    implements _$SettingsStateCopyWith<$Res> {
  __$SettingsStateCopyWithImpl(this._self, this._then);

  final _SettingsState _self;
  final $Res Function(_SettingsState) _then;

  /// Create a copy of SettingsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? selectedRegion = null,
    Object? includeLockWallpaper = null,
    Object? isSmartCropEnabled = null,
    Object? smartCropLevel = null,
    Object? enableSubjectScaling = null,
    Object? deviceCapability = freezed,
    Object? thumbnails = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_SettingsState(
      selectedRegion: null == selectedRegion
          ? _self.selectedRegion
          : selectedRegion // ignore: cast_nullable_to_non_nullable
              as BingRegionEnum,
      includeLockWallpaper: null == includeLockWallpaper
          ? _self.includeLockWallpaper
          : includeLockWallpaper // ignore: cast_nullable_to_non_nullable
              as bool,
      isSmartCropEnabled: null == isSmartCropEnabled
          ? _self.isSmartCropEnabled
          : isSmartCropEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      smartCropLevel: null == smartCropLevel
          ? _self.smartCropLevel
          : smartCropLevel // ignore: cast_nullable_to_non_nullable
              as int,
      enableSubjectScaling: null == enableSubjectScaling
          ? _self.enableSubjectScaling
          : enableSubjectScaling // ignore: cast_nullable_to_non_nullable
              as bool,
      deviceCapability: freezed == deviceCapability
          ? _self.deviceCapability
          : deviceCapability // ignore: cast_nullable_to_non_nullable
              as DeviceCapability?,
      thumbnails: null == thumbnails
          ? _self._thumbnails
          : thumbnails // ignore: cast_nullable_to_non_nullable
              as List<RegionItem>,
      isLoading: null == isLoading
          ? _self.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _self.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

// dart format on
