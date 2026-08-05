// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver_home_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DriverHomeState {

 DriverStatus get status; bool get isUpdating; DriverProfile? get profile;
/// Create a copy of DriverHomeState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverHomeStateCopyWith<DriverHomeState> get copyWith => _$DriverHomeStateCopyWithImpl<DriverHomeState>(this as DriverHomeState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverHomeState&&(identical(other.status, status) || other.status == status)&&(identical(other.isUpdating, isUpdating) || other.isUpdating == isUpdating)&&(identical(other.profile, profile) || other.profile == profile));
}


@override
int get hashCode => Object.hash(runtimeType,status,isUpdating,profile);

@override
String toString() {
  return 'DriverHomeState(status: $status, isUpdating: $isUpdating, profile: $profile)';
}


}

/// @nodoc
abstract mixin class $DriverHomeStateCopyWith<$Res>  {
  factory $DriverHomeStateCopyWith(DriverHomeState value, $Res Function(DriverHomeState) _then) = _$DriverHomeStateCopyWithImpl;
@useResult
$Res call({
 DriverStatus status, bool isUpdating, DriverProfile? profile
});


$DriverProfileCopyWith<$Res>? get profile;

}
/// @nodoc
class _$DriverHomeStateCopyWithImpl<$Res>
    implements $DriverHomeStateCopyWith<$Res> {
  _$DriverHomeStateCopyWithImpl(this._self, this._then);

  final DriverHomeState _self;
  final $Res Function(DriverHomeState) _then;

/// Create a copy of DriverHomeState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? status = null,Object? isUpdating = null,Object? profile = freezed,}) {
  return _then(_self.copyWith(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DriverStatus,isUpdating: null == isUpdating ? _self.isUpdating : isUpdating // ignore: cast_nullable_to_non_nullable
as bool,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as DriverProfile?,
  ));
}
/// Create a copy of DriverHomeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DriverProfileCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $DriverProfileCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}


/// Adds pattern-matching-related methods to [DriverHomeState].
extension DriverHomeStatePatterns on DriverHomeState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverHomeState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverHomeState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverHomeState value)  $default,){
final _that = this;
switch (_that) {
case _DriverHomeState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverHomeState value)?  $default,){
final _that = this;
switch (_that) {
case _DriverHomeState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DriverStatus status,  bool isUpdating,  DriverProfile? profile)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverHomeState() when $default != null:
return $default(_that.status,_that.isUpdating,_that.profile);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DriverStatus status,  bool isUpdating,  DriverProfile? profile)  $default,) {final _that = this;
switch (_that) {
case _DriverHomeState():
return $default(_that.status,_that.isUpdating,_that.profile);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DriverStatus status,  bool isUpdating,  DriverProfile? profile)?  $default,) {final _that = this;
switch (_that) {
case _DriverHomeState() when $default != null:
return $default(_that.status,_that.isUpdating,_that.profile);case _:
  return null;

}
}

}

/// @nodoc


class _DriverHomeState extends DriverHomeState {
  const _DriverHomeState({this.status = DriverStatus.offline, this.isUpdating = false, this.profile}): super._();
  

@override@JsonKey() final  DriverStatus status;
@override@JsonKey() final  bool isUpdating;
@override final  DriverProfile? profile;

/// Create a copy of DriverHomeState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverHomeStateCopyWith<_DriverHomeState> get copyWith => __$DriverHomeStateCopyWithImpl<_DriverHomeState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverHomeState&&(identical(other.status, status) || other.status == status)&&(identical(other.isUpdating, isUpdating) || other.isUpdating == isUpdating)&&(identical(other.profile, profile) || other.profile == profile));
}


@override
int get hashCode => Object.hash(runtimeType,status,isUpdating,profile);

@override
String toString() {
  return 'DriverHomeState(status: $status, isUpdating: $isUpdating, profile: $profile)';
}


}

/// @nodoc
abstract mixin class _$DriverHomeStateCopyWith<$Res> implements $DriverHomeStateCopyWith<$Res> {
  factory _$DriverHomeStateCopyWith(_DriverHomeState value, $Res Function(_DriverHomeState) _then) = __$DriverHomeStateCopyWithImpl;
@override @useResult
$Res call({
 DriverStatus status, bool isUpdating, DriverProfile? profile
});


@override $DriverProfileCopyWith<$Res>? get profile;

}
/// @nodoc
class __$DriverHomeStateCopyWithImpl<$Res>
    implements _$DriverHomeStateCopyWith<$Res> {
  __$DriverHomeStateCopyWithImpl(this._self, this._then);

  final _DriverHomeState _self;
  final $Res Function(_DriverHomeState) _then;

/// Create a copy of DriverHomeState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? status = null,Object? isUpdating = null,Object? profile = freezed,}) {
  return _then(_DriverHomeState(
status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DriverStatus,isUpdating: null == isUpdating ? _self.isUpdating : isUpdating // ignore: cast_nullable_to_non_nullable
as bool,profile: freezed == profile ? _self.profile : profile // ignore: cast_nullable_to_non_nullable
as DriverProfile?,
  ));
}

/// Create a copy of DriverHomeState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DriverProfileCopyWith<$Res>? get profile {
    if (_self.profile == null) {
    return null;
  }

  return $DriverProfileCopyWith<$Res>(_self.profile!, (value) {
    return _then(_self.copyWith(profile: value));
  });
}
}

// dart format on
