// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fleet_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FleetState {

 Fleet? get fleet; bool get isLoading; bool get loadFailed;
/// Create a copy of FleetState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FleetStateCopyWith<FleetState> get copyWith => _$FleetStateCopyWithImpl<FleetState>(this as FleetState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FleetState&&(identical(other.fleet, fleet) || other.fleet == fleet)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed));
}


@override
int get hashCode => Object.hash(runtimeType,fleet,isLoading,loadFailed);

@override
String toString() {
  return 'FleetState(fleet: $fleet, isLoading: $isLoading, loadFailed: $loadFailed)';
}


}

/// @nodoc
abstract mixin class $FleetStateCopyWith<$Res>  {
  factory $FleetStateCopyWith(FleetState value, $Res Function(FleetState) _then) = _$FleetStateCopyWithImpl;
@useResult
$Res call({
 Fleet? fleet, bool isLoading, bool loadFailed
});


$FleetCopyWith<$Res>? get fleet;

}
/// @nodoc
class _$FleetStateCopyWithImpl<$Res>
    implements $FleetStateCopyWith<$Res> {
  _$FleetStateCopyWithImpl(this._self, this._then);

  final FleetState _self;
  final $Res Function(FleetState) _then;

/// Create a copy of FleetState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fleet = freezed,Object? isLoading = null,Object? loadFailed = null,}) {
  return _then(_self.copyWith(
fleet: freezed == fleet ? _self.fleet : fleet // ignore: cast_nullable_to_non_nullable
as Fleet?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of FleetState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FleetCopyWith<$Res>? get fleet {
    if (_self.fleet == null) {
    return null;
  }

  return $FleetCopyWith<$Res>(_self.fleet!, (value) {
    return _then(_self.copyWith(fleet: value));
  });
}
}


/// Adds pattern-matching-related methods to [FleetState].
extension FleetStatePatterns on FleetState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FleetState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FleetState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FleetState value)  $default,){
final _that = this;
switch (_that) {
case _FleetState():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FleetState value)?  $default,){
final _that = this;
switch (_that) {
case _FleetState() when $default != null:
return $default(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Fleet? fleet,  bool isLoading,  bool loadFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FleetState() when $default != null:
return $default(_that.fleet,_that.isLoading,_that.loadFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Fleet? fleet,  bool isLoading,  bool loadFailed)  $default,) {final _that = this;
switch (_that) {
case _FleetState():
return $default(_that.fleet,_that.isLoading,_that.loadFailed);case _:
  throw StateError('Unexpected subclass');

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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Fleet? fleet,  bool isLoading,  bool loadFailed)?  $default,) {final _that = this;
switch (_that) {
case _FleetState() when $default != null:
return $default(_that.fleet,_that.isLoading,_that.loadFailed);case _:
  return null;

}
}

}

/// @nodoc


class _FleetState implements FleetState {
  const _FleetState({this.fleet, this.isLoading = true, this.loadFailed = false});
  

@override final  Fleet? fleet;
@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool loadFailed;

/// Create a copy of FleetState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FleetStateCopyWith<_FleetState> get copyWith => __$FleetStateCopyWithImpl<_FleetState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FleetState&&(identical(other.fleet, fleet) || other.fleet == fleet)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed));
}


@override
int get hashCode => Object.hash(runtimeType,fleet,isLoading,loadFailed);

@override
String toString() {
  return 'FleetState(fleet: $fleet, isLoading: $isLoading, loadFailed: $loadFailed)';
}


}

/// @nodoc
abstract mixin class _$FleetStateCopyWith<$Res> implements $FleetStateCopyWith<$Res> {
  factory _$FleetStateCopyWith(_FleetState value, $Res Function(_FleetState) _then) = __$FleetStateCopyWithImpl;
@override @useResult
$Res call({
 Fleet? fleet, bool isLoading, bool loadFailed
});


@override $FleetCopyWith<$Res>? get fleet;

}
/// @nodoc
class __$FleetStateCopyWithImpl<$Res>
    implements _$FleetStateCopyWith<$Res> {
  __$FleetStateCopyWithImpl(this._self, this._then);

  final _FleetState _self;
  final $Res Function(_FleetState) _then;

/// Create a copy of FleetState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fleet = freezed,Object? isLoading = null,Object? loadFailed = null,}) {
  return _then(_FleetState(
fleet: freezed == fleet ? _self.fleet : fleet // ignore: cast_nullable_to_non_nullable
as Fleet?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of FleetState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FleetCopyWith<$Res>? get fleet {
    if (_self.fleet == null) {
    return null;
  }

  return $FleetCopyWith<$Res>(_self.fleet!, (value) {
    return _then(_self.copyWith(fleet: value));
  });
}
}

// dart format on
