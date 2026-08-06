// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'active_job_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ActiveJobState {

 Job? get job; String? get errorMessage;
/// Create a copy of ActiveJobState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveJobStateCopyWith<ActiveJobState> get copyWith => _$ActiveJobStateCopyWithImpl<ActiveJobState>(this as ActiveJobState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveJobState&&(identical(other.job, job) || other.job == job)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,job,errorMessage);

@override
String toString() {
  return 'ActiveJobState(job: $job, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class $ActiveJobStateCopyWith<$Res>  {
  factory $ActiveJobStateCopyWith(ActiveJobState value, $Res Function(ActiveJobState) _then) = _$ActiveJobStateCopyWithImpl;
@useResult
$Res call({
 Job? job, String? errorMessage
});


$JobCopyWith<$Res>? get job;

}
/// @nodoc
class _$ActiveJobStateCopyWithImpl<$Res>
    implements $ActiveJobStateCopyWith<$Res> {
  _$ActiveJobStateCopyWithImpl(this._self, this._then);

  final ActiveJobState _self;
  final $Res Function(ActiveJobState) _then;

/// Create a copy of ActiveJobState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? job = freezed,Object? errorMessage = freezed,}) {
  return _then(_self.copyWith(
job: freezed == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as Job?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of ActiveJobState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobCopyWith<$Res>? get job {
    if (_self.job == null) {
    return null;
  }

  return $JobCopyWith<$Res>(_self.job!, (value) {
    return _then(_self.copyWith(job: value));
  });
}
}


/// Adds pattern-matching-related methods to [ActiveJobState].
extension ActiveJobStatePatterns on ActiveJobState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActiveJobState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActiveJobState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActiveJobState value)  $default,){
final _that = this;
switch (_that) {
case _ActiveJobState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActiveJobState value)?  $default,){
final _that = this;
switch (_that) {
case _ActiveJobState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Job? job,  String? errorMessage)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActiveJobState() when $default != null:
return $default(_that.job,_that.errorMessage);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Job? job,  String? errorMessage)  $default,) {final _that = this;
switch (_that) {
case _ActiveJobState():
return $default(_that.job,_that.errorMessage);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Job? job,  String? errorMessage)?  $default,) {final _that = this;
switch (_that) {
case _ActiveJobState() when $default != null:
return $default(_that.job,_that.errorMessage);case _:
  return null;

}
}

}

/// @nodoc


class _ActiveJobState implements ActiveJobState {
  const _ActiveJobState({this.job, this.errorMessage});
  

@override final  Job? job;
@override final  String? errorMessage;

/// Create a copy of ActiveJobState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveJobStateCopyWith<_ActiveJobState> get copyWith => __$ActiveJobStateCopyWithImpl<_ActiveJobState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveJobState&&(identical(other.job, job) || other.job == job)&&(identical(other.errorMessage, errorMessage) || other.errorMessage == errorMessage));
}


@override
int get hashCode => Object.hash(runtimeType,job,errorMessage);

@override
String toString() {
  return 'ActiveJobState(job: $job, errorMessage: $errorMessage)';
}


}

/// @nodoc
abstract mixin class _$ActiveJobStateCopyWith<$Res> implements $ActiveJobStateCopyWith<$Res> {
  factory _$ActiveJobStateCopyWith(_ActiveJobState value, $Res Function(_ActiveJobState) _then) = __$ActiveJobStateCopyWithImpl;
@override @useResult
$Res call({
 Job? job, String? errorMessage
});


@override $JobCopyWith<$Res>? get job;

}
/// @nodoc
class __$ActiveJobStateCopyWithImpl<$Res>
    implements _$ActiveJobStateCopyWith<$Res> {
  __$ActiveJobStateCopyWithImpl(this._self, this._then);

  final _ActiveJobState _self;
  final $Res Function(_ActiveJobState) _then;

/// Create a copy of ActiveJobState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? job = freezed,Object? errorMessage = freezed,}) {
  return _then(_ActiveJobState(
job: freezed == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as Job?,errorMessage: freezed == errorMessage ? _self.errorMessage : errorMessage // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of ActiveJobState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobCopyWith<$Res>? get job {
    if (_self.job == null) {
    return null;
  }

  return $JobCopyWith<$Res>(_self.job!, (value) {
    return _then(_self.copyWith(job: value));
  });
}
}

// dart format on
