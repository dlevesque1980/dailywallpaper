// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'pexels_categories_event.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$PexelsCategoriesEvent {
  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType && other is PexelsCategoriesEvent);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'PexelsCategoriesEvent()';
  }
}

/// @nodoc
class $PexelsCategoriesEventCopyWith<$Res> {
  $PexelsCategoriesEventCopyWith(
      PexelsCategoriesEvent _, $Res Function(PexelsCategoriesEvent) __);
}

/// Adds pattern-matching-related methods to [PexelsCategoriesEvent].
extension PexelsCategoriesEventPatterns on PexelsCategoriesEvent {
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
    TResult Function(PexelsCategoriesEventStarted value)? started,
    TResult Function(PexelsCategoriesEventCategoriesChanged value)?
        categoriesChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case PexelsCategoriesEventStarted() when started != null:
        return started(_that);
      case PexelsCategoriesEventCategoriesChanged()
          when categoriesChanged != null:
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
    required TResult Function(PexelsCategoriesEventStarted value) started,
    required TResult Function(PexelsCategoriesEventCategoriesChanged value)
        categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PexelsCategoriesEventStarted():
        return started(_that);
      case PexelsCategoriesEventCategoriesChanged():
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
    TResult? Function(PexelsCategoriesEventStarted value)? started,
    TResult? Function(PexelsCategoriesEventCategoriesChanged value)?
        categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PexelsCategoriesEventStarted() when started != null:
        return started(_that);
      case PexelsCategoriesEventCategoriesChanged()
          when categoriesChanged != null:
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
    TResult Function(List<String> categories)? categoriesChanged,
    required TResult orElse(),
  }) {
    final _that = this;
    switch (_that) {
      case PexelsCategoriesEventStarted() when started != null:
        return started();
      case PexelsCategoriesEventCategoriesChanged()
          when categoriesChanged != null:
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
    required TResult Function(List<String> categories) categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PexelsCategoriesEventStarted():
        return started();
      case PexelsCategoriesEventCategoriesChanged():
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
    TResult? Function(List<String> categories)? categoriesChanged,
  }) {
    final _that = this;
    switch (_that) {
      case PexelsCategoriesEventStarted() when started != null:
        return started();
      case PexelsCategoriesEventCategoriesChanged()
          when categoriesChanged != null:
        return categoriesChanged(_that.categories);
      case _:
        return null;
    }
  }
}

/// @nodoc

class PexelsCategoriesEventStarted implements PexelsCategoriesEvent {
  const PexelsCategoriesEventStarted();

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PexelsCategoriesEventStarted);
  }

  @override
  int get hashCode => runtimeType.hashCode;

  @override
  String toString() {
    return 'PexelsCategoriesEvent.started()';
  }
}

/// @nodoc

class PexelsCategoriesEventCategoriesChanged implements PexelsCategoriesEvent {
  const PexelsCategoriesEventCategoriesChanged(final List<String> categories)
      : _categories = categories;

  final List<String> _categories;
  List<String> get categories {
    if (_categories is EqualUnmodifiableListView) return _categories;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_categories);
  }

  /// Create a copy of PexelsCategoriesEvent
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $PexelsCategoriesEventCategoriesChangedCopyWith<
          PexelsCategoriesEventCategoriesChanged>
      get copyWith => _$PexelsCategoriesEventCategoriesChangedCopyWithImpl<
          PexelsCategoriesEventCategoriesChanged>(this, _$identity);

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is PexelsCategoriesEventCategoriesChanged &&
            const DeepCollectionEquality()
                .equals(other._categories, _categories));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType, const DeepCollectionEquality().hash(_categories));

  @override
  String toString() {
    return 'PexelsCategoriesEvent.categoriesChanged(categories: $categories)';
  }
}

/// @nodoc
abstract mixin class $PexelsCategoriesEventCategoriesChangedCopyWith<$Res>
    implements $PexelsCategoriesEventCopyWith<$Res> {
  factory $PexelsCategoriesEventCategoriesChangedCopyWith(
          PexelsCategoriesEventCategoriesChanged value,
          $Res Function(PexelsCategoriesEventCategoriesChanged) _then) =
      _$PexelsCategoriesEventCategoriesChangedCopyWithImpl;
  @useResult
  $Res call({List<String> categories});
}

/// @nodoc
class _$PexelsCategoriesEventCategoriesChangedCopyWithImpl<$Res>
    implements $PexelsCategoriesEventCategoriesChangedCopyWith<$Res> {
  _$PexelsCategoriesEventCategoriesChangedCopyWithImpl(this._self, this._then);

  final PexelsCategoriesEventCategoriesChanged _self;
  final $Res Function(PexelsCategoriesEventCategoriesChanged) _then;

  /// Create a copy of PexelsCategoriesEvent
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  $Res call({
    Object? categories = null,
  }) {
    return _then(PexelsCategoriesEventCategoriesChanged(
      null == categories
          ? _self._categories
          : categories // ignore: cast_nullable_to_non_nullable
              as List<String>,
    ));
  }
}

// dart format on
