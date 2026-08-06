// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'request_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$RequestState {

 String get pickupAddress; String get dropoffAddress; VehicleType get vehicleType; Quote? get quote; bool get isQuoting; bool get quoteFailed; bool get isCreatingJob; bool get createJobFailed; Job? get activeJob; bool get isConfirmingDelivery; bool get confirmDeliveryFailed;
/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequestStateCopyWith<RequestState> get copyWith => _$RequestStateCopyWithImpl<RequestState>(this as RequestState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RequestState&&(identical(other.pickupAddress, pickupAddress) || other.pickupAddress == pickupAddress)&&(identical(other.dropoffAddress, dropoffAddress) || other.dropoffAddress == dropoffAddress)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.isQuoting, isQuoting) || other.isQuoting == isQuoting)&&(identical(other.quoteFailed, quoteFailed) || other.quoteFailed == quoteFailed)&&(identical(other.isCreatingJob, isCreatingJob) || other.isCreatingJob == isCreatingJob)&&(identical(other.createJobFailed, createJobFailed) || other.createJobFailed == createJobFailed)&&(identical(other.activeJob, activeJob) || other.activeJob == activeJob)&&(identical(other.isConfirmingDelivery, isConfirmingDelivery) || other.isConfirmingDelivery == isConfirmingDelivery)&&(identical(other.confirmDeliveryFailed, confirmDeliveryFailed) || other.confirmDeliveryFailed == confirmDeliveryFailed));
}


@override
int get hashCode => Object.hash(runtimeType,pickupAddress,dropoffAddress,vehicleType,quote,isQuoting,quoteFailed,isCreatingJob,createJobFailed,activeJob,isConfirmingDelivery,confirmDeliveryFailed);

@override
String toString() {
  return 'RequestState(pickupAddress: $pickupAddress, dropoffAddress: $dropoffAddress, vehicleType: $vehicleType, quote: $quote, isQuoting: $isQuoting, quoteFailed: $quoteFailed, isCreatingJob: $isCreatingJob, createJobFailed: $createJobFailed, activeJob: $activeJob, isConfirmingDelivery: $isConfirmingDelivery, confirmDeliveryFailed: $confirmDeliveryFailed)';
}


}

/// @nodoc
abstract mixin class $RequestStateCopyWith<$Res>  {
  factory $RequestStateCopyWith(RequestState value, $Res Function(RequestState) _then) = _$RequestStateCopyWithImpl;
@useResult
$Res call({
 String pickupAddress, String dropoffAddress, VehicleType vehicleType, Quote? quote, bool isQuoting, bool quoteFailed, bool isCreatingJob, bool createJobFailed, Job? activeJob, bool isConfirmingDelivery, bool confirmDeliveryFailed
});


$QuoteCopyWith<$Res>? get quote;$JobCopyWith<$Res>? get activeJob;

}
/// @nodoc
class _$RequestStateCopyWithImpl<$Res>
    implements $RequestStateCopyWith<$Res> {
  _$RequestStateCopyWithImpl(this._self, this._then);

  final RequestState _self;
  final $Res Function(RequestState) _then;

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pickupAddress = null,Object? dropoffAddress = null,Object? vehicleType = null,Object? quote = freezed,Object? isQuoting = null,Object? quoteFailed = null,Object? isCreatingJob = null,Object? createJobFailed = null,Object? activeJob = freezed,Object? isConfirmingDelivery = null,Object? confirmDeliveryFailed = null,}) {
  return _then(_self.copyWith(
pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as Quote?,isQuoting: null == isQuoting ? _self.isQuoting : isQuoting // ignore: cast_nullable_to_non_nullable
as bool,quoteFailed: null == quoteFailed ? _self.quoteFailed : quoteFailed // ignore: cast_nullable_to_non_nullable
as bool,isCreatingJob: null == isCreatingJob ? _self.isCreatingJob : isCreatingJob // ignore: cast_nullable_to_non_nullable
as bool,createJobFailed: null == createJobFailed ? _self.createJobFailed : createJobFailed // ignore: cast_nullable_to_non_nullable
as bool,activeJob: freezed == activeJob ? _self.activeJob : activeJob // ignore: cast_nullable_to_non_nullable
as Job?,isConfirmingDelivery: null == isConfirmingDelivery ? _self.isConfirmingDelivery : isConfirmingDelivery // ignore: cast_nullable_to_non_nullable
as bool,confirmDeliveryFailed: null == confirmDeliveryFailed ? _self.confirmDeliveryFailed : confirmDeliveryFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}
/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteCopyWith<$Res>? get quote {
    if (_self.quote == null) {
    return null;
  }

  return $QuoteCopyWith<$Res>(_self.quote!, (value) {
    return _then(_self.copyWith(quote: value));
  });
}/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobCopyWith<$Res>? get activeJob {
    if (_self.activeJob == null) {
    return null;
  }

  return $JobCopyWith<$Res>(_self.activeJob!, (value) {
    return _then(_self.copyWith(activeJob: value));
  });
}
}


/// Adds pattern-matching-related methods to [RequestState].
extension RequestStatePatterns on RequestState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _RequestState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _RequestState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _RequestState value)  $default,){
final _that = this;
switch (_that) {
case _RequestState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _RequestState value)?  $default,){
final _that = this;
switch (_that) {
case _RequestState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String pickupAddress,  String dropoffAddress,  VehicleType vehicleType,  Quote? quote,  bool isQuoting,  bool quoteFailed,  bool isCreatingJob,  bool createJobFailed,  Job? activeJob,  bool isConfirmingDelivery,  bool confirmDeliveryFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RequestState() when $default != null:
return $default(_that.pickupAddress,_that.dropoffAddress,_that.vehicleType,_that.quote,_that.isQuoting,_that.quoteFailed,_that.isCreatingJob,_that.createJobFailed,_that.activeJob,_that.isConfirmingDelivery,_that.confirmDeliveryFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String pickupAddress,  String dropoffAddress,  VehicleType vehicleType,  Quote? quote,  bool isQuoting,  bool quoteFailed,  bool isCreatingJob,  bool createJobFailed,  Job? activeJob,  bool isConfirmingDelivery,  bool confirmDeliveryFailed)  $default,) {final _that = this;
switch (_that) {
case _RequestState():
return $default(_that.pickupAddress,_that.dropoffAddress,_that.vehicleType,_that.quote,_that.isQuoting,_that.quoteFailed,_that.isCreatingJob,_that.createJobFailed,_that.activeJob,_that.isConfirmingDelivery,_that.confirmDeliveryFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String pickupAddress,  String dropoffAddress,  VehicleType vehicleType,  Quote? quote,  bool isQuoting,  bool quoteFailed,  bool isCreatingJob,  bool createJobFailed,  Job? activeJob,  bool isConfirmingDelivery,  bool confirmDeliveryFailed)?  $default,) {final _that = this;
switch (_that) {
case _RequestState() when $default != null:
return $default(_that.pickupAddress,_that.dropoffAddress,_that.vehicleType,_that.quote,_that.isQuoting,_that.quoteFailed,_that.isCreatingJob,_that.createJobFailed,_that.activeJob,_that.isConfirmingDelivery,_that.confirmDeliveryFailed);case _:
  return null;

}
}

}

/// @nodoc


class _RequestState extends RequestState {
  const _RequestState({this.pickupAddress = '', this.dropoffAddress = '', this.vehicleType = VehicleType.car, this.quote, this.isQuoting = false, this.quoteFailed = false, this.isCreatingJob = false, this.createJobFailed = false, this.activeJob, this.isConfirmingDelivery = false, this.confirmDeliveryFailed = false}): super._();
  

@override@JsonKey() final  String pickupAddress;
@override@JsonKey() final  String dropoffAddress;
@override@JsonKey() final  VehicleType vehicleType;
@override final  Quote? quote;
@override@JsonKey() final  bool isQuoting;
@override@JsonKey() final  bool quoteFailed;
@override@JsonKey() final  bool isCreatingJob;
@override@JsonKey() final  bool createJobFailed;
@override final  Job? activeJob;
@override@JsonKey() final  bool isConfirmingDelivery;
@override@JsonKey() final  bool confirmDeliveryFailed;

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestStateCopyWith<_RequestState> get copyWith => __$RequestStateCopyWithImpl<_RequestState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestState&&(identical(other.pickupAddress, pickupAddress) || other.pickupAddress == pickupAddress)&&(identical(other.dropoffAddress, dropoffAddress) || other.dropoffAddress == dropoffAddress)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.isQuoting, isQuoting) || other.isQuoting == isQuoting)&&(identical(other.quoteFailed, quoteFailed) || other.quoteFailed == quoteFailed)&&(identical(other.isCreatingJob, isCreatingJob) || other.isCreatingJob == isCreatingJob)&&(identical(other.createJobFailed, createJobFailed) || other.createJobFailed == createJobFailed)&&(identical(other.activeJob, activeJob) || other.activeJob == activeJob)&&(identical(other.isConfirmingDelivery, isConfirmingDelivery) || other.isConfirmingDelivery == isConfirmingDelivery)&&(identical(other.confirmDeliveryFailed, confirmDeliveryFailed) || other.confirmDeliveryFailed == confirmDeliveryFailed));
}


@override
int get hashCode => Object.hash(runtimeType,pickupAddress,dropoffAddress,vehicleType,quote,isQuoting,quoteFailed,isCreatingJob,createJobFailed,activeJob,isConfirmingDelivery,confirmDeliveryFailed);

@override
String toString() {
  return 'RequestState(pickupAddress: $pickupAddress, dropoffAddress: $dropoffAddress, vehicleType: $vehicleType, quote: $quote, isQuoting: $isQuoting, quoteFailed: $quoteFailed, isCreatingJob: $isCreatingJob, createJobFailed: $createJobFailed, activeJob: $activeJob, isConfirmingDelivery: $isConfirmingDelivery, confirmDeliveryFailed: $confirmDeliveryFailed)';
}


}

/// @nodoc
abstract mixin class _$RequestStateCopyWith<$Res> implements $RequestStateCopyWith<$Res> {
  factory _$RequestStateCopyWith(_RequestState value, $Res Function(_RequestState) _then) = __$RequestStateCopyWithImpl;
@override @useResult
$Res call({
 String pickupAddress, String dropoffAddress, VehicleType vehicleType, Quote? quote, bool isQuoting, bool quoteFailed, bool isCreatingJob, bool createJobFailed, Job? activeJob, bool isConfirmingDelivery, bool confirmDeliveryFailed
});


@override $QuoteCopyWith<$Res>? get quote;@override $JobCopyWith<$Res>? get activeJob;

}
/// @nodoc
class __$RequestStateCopyWithImpl<$Res>
    implements _$RequestStateCopyWith<$Res> {
  __$RequestStateCopyWithImpl(this._self, this._then);

  final _RequestState _self;
  final $Res Function(_RequestState) _then;

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pickupAddress = null,Object? dropoffAddress = null,Object? vehicleType = null,Object? quote = freezed,Object? isQuoting = null,Object? quoteFailed = null,Object? isCreatingJob = null,Object? createJobFailed = null,Object? activeJob = freezed,Object? isConfirmingDelivery = null,Object? confirmDeliveryFailed = null,}) {
  return _then(_RequestState(
pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as Quote?,isQuoting: null == isQuoting ? _self.isQuoting : isQuoting // ignore: cast_nullable_to_non_nullable
as bool,quoteFailed: null == quoteFailed ? _self.quoteFailed : quoteFailed // ignore: cast_nullable_to_non_nullable
as bool,isCreatingJob: null == isCreatingJob ? _self.isCreatingJob : isCreatingJob // ignore: cast_nullable_to_non_nullable
as bool,createJobFailed: null == createJobFailed ? _self.createJobFailed : createJobFailed // ignore: cast_nullable_to_non_nullable
as bool,activeJob: freezed == activeJob ? _self.activeJob : activeJob // ignore: cast_nullable_to_non_nullable
as Job?,isConfirmingDelivery: null == isConfirmingDelivery ? _self.isConfirmingDelivery : isConfirmingDelivery // ignore: cast_nullable_to_non_nullable
as bool,confirmDeliveryFailed: null == confirmDeliveryFailed ? _self.confirmDeliveryFailed : confirmDeliveryFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$QuoteCopyWith<$Res>? get quote {
    if (_self.quote == null) {
    return null;
  }

  return $QuoteCopyWith<$Res>(_self.quote!, (value) {
    return _then(_self.copyWith(quote: value));
  });
}/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobCopyWith<$Res>? get activeJob {
    if (_self.activeJob == null) {
    return null;
  }

  return $JobCopyWith<$Res>(_self.activeJob!, (value) {
    return _then(_self.copyWith(activeJob: value));
  });
}
}

// dart format on
