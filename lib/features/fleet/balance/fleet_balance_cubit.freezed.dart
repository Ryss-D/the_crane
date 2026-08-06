// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fleet_balance_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$FleetBalanceState {

 FleetBalance? get balance; bool get isLoading; bool get loadFailed;
/// Create a copy of FleetBalanceState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FleetBalanceStateCopyWith<FleetBalanceState> get copyWith => _$FleetBalanceStateCopyWithImpl<FleetBalanceState>(this as FleetBalanceState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FleetBalanceState&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed));
}


@override
int get hashCode => Object.hash(runtimeType,balance,isLoading,loadFailed);

@override
String toString() {
  return 'FleetBalanceState(balance: $balance, isLoading: $isLoading, loadFailed: $loadFailed)';
}


}

/// @nodoc
abstract mixin class $FleetBalanceStateCopyWith<$Res>  {
  factory $FleetBalanceStateCopyWith(FleetBalanceState value, $Res Function(FleetBalanceState) _then) = _$FleetBalanceStateCopyWithImpl;
@useResult
$Res call({
 FleetBalance? balance, bool isLoading, bool loadFailed
});


$FleetBalanceCopyWith<$Res>? get balance;

}
/// @nodoc
class _$FleetBalanceStateCopyWithImpl<$Res>
    implements $FleetBalanceStateCopyWith<$Res> {
  _$FleetBalanceStateCopyWithImpl(this._self, this._then);

  final FleetBalanceState _self;
  final $Res Function(FleetBalanceState) _then;

/// Create a copy of FleetBalanceState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? balance = freezed,Object? isLoading = null,Object? loadFailed = null,}) {
  return _then(_self.copyWith(
balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as FleetBalance?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of FleetBalanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FleetBalanceCopyWith<$Res>? get balance {
    if (_self.balance == null) {
    return null;
  }

  return $FleetBalanceCopyWith<$Res>(_self.balance!, (value) {
    return _then(_self.copyWith(balance: value));
  });
}
}


/// Adds pattern-matching-related methods to [FleetBalanceState].
extension FleetBalanceStatePatterns on FleetBalanceState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FleetBalanceState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FleetBalanceState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FleetBalanceState value)  $default,){
final _that = this;
switch (_that) {
case _FleetBalanceState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FleetBalanceState value)?  $default,){
final _that = this;
switch (_that) {
case _FleetBalanceState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( FleetBalance? balance,  bool isLoading,  bool loadFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FleetBalanceState() when $default != null:
return $default(_that.balance,_that.isLoading,_that.loadFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( FleetBalance? balance,  bool isLoading,  bool loadFailed)  $default,) {final _that = this;
switch (_that) {
case _FleetBalanceState():
return $default(_that.balance,_that.isLoading,_that.loadFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( FleetBalance? balance,  bool isLoading,  bool loadFailed)?  $default,) {final _that = this;
switch (_that) {
case _FleetBalanceState() when $default != null:
return $default(_that.balance,_that.isLoading,_that.loadFailed);case _:
  return null;

}
}

}

/// @nodoc


class _FleetBalanceState implements FleetBalanceState {
  const _FleetBalanceState({this.balance, this.isLoading = true, this.loadFailed = false});
  

@override final  FleetBalance? balance;
@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool loadFailed;

/// Create a copy of FleetBalanceState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FleetBalanceStateCopyWith<_FleetBalanceState> get copyWith => __$FleetBalanceStateCopyWithImpl<_FleetBalanceState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FleetBalanceState&&(identical(other.balance, balance) || other.balance == balance)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed));
}


@override
int get hashCode => Object.hash(runtimeType,balance,isLoading,loadFailed);

@override
String toString() {
  return 'FleetBalanceState(balance: $balance, isLoading: $isLoading, loadFailed: $loadFailed)';
}


}

/// @nodoc
abstract mixin class _$FleetBalanceStateCopyWith<$Res> implements $FleetBalanceStateCopyWith<$Res> {
  factory _$FleetBalanceStateCopyWith(_FleetBalanceState value, $Res Function(_FleetBalanceState) _then) = __$FleetBalanceStateCopyWithImpl;
@override @useResult
$Res call({
 FleetBalance? balance, bool isLoading, bool loadFailed
});


@override $FleetBalanceCopyWith<$Res>? get balance;

}
/// @nodoc
class __$FleetBalanceStateCopyWithImpl<$Res>
    implements _$FleetBalanceStateCopyWith<$Res> {
  __$FleetBalanceStateCopyWithImpl(this._self, this._then);

  final _FleetBalanceState _self;
  final $Res Function(_FleetBalanceState) _then;

/// Create a copy of FleetBalanceState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? balance = freezed,Object? isLoading = null,Object? loadFailed = null,}) {
  return _then(_FleetBalanceState(
balance: freezed == balance ? _self.balance : balance // ignore: cast_nullable_to_non_nullable
as FleetBalance?,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of FleetBalanceState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$FleetBalanceCopyWith<$Res>? get balance {
    if (_self.balance == null) {
    return null;
  }

  return $FleetBalanceCopyWith<$Res>(_self.balance!, (value) {
    return _then(_self.copyWith(balance: value));
  });
}
}

// dart format on
