// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'auth_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$AuthState {

 AuthPhase get phase; bool get isSendingCode; bool get sendCodeFailed; bool get isConfirmingCode; bool get confirmCodeFailed; String? get verificationId; String? get phoneNumber; AppUser? get user;
/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$AuthStateCopyWith<AuthState> get copyWith => _$AuthStateCopyWithImpl<AuthState>(this as AuthState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is AuthState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.isSendingCode, isSendingCode) || other.isSendingCode == isSendingCode)&&(identical(other.sendCodeFailed, sendCodeFailed) || other.sendCodeFailed == sendCodeFailed)&&(identical(other.isConfirmingCode, isConfirmingCode) || other.isConfirmingCode == isConfirmingCode)&&(identical(other.confirmCodeFailed, confirmCodeFailed) || other.confirmCodeFailed == confirmCodeFailed)&&(identical(other.verificationId, verificationId) || other.verificationId == verificationId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,phase,isSendingCode,sendCodeFailed,isConfirmingCode,confirmCodeFailed,verificationId,phoneNumber,user);

@override
String toString() {
  return 'AuthState(phase: $phase, isSendingCode: $isSendingCode, sendCodeFailed: $sendCodeFailed, isConfirmingCode: $isConfirmingCode, confirmCodeFailed: $confirmCodeFailed, verificationId: $verificationId, phoneNumber: $phoneNumber, user: $user)';
}


}

/// @nodoc
abstract mixin class $AuthStateCopyWith<$Res>  {
  factory $AuthStateCopyWith(AuthState value, $Res Function(AuthState) _then) = _$AuthStateCopyWithImpl;
@useResult
$Res call({
 AuthPhase phase, bool isSendingCode, bool sendCodeFailed, bool isConfirmingCode, bool confirmCodeFailed, String? verificationId, String? phoneNumber, AppUser? user
});


$AppUserCopyWith<$Res>? get user;

}
/// @nodoc
class _$AuthStateCopyWithImpl<$Res>
    implements $AuthStateCopyWith<$Res> {
  _$AuthStateCopyWithImpl(this._self, this._then);

  final AuthState _self;
  final $Res Function(AuthState) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? phase = null,Object? isSendingCode = null,Object? sendCodeFailed = null,Object? isConfirmingCode = null,Object? confirmCodeFailed = null,Object? verificationId = freezed,Object? phoneNumber = freezed,Object? user = freezed,}) {
  return _then(_self.copyWith(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as AuthPhase,isSendingCode: null == isSendingCode ? _self.isSendingCode : isSendingCode // ignore: cast_nullable_to_non_nullable
as bool,sendCodeFailed: null == sendCodeFailed ? _self.sendCodeFailed : sendCodeFailed // ignore: cast_nullable_to_non_nullable
as bool,isConfirmingCode: null == isConfirmingCode ? _self.isConfirmingCode : isConfirmingCode // ignore: cast_nullable_to_non_nullable
as bool,confirmCodeFailed: null == confirmCodeFailed ? _self.confirmCodeFailed : confirmCodeFailed // ignore: cast_nullable_to_non_nullable
as bool,verificationId: freezed == verificationId ? _self.verificationId : verificationId // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AppUser?,
  ));
}
/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppUserCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $AppUserCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}


/// Adds pattern-matching-related methods to [AuthState].
extension AuthStatePatterns on AuthState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _AuthState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _AuthState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _AuthState value)  $default,){
final _that = this;
switch (_that) {
case _AuthState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _AuthState value)?  $default,){
final _that = this;
switch (_that) {
case _AuthState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( AuthPhase phase,  bool isSendingCode,  bool sendCodeFailed,  bool isConfirmingCode,  bool confirmCodeFailed,  String? verificationId,  String? phoneNumber,  AppUser? user)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _AuthState() when $default != null:
return $default(_that.phase,_that.isSendingCode,_that.sendCodeFailed,_that.isConfirmingCode,_that.confirmCodeFailed,_that.verificationId,_that.phoneNumber,_that.user);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( AuthPhase phase,  bool isSendingCode,  bool sendCodeFailed,  bool isConfirmingCode,  bool confirmCodeFailed,  String? verificationId,  String? phoneNumber,  AppUser? user)  $default,) {final _that = this;
switch (_that) {
case _AuthState():
return $default(_that.phase,_that.isSendingCode,_that.sendCodeFailed,_that.isConfirmingCode,_that.confirmCodeFailed,_that.verificationId,_that.phoneNumber,_that.user);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( AuthPhase phase,  bool isSendingCode,  bool sendCodeFailed,  bool isConfirmingCode,  bool confirmCodeFailed,  String? verificationId,  String? phoneNumber,  AppUser? user)?  $default,) {final _that = this;
switch (_that) {
case _AuthState() when $default != null:
return $default(_that.phase,_that.isSendingCode,_that.sendCodeFailed,_that.isConfirmingCode,_that.confirmCodeFailed,_that.verificationId,_that.phoneNumber,_that.user);case _:
  return null;

}
}

}

/// @nodoc


class _AuthState extends AuthState {
  const _AuthState({this.phase = AuthPhase.unauthenticated, this.isSendingCode = false, this.sendCodeFailed = false, this.isConfirmingCode = false, this.confirmCodeFailed = false, this.verificationId, this.phoneNumber, this.user}): super._();
  

@override@JsonKey() final  AuthPhase phase;
@override@JsonKey() final  bool isSendingCode;
@override@JsonKey() final  bool sendCodeFailed;
@override@JsonKey() final  bool isConfirmingCode;
@override@JsonKey() final  bool confirmCodeFailed;
@override final  String? verificationId;
@override final  String? phoneNumber;
@override final  AppUser? user;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$AuthStateCopyWith<_AuthState> get copyWith => __$AuthStateCopyWithImpl<_AuthState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _AuthState&&(identical(other.phase, phase) || other.phase == phase)&&(identical(other.isSendingCode, isSendingCode) || other.isSendingCode == isSendingCode)&&(identical(other.sendCodeFailed, sendCodeFailed) || other.sendCodeFailed == sendCodeFailed)&&(identical(other.isConfirmingCode, isConfirmingCode) || other.isConfirmingCode == isConfirmingCode)&&(identical(other.confirmCodeFailed, confirmCodeFailed) || other.confirmCodeFailed == confirmCodeFailed)&&(identical(other.verificationId, verificationId) || other.verificationId == verificationId)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.user, user) || other.user == user));
}


@override
int get hashCode => Object.hash(runtimeType,phase,isSendingCode,sendCodeFailed,isConfirmingCode,confirmCodeFailed,verificationId,phoneNumber,user);

@override
String toString() {
  return 'AuthState(phase: $phase, isSendingCode: $isSendingCode, sendCodeFailed: $sendCodeFailed, isConfirmingCode: $isConfirmingCode, confirmCodeFailed: $confirmCodeFailed, verificationId: $verificationId, phoneNumber: $phoneNumber, user: $user)';
}


}

/// @nodoc
abstract mixin class _$AuthStateCopyWith<$Res> implements $AuthStateCopyWith<$Res> {
  factory _$AuthStateCopyWith(_AuthState value, $Res Function(_AuthState) _then) = __$AuthStateCopyWithImpl;
@override @useResult
$Res call({
 AuthPhase phase, bool isSendingCode, bool sendCodeFailed, bool isConfirmingCode, bool confirmCodeFailed, String? verificationId, String? phoneNumber, AppUser? user
});


@override $AppUserCopyWith<$Res>? get user;

}
/// @nodoc
class __$AuthStateCopyWithImpl<$Res>
    implements _$AuthStateCopyWith<$Res> {
  __$AuthStateCopyWithImpl(this._self, this._then);

  final _AuthState _self;
  final $Res Function(_AuthState) _then;

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? phase = null,Object? isSendingCode = null,Object? sendCodeFailed = null,Object? isConfirmingCode = null,Object? confirmCodeFailed = null,Object? verificationId = freezed,Object? phoneNumber = freezed,Object? user = freezed,}) {
  return _then(_AuthState(
phase: null == phase ? _self.phase : phase // ignore: cast_nullable_to_non_nullable
as AuthPhase,isSendingCode: null == isSendingCode ? _self.isSendingCode : isSendingCode // ignore: cast_nullable_to_non_nullable
as bool,sendCodeFailed: null == sendCodeFailed ? _self.sendCodeFailed : sendCodeFailed // ignore: cast_nullable_to_non_nullable
as bool,isConfirmingCode: null == isConfirmingCode ? _self.isConfirmingCode : isConfirmingCode // ignore: cast_nullable_to_non_nullable
as bool,confirmCodeFailed: null == confirmCodeFailed ? _self.confirmCodeFailed : confirmCodeFailed // ignore: cast_nullable_to_non_nullable
as bool,verificationId: freezed == verificationId ? _self.verificationId : verificationId // ignore: cast_nullable_to_non_nullable
as String?,phoneNumber: freezed == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
as String?,user: freezed == user ? _self.user : user // ignore: cast_nullable_to_non_nullable
as AppUser?,
  ));
}

/// Create a copy of AuthState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$AppUserCopyWith<$Res>? get user {
    if (_self.user == null) {
    return null;
  }

  return $AppUserCopyWith<$Res>(_self.user!, (value) {
    return _then(_self.copyWith(user: value));
  });
}
}

// dart format on
