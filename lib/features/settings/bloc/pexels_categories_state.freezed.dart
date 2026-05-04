// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pexels_categories_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PexelsCategoriesState {
  List<String> get allCategories;
  List<String> get selectedCategories;
  bool get isLoading;
  String? get error;

  /// Create a copy of PexelsCategoriesState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PexelsCategoriesStateCopyWith<PexelsCategoriesState> get copyWith =>
      _$PexelsCategoriesStateCopyWithImpl<PexelsCategoriesState>(
          this as PexelsCategoriesState, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PexelsCategoriesState &&
            const DeepCollectionEquality()
                .equals(other.allCategories, allCategories) &&
            const DeepCollectionEquality()
                .equals(other.selectedCategories, selectedCategories) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(allCategories),
      const DeepCollectionEquality().hash(selectedCategories),
      isLoading,
      error);

  @override
  String toString() {
    return 'PexelsCategoriesState(allCategories: $allCategories, selectedCategories: $selectedCategories, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class $PexelsCategoriesStateCopyWith<$Res> {
  factory $PexelsCategoriesStateCopyWith(PexelsCategoriesState value,
          $Res Function(PexelsCategoriesState) _then) =
      _$PexelsCategoriesStateCopyWithImpl;
  @useResult
  $Res call(
      {List<String> allCategories,
      List<String> selectedCategories,
      bool isLoading,
      String? error});
}

/// @nodoc
class _$PexelsCategoriesStateCopyWithImpl<$Res>
    implements $PexelsCategoriesStateCopyWith<$Res> {
  _$PexelsCategoriesStateCopyWithImpl(this._self, this._then);

  final PexelsCategoriesState _self;
  final $Res Function(PexelsCategoriesState) _then;

  /// Create a copy of PexelsCategoriesState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? allCategories = null,
    Object? selectedCategories = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_self.copyWith(
      allCategories: null == allCategories
          ? _self.allCategories
          : allCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      selectedCategories: null == selectedCategories
          ? _self.selectedCategories
          : selectedCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
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

/// Adds pattern-matching-related methods to [PexelsCategoriesState].
extension PexelsCategoriesStatePatterns on PexelsCategoriesState {
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
    TResult Function(_PexelsCategoriesState value)? $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PexelsCategoriesState() when $default != null:
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
    TResult Function(_PexelsCategoriesState value) $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PexelsCategoriesState():
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
    TResult? Function(_PexelsCategoriesState value)? $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PexelsCategoriesState() when $default != null:
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
    TResult Function(List<String> allCategories,
            List<String> selectedCategories, bool isLoading, String? error)?
        $default, {
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case _PexelsCategoriesState() when $default != null:
        return $default(_that.allCategories, _that.selectedCategories,
            _that.isLoading, _that.error);
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
    TResult Function(List<String> allCategories,
            List<String> selectedCategories, bool isLoading, String? error)
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PexelsCategoriesState():
        return $default(_that.allCategories, _that.selectedCategories,
            _that.isLoading, _that.error);
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
    TResult? Function(List<String> allCategories,
            List<String> selectedCategories, bool isLoading, String? error)?
        $default,
  ) {
    final _that = this;
    switch (_that) {
      case _PexelsCategoriesState() when $default != null:
        return $default(_that.allCategories, _that.selectedCategories,
            _that.isLoading, _that.error);
      case _:
        return null;
    }
  }
}

/// @nodoc

class _PexelsCategoriesState implements PexelsCategoriesState {
  const _PexelsCategoriesState(
      {required final List<String> allCategories,
      required final List<String> selectedCategories,
      this.isLoading = false,
      this.error})
      : _allCategories = allCategories,
        _selectedCategories = selectedCategories;

  final List<String> _allCategories;
  @override
  List<String> get allCategories {
    if (_allCategories is EqualUnmodifiableListView) return _allCategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_allCategories);
  }

  final List<String> _selectedCategories;
  @override
  List<String> get selectedCategories {
    if (_selectedCategories is EqualUnmodifiableListView)
      return _selectedCategories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_selectedCategories);
  }

  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? error;

  /// Create a copy of PexelsCategoriesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  _$PexelsCategoriesStateCopyWith<_PexelsCategoriesState> get copyWith =>
      __$PexelsCategoriesStateCopyWithImpl<_PexelsCategoriesState>(
          this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _PexelsCategoriesState &&
            const DeepCollectionEquality()
                .equals(other._allCategories, _allCategories) &&
            const DeepCollectionEquality()
                .equals(other._selectedCategories, _selectedCategories) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_allCategories),
      const DeepCollectionEquality().hash(_selectedCategories),
      isLoading,
      error);

  @override
  String toString() {
    return 'PexelsCategoriesState(allCategories: $allCategories, selectedCategories: $selectedCategories, isLoading: $isLoading, error: $error)';
  }
}

/// @nodoc
abstract mixin class _$PexelsCategoriesStateCopyWith<$Res>
    implements $PexelsCategoriesStateCopyWith<$Res> {
  factory _$PexelsCategoriesStateCopyWith(_PexelsCategoriesState value,
          $Res Function(_PexelsCategoriesState) _then) =
      __$PexelsCategoriesStateCopyWithImpl;
  @override
  @useResult
  $Res call(
      {List<String> allCategories,
      List<String> selectedCategories,
      bool isLoading,
      String? error});
}

/// @nodoc
class __$PexelsCategoriesStateCopyWithImpl<$Res>
    implements _$PexelsCategoriesStateCopyWith<$Res> {
  __$PexelsCategoriesStateCopyWithImpl(this._self, this._then);

  final _PexelsCategoriesState _self;
  final $Res Function(_PexelsCategoriesState) _then;

  /// Create a copy of PexelsCategoriesState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $Res call({
    Object? allCategories = null,
    Object? selectedCategories = null,
    Object? isLoading = null,
    Object? error = freezed,
  }) {
    return _then(_PexelsCategoriesState(
      allCategories: null == allCategories
          ? _self._allCategories
          : allCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
      selectedCategories: null == selectedCategories
          ? _self._selectedCategories
          : selectedCategories // ignore: cast_nullable_to_non_nullable
              as List<String>,
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
