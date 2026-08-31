// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver_balance_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$DriverBalanceState {

 DriverBalance? get balance; bool get isLoading; bool get loadFailed; bool get isSettling;// Transient: the UI consumes these once (open the URL / show the
// message) and calls `clearSettlementResult` — they don't persist
// across rebuilds the way `balance` does.
 SettlementCheckout? get lastCheckout; String? get settlementError;
/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverBalanceStateCopyWith<DriverBalanceState> get copyWith => _$DriverBalanceStateCopyWithImpl<DriverBalanceState>(this as DriverBalanceState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverBalanceState&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed)&&(identical(other.isSettling, isSettling) || other.isSettling == isSettling)&&(identical(other.lastCheckout, lastCheckout) || other.lastCheckout == lastCheckout)&&(identical(other.settlementError, settlementError) || other.settlementError == settlementError));
}


@override
int get hashCode => Object.hash(runtimeType,balance,isLoading,loadFailed,isSettling,lastCheckout,settlementError);

@override
String toString() {
  return 'DriverBalanceState(balance: $balance, isLoading: $isLoading, loadFailed: $loadFailed, isSettling: $isSettling, lastCheckout: $lastCheckout, settlementError: $settlementError)';
}


}

/// @nodoc
abstract mixin class $DriverBalanceStateCopyWith<$Res>  {
  factory $DriverBalanceStateCopyWith(DriverBalanceState value, $Res Function(DriverBalanceState) _then) = _$DriverBalanceStateCopyWithImpl;
@useResult
$Res call({
 DriverBalance? balance, bool isLoading, bool loadFailed, bool isSettling, SettlementCheckout? lastCheckout, String? settlementError
});


$DriverBalanceCopyWith<$Res>? get balance;$SettlementCheckoutCopyWith<$Res>? get lastCheckout;

}
/// @nodoc
class _$DriverBalanceStateCopyWithImpl<$Res>
    implements $DriverBalanceStateCopyWith<$Res> {
  _$DriverBalanceStateCopyWithImpl(this._self, this._then);

  final DriverBalanceState _self;
  final $Res Function(DriverBalanceState) _then;

/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = freezed,Object? isLoading = null,Object? loadFailed = null,Object? isSettling = null,Object? lastCheckout = freezed,Object? settlementError = freezed,}) {
  return _then(_self.copyWith(
balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as DriverBalance?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,isSettling: null == isSettling ? _self.isSettling : isSettling // ignore: cast_nullable_to_non_nullable
as bool,lastCheckout: freezed == lastCheckout ? _self.lastCheckout : lastCheckout // ignore: cast_nullable_to_non_nullable
as SettlementCheckout?,settlementError: freezed == settlementError ? _self.settlementError : settlementError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DriverBalanceCopyWith<$Res>? get balance {
    if (_self.balance == null) {
    return null;
  }

  return $DriverBalanceCopyWith<$Res>(_self.balance!, (value) {
    return _then(_self.copyWith(balance: value));
  });
}/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SettlementCheckoutCopyWith<$Res>? get lastCheckout {
    if (_self.lastCheckout == null) {
    return null;
  }

  return $SettlementCheckoutCopyWith<$Res>(_self.lastCheckout!, (value) {
    return _then(_self.copyWith(lastCheckout: value));
  });
}
}


/// Adds pattern-matching-related methods to [DriverBalanceState].
extension DriverBalanceStatePatterns on DriverBalanceState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverBalanceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverBalanceState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverBalanceState value)  $default,){
final _that = this;
switch (_that) {
case _DriverBalanceState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverBalanceState value)?  $default,){
final _that = this;
switch (_that) {
case _DriverBalanceState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DriverBalance? balance,  bool isLoading,  bool loadFailed,  bool isSettling,  SettlementCheckout? lastCheckout,  String? settlementError)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverBalanceState() when $default != null:
return $default(_that.balance,_that.isLoading,_that.loadFailed,_that.isSettling,_that.lastCheckout,_that.settlementError);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DriverBalance? balance,  bool isLoading,  bool loadFailed,  bool isSettling,  SettlementCheckout? lastCheckout,  String? settlementError)  $default,) {final _that = this;
switch (_that) {
case _DriverBalanceState():
return $default(_that.balance,_that.isLoading,_that.loadFailed,_that.isSettling,_that.lastCheckout,_that.settlementError);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DriverBalance? balance,  bool isLoading,  bool loadFailed,  bool isSettling,  SettlementCheckout? lastCheckout,  String? settlementError)?  $default,) {final _that = this;
switch (_that) {
case _DriverBalanceState() when $default != null:
return $default(_that.balance,_that.isLoading,_that.loadFailed,_that.isSettling,_that.lastCheckout,_that.settlementError);case _:
  return null;

}
}

}

/// @nodoc


class _DriverBalanceState implements DriverBalanceState {
  const _DriverBalanceState({this.balance, this.isLoading = true, this.loadFailed = false, this.isSettling = false, this.lastCheckout, this.settlementError});
  

@override final  DriverBalance? balance;
@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool loadFailed;
@override@JsonKey() final  bool isSettling;
// Transient: the UI consumes these once (open the URL / show the
// message) and calls `clearSettlementResult` — they don't persist
// across rebuilds the way `balance` does.
@override final  SettlementCheckout? lastCheckout;
@override final  String? settlementError;

/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverBalanceStateCopyWith<_DriverBalanceState> get copyWith => __$DriverBalanceStateCopyWithImpl<_DriverBalanceState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverBalanceState&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed)&&(identical(other.isSettling, isSettling) || other.isSettling == isSettling)&&(identical(other.lastCheckout, lastCheckout) || other.lastCheckout == lastCheckout)&&(identical(other.settlementError, settlementError) || other.settlementError == settlementError));
}


@override
int get hashCode => Object.hash(runtimeType,balance,isLoading,loadFailed,isSettling,lastCheckout,settlementError);

@override
String toString() {
  return 'DriverBalanceState(balance: $balance, isLoading: $isLoading, loadFailed: $loadFailed, isSettling: $isSettling, lastCheckout: $lastCheckout, settlementError: $settlementError)';
}


}

/// @nodoc
abstract mixin class _$DriverBalanceStateCopyWith<$Res> implements $DriverBalanceStateCopyWith<$Res> {
  factory _$DriverBalanceStateCopyWith(_DriverBalanceState value, $Res Function(_DriverBalanceState) _then) = __$DriverBalanceStateCopyWithImpl;
@override @useResult
$Res call({
 DriverBalance? balance, bool isLoading, bool loadFailed, bool isSettling, SettlementCheckout? lastCheckout, String? settlementError
});


@override $DriverBalanceCopyWith<$Res>? get balance;@override $SettlementCheckoutCopyWith<$Res>? get lastCheckout;

}
/// @nodoc
class __$DriverBalanceStateCopyWithImpl<$Res>
    implements _$DriverBalanceStateCopyWith<$Res> {
  __$DriverBalanceStateCopyWithImpl(this._self, this._then);

  final _DriverBalanceState _self;
  final $Res Function(_DriverBalanceState) _then;

/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = freezed,Object? isLoading = null,Object? loadFailed = null,Object? isSettling = null,Object? lastCheckout = freezed,Object? settlementError = freezed,}) {
  return _then(_DriverBalanceState(
balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as DriverBalance?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,isSettling: null == isSettling ? _self.isSettling : isSettling // ignore: cast_nullable_to_non_nullable
as bool,lastCheckout: freezed == lastCheckout ? _self.lastCheckout : lastCheckout // ignore: cast_nullable_to_non_nullable
as SettlementCheckout?,settlementError: freezed == settlementError ? _self.settlementError : settlementError // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$DriverBalanceCopyWith<$Res>? get balance {
    if (_self.balance == null) {
    return null;
  }

  return $DriverBalanceCopyWith<$Res>(_self.balance!, (value) {
    return _then(_self.copyWith(balance: value));
  });
}/// Create a copy of DriverBalanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SettlementCheckoutCopyWith<$Res>? get lastCheckout {
    if (_self.lastCheckout == null) {
    return null;
  }

  return $SettlementCheckoutCopyWith<$Res>(_self.lastCheckout!, (value) {
    return _then(_self.copyWith(lastCheckout: value));
  });
}
}

// dart format on
