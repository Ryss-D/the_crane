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

 String get pickupAddress; String get dropoffAddress;// FND-6: real coordinates once resolved via Places search or pin-drag.
// Null means "no real fix yet for whatever's currently in the matching
// *Address field" — `fakeGeocode` stands in for that address text until
// a real one arrives, same "explicit coords win, typed text falls back
// to fakeGeocode" contract the web client already ships
// (`RequestPage.tsx`'s `pickupCoords`).
 LatLng? get pickupLatLng; LatLng? get dropoffLatLng; VehicleType get vehicleType; Quote? get quote; bool get isQuoting; bool get quoteFailed; bool get isCreatingJob; bool get createJobFailed; Job? get activeJob; bool get isConfirmingDelivery; bool get confirmDeliveryFailed;// PAY-4: the backend's own rejection detail (e.g. "Digital fares are
// not enabled") when confirmDelivery's failure was a typed
// JobStatusRejectedException — null for any other failure (network,
// etc.), which still just flips confirmDeliveryFailed with no message
// of its own, same as before this field existed.
 String? get confirmDeliveryErrorMessage;// FND-6/CUS-4: the assigned driver's live position, from the WS
// `driver_location` push (`ServerMessage.driverLocation`) — was already
// parsed but never consumed anywhere before this. Null under fakes (no
// socket) and until the first push for the active job arrives.
 LatLng? get driverPosition;
/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$RequestStateCopyWith<RequestState> get copyWith => _$RequestStateCopyWithImpl<RequestState>(this as RequestState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is RequestState&&(identical(other.pickupAddress, pickupAddress) || other.pickupAddress == pickupAddress)&&(identical(other.dropoffAddress, dropoffAddress) || other.dropoffAddress == dropoffAddress)&&(identical(other.pickupLatLng, pickupLatLng) || other.pickupLatLng == pickupLatLng)&&(identical(other.dropoffLatLng, dropoffLatLng) || other.dropoffLatLng == dropoffLatLng)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.isQuoting, isQuoting) || other.isQuoting == isQuoting)&&(identical(other.quoteFailed, quoteFailed) || other.quoteFailed == quoteFailed)&&(identical(other.isCreatingJob, isCreatingJob) || other.isCreatingJob == isCreatingJob)&&(identical(other.createJobFailed, createJobFailed) || other.createJobFailed == createJobFailed)&&(identical(other.activeJob, activeJob) || other.activeJob == activeJob)&&(identical(other.isConfirmingDelivery, isConfirmingDelivery) || other.isConfirmingDelivery == isConfirmingDelivery)&&(identical(other.confirmDeliveryFailed, confirmDeliveryFailed) || other.confirmDeliveryFailed == confirmDeliveryFailed)&&(identical(other.confirmDeliveryErrorMessage, confirmDeliveryErrorMessage) || other.confirmDeliveryErrorMessage == confirmDeliveryErrorMessage)&&(identical(other.driverPosition, driverPosition) || other.driverPosition == driverPosition));
}


@override
int get hashCode => Object.hash(runtimeType,pickupAddress,dropoffAddress,pickupLatLng,dropoffLatLng,vehicleType,quote,isQuoting,quoteFailed,isCreatingJob,createJobFailed,activeJob,isConfirmingDelivery,confirmDeliveryFailed,confirmDeliveryErrorMessage,driverPosition);

@override
String toString() {
  return 'RequestState(pickupAddress: $pickupAddress, dropoffAddress: $dropoffAddress, pickupLatLng: $pickupLatLng, dropoffLatLng: $dropoffLatLng, vehicleType: $vehicleType, quote: $quote, isQuoting: $isQuoting, quoteFailed: $quoteFailed, isCreatingJob: $isCreatingJob, createJobFailed: $createJobFailed, activeJob: $activeJob, isConfirmingDelivery: $isConfirmingDelivery, confirmDeliveryFailed: $confirmDeliveryFailed, confirmDeliveryErrorMessage: $confirmDeliveryErrorMessage, driverPosition: $driverPosition)';
}


}

/// @nodoc
abstract mixin class $RequestStateCopyWith<$Res>  {
  factory $RequestStateCopyWith(RequestState value, $Res Function(RequestState) _then) = _$RequestStateCopyWithImpl;
@useResult
$Res call({
 String pickupAddress, String dropoffAddress, LatLng? pickupLatLng, LatLng? dropoffLatLng, VehicleType vehicleType, Quote? quote, bool isQuoting, bool quoteFailed, bool isCreatingJob, bool createJobFailed, Job? activeJob, bool isConfirmingDelivery, bool confirmDeliveryFailed, String? confirmDeliveryErrorMessage, LatLng? driverPosition
});


$LatLngCopyWith<$Res>? get pickupLatLng;$LatLngCopyWith<$Res>? get dropoffLatLng;$QuoteCopyWith<$Res>? get quote;$JobCopyWith<$Res>? get activeJob;$LatLngCopyWith<$Res>? get driverPosition;

}
/// @nodoc
class _$RequestStateCopyWithImpl<$Res>
    implements $RequestStateCopyWith<$Res> {
  _$RequestStateCopyWithImpl(this._self, this._then);

  final RequestState _self;
  final $Res Function(RequestState) _then;

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pickupAddress = null,Object? dropoffAddress = null,Object? pickupLatLng = freezed,Object? dropoffLatLng = freezed,Object? vehicleType = null,Object? quote = freezed,Object? isQuoting = null,Object? quoteFailed = null,Object? isCreatingJob = null,Object? createJobFailed = null,Object? activeJob = freezed,Object? isConfirmingDelivery = null,Object? confirmDeliveryFailed = null,Object? confirmDeliveryErrorMessage = freezed,Object? driverPosition = freezed,}) {
  return _then(_self.copyWith(
pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,pickupLatLng: freezed == pickupLatLng ? _self.pickupLatLng : pickupLatLng // ignore: cast_nullable_to_non_nullable
as LatLng?,dropoffLatLng: freezed == dropoffLatLng ? _self.dropoffLatLng : dropoffLatLng // ignore: cast_nullable_to_non_nullable
as LatLng?,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as Quote?,isQuoting: null == isQuoting ? _self.isQuoting : isQuoting // ignore: cast_nullable_to_non_nullable
as bool,quoteFailed: null == quoteFailed ? _self.quoteFailed : quoteFailed // ignore: cast_nullable_to_non_nullable
as bool,isCreatingJob: null == isCreatingJob ? _self.isCreatingJob : isCreatingJob // ignore: cast_nullable_to_non_nullable
as bool,createJobFailed: null == createJobFailed ? _self.createJobFailed : createJobFailed // ignore: cast_nullable_to_non_nullable
as bool,activeJob: freezed == activeJob ? _self.activeJob : activeJob // ignore: cast_nullable_to_non_nullable
as Job?,isConfirmingDelivery: null == isConfirmingDelivery ? _self.isConfirmingDelivery : isConfirmingDelivery // ignore: cast_nullable_to_non_nullable
as bool,confirmDeliveryFailed: null == confirmDeliveryFailed ? _self.confirmDeliveryFailed : confirmDeliveryFailed // ignore: cast_nullable_to_non_nullable
as bool,confirmDeliveryErrorMessage: freezed == confirmDeliveryErrorMessage ? _self.confirmDeliveryErrorMessage : confirmDeliveryErrorMessage // ignore: cast_nullable_to_non_nullable
as String?,driverPosition: freezed == driverPosition ? _self.driverPosition : driverPosition // ignore: cast_nullable_to_non_nullable
as LatLng?,
  ));
}
/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res>? get pickupLatLng {
    if (_self.pickupLatLng == null) {
    return null;
  }

  return $LatLngCopyWith<$Res>(_self.pickupLatLng!, (value) {
    return _then(_self.copyWith(pickupLatLng: value));
  });
}/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res>? get dropoffLatLng {
    if (_self.dropoffLatLng == null) {
    return null;
  }

  return $LatLngCopyWith<$Res>(_self.dropoffLatLng!, (value) {
    return _then(_self.copyWith(dropoffLatLng: value));
  });
}/// Create a copy of RequestState
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
}/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res>? get driverPosition {
    if (_self.driverPosition == null) {
    return null;
  }

  return $LatLngCopyWith<$Res>(_self.driverPosition!, (value) {
    return _then(_self.copyWith(driverPosition: value));
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String pickupAddress,  String dropoffAddress,  LatLng? pickupLatLng,  LatLng? dropoffLatLng,  VehicleType vehicleType,  Quote? quote,  bool isQuoting,  bool quoteFailed,  bool isCreatingJob,  bool createJobFailed,  Job? activeJob,  bool isConfirmingDelivery,  bool confirmDeliveryFailed,  String? confirmDeliveryErrorMessage,  LatLng? driverPosition)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _RequestState() when $default != null:
return $default(_that.pickupAddress,_that.dropoffAddress,_that.pickupLatLng,_that.dropoffLatLng,_that.vehicleType,_that.quote,_that.isQuoting,_that.quoteFailed,_that.isCreatingJob,_that.createJobFailed,_that.activeJob,_that.isConfirmingDelivery,_that.confirmDeliveryFailed,_that.confirmDeliveryErrorMessage,_that.driverPosition);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String pickupAddress,  String dropoffAddress,  LatLng? pickupLatLng,  LatLng? dropoffLatLng,  VehicleType vehicleType,  Quote? quote,  bool isQuoting,  bool quoteFailed,  bool isCreatingJob,  bool createJobFailed,  Job? activeJob,  bool isConfirmingDelivery,  bool confirmDeliveryFailed,  String? confirmDeliveryErrorMessage,  LatLng? driverPosition)  $default,) {final _that = this;
switch (_that) {
case _RequestState():
return $default(_that.pickupAddress,_that.dropoffAddress,_that.pickupLatLng,_that.dropoffLatLng,_that.vehicleType,_that.quote,_that.isQuoting,_that.quoteFailed,_that.isCreatingJob,_that.createJobFailed,_that.activeJob,_that.isConfirmingDelivery,_that.confirmDeliveryFailed,_that.confirmDeliveryErrorMessage,_that.driverPosition);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String pickupAddress,  String dropoffAddress,  LatLng? pickupLatLng,  LatLng? dropoffLatLng,  VehicleType vehicleType,  Quote? quote,  bool isQuoting,  bool quoteFailed,  bool isCreatingJob,  bool createJobFailed,  Job? activeJob,  bool isConfirmingDelivery,  bool confirmDeliveryFailed,  String? confirmDeliveryErrorMessage,  LatLng? driverPosition)?  $default,) {final _that = this;
switch (_that) {
case _RequestState() when $default != null:
return $default(_that.pickupAddress,_that.dropoffAddress,_that.pickupLatLng,_that.dropoffLatLng,_that.vehicleType,_that.quote,_that.isQuoting,_that.quoteFailed,_that.isCreatingJob,_that.createJobFailed,_that.activeJob,_that.isConfirmingDelivery,_that.confirmDeliveryFailed,_that.confirmDeliveryErrorMessage,_that.driverPosition);case _:
  return null;

}
}

}

/// @nodoc


class _RequestState extends RequestState {
  const _RequestState({this.pickupAddress = '', this.dropoffAddress = '', this.pickupLatLng, this.dropoffLatLng, this.vehicleType = VehicleType.car, this.quote, this.isQuoting = false, this.quoteFailed = false, this.isCreatingJob = false, this.createJobFailed = false, this.activeJob, this.isConfirmingDelivery = false, this.confirmDeliveryFailed = false, this.confirmDeliveryErrorMessage, this.driverPosition}): super._();
  

@override@JsonKey() final  String pickupAddress;
@override@JsonKey() final  String dropoffAddress;
// FND-6: real coordinates once resolved via Places search or pin-drag.
// Null means "no real fix yet for whatever's currently in the matching
// *Address field" — `fakeGeocode` stands in for that address text until
// a real one arrives, same "explicit coords win, typed text falls back
// to fakeGeocode" contract the web client already ships
// (`RequestPage.tsx`'s `pickupCoords`).
@override final  LatLng? pickupLatLng;
@override final  LatLng? dropoffLatLng;
@override@JsonKey() final  VehicleType vehicleType;
@override final  Quote? quote;
@override@JsonKey() final  bool isQuoting;
@override@JsonKey() final  bool quoteFailed;
@override@JsonKey() final  bool isCreatingJob;
@override@JsonKey() final  bool createJobFailed;
@override final  Job? activeJob;
@override@JsonKey() final  bool isConfirmingDelivery;
@override@JsonKey() final  bool confirmDeliveryFailed;
// PAY-4: the backend's own rejection detail (e.g. "Digital fares are
// not enabled") when confirmDelivery's failure was a typed
// JobStatusRejectedException — null for any other failure (network,
// etc.), which still just flips confirmDeliveryFailed with no message
// of its own, same as before this field existed.
@override final  String? confirmDeliveryErrorMessage;
// FND-6/CUS-4: the assigned driver's live position, from the WS
// `driver_location` push (`ServerMessage.driverLocation`) — was already
// parsed but never consumed anywhere before this. Null under fakes (no
// socket) and until the first push for the active job arrives.
@override final  LatLng? driverPosition;

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$RequestStateCopyWith<_RequestState> get copyWith => __$RequestStateCopyWithImpl<_RequestState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _RequestState&&(identical(other.pickupAddress, pickupAddress) || other.pickupAddress == pickupAddress)&&(identical(other.dropoffAddress, dropoffAddress) || other.dropoffAddress == dropoffAddress)&&(identical(other.pickupLatLng, pickupLatLng) || other.pickupLatLng == pickupLatLng)&&(identical(other.dropoffLatLng, dropoffLatLng) || other.dropoffLatLng == dropoffLatLng)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.quote, quote) || other.quote == quote)&&(identical(other.isQuoting, isQuoting) || other.isQuoting == isQuoting)&&(identical(other.quoteFailed, quoteFailed) || other.quoteFailed == quoteFailed)&&(identical(other.isCreatingJob, isCreatingJob) || other.isCreatingJob == isCreatingJob)&&(identical(other.createJobFailed, createJobFailed) || other.createJobFailed == createJobFailed)&&(identical(other.activeJob, activeJob) || other.activeJob == activeJob)&&(identical(other.isConfirmingDelivery, isConfirmingDelivery) || other.isConfirmingDelivery == isConfirmingDelivery)&&(identical(other.confirmDeliveryFailed, confirmDeliveryFailed) || other.confirmDeliveryFailed == confirmDeliveryFailed)&&(identical(other.confirmDeliveryErrorMessage, confirmDeliveryErrorMessage) || other.confirmDeliveryErrorMessage == confirmDeliveryErrorMessage)&&(identical(other.driverPosition, driverPosition) || other.driverPosition == driverPosition));
}


@override
int get hashCode => Object.hash(runtimeType,pickupAddress,dropoffAddress,pickupLatLng,dropoffLatLng,vehicleType,quote,isQuoting,quoteFailed,isCreatingJob,createJobFailed,activeJob,isConfirmingDelivery,confirmDeliveryFailed,confirmDeliveryErrorMessage,driverPosition);

@override
String toString() {
  return 'RequestState(pickupAddress: $pickupAddress, dropoffAddress: $dropoffAddress, pickupLatLng: $pickupLatLng, dropoffLatLng: $dropoffLatLng, vehicleType: $vehicleType, quote: $quote, isQuoting: $isQuoting, quoteFailed: $quoteFailed, isCreatingJob: $isCreatingJob, createJobFailed: $createJobFailed, activeJob: $activeJob, isConfirmingDelivery: $isConfirmingDelivery, confirmDeliveryFailed: $confirmDeliveryFailed, confirmDeliveryErrorMessage: $confirmDeliveryErrorMessage, driverPosition: $driverPosition)';
}


}

/// @nodoc
abstract mixin class _$RequestStateCopyWith<$Res> implements $RequestStateCopyWith<$Res> {
  factory _$RequestStateCopyWith(_RequestState value, $Res Function(_RequestState) _then) = __$RequestStateCopyWithImpl;
@override @useResult
$Res call({
 String pickupAddress, String dropoffAddress, LatLng? pickupLatLng, LatLng? dropoffLatLng, VehicleType vehicleType, Quote? quote, bool isQuoting, bool quoteFailed, bool isCreatingJob, bool createJobFailed, Job? activeJob, bool isConfirmingDelivery, bool confirmDeliveryFailed, String? confirmDeliveryErrorMessage, LatLng? driverPosition
});


@override $LatLngCopyWith<$Res>? get pickupLatLng;@override $LatLngCopyWith<$Res>? get dropoffLatLng;@override $QuoteCopyWith<$Res>? get quote;@override $JobCopyWith<$Res>? get activeJob;@override $LatLngCopyWith<$Res>? get driverPosition;

}
/// @nodoc
class __$RequestStateCopyWithImpl<$Res>
    implements _$RequestStateCopyWith<$Res> {
  __$RequestStateCopyWithImpl(this._self, this._then);

  final _RequestState _self;
  final $Res Function(_RequestState) _then;

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pickupAddress = null,Object? dropoffAddress = null,Object? pickupLatLng = freezed,Object? dropoffLatLng = freezed,Object? vehicleType = null,Object? quote = freezed,Object? isQuoting = null,Object? quoteFailed = null,Object? isCreatingJob = null,Object? createJobFailed = null,Object? activeJob = freezed,Object? isConfirmingDelivery = null,Object? confirmDeliveryFailed = null,Object? confirmDeliveryErrorMessage = freezed,Object? driverPosition = freezed,}) {
  return _then(_RequestState(
pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,pickupLatLng: freezed == pickupLatLng ? _self.pickupLatLng : pickupLatLng // ignore: cast_nullable_to_non_nullable
as LatLng?,dropoffLatLng: freezed == dropoffLatLng ? _self.dropoffLatLng : dropoffLatLng // ignore: cast_nullable_to_non_nullable
as LatLng?,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,quote: freezed == quote ? _self.quote : quote // ignore: cast_nullable_to_non_nullable
as Quote?,isQuoting: null == isQuoting ? _self.isQuoting : isQuoting // ignore: cast_nullable_to_non_nullable
as bool,quoteFailed: null == quoteFailed ? _self.quoteFailed : quoteFailed // ignore: cast_nullable_to_non_nullable
as bool,isCreatingJob: null == isCreatingJob ? _self.isCreatingJob : isCreatingJob // ignore: cast_nullable_to_non_nullable
as bool,createJobFailed: null == createJobFailed ? _self.createJobFailed : createJobFailed // ignore: cast_nullable_to_non_nullable
as bool,activeJob: freezed == activeJob ? _self.activeJob : activeJob // ignore: cast_nullable_to_non_nullable
as Job?,isConfirmingDelivery: null == isConfirmingDelivery ? _self.isConfirmingDelivery : isConfirmingDelivery // ignore: cast_nullable_to_non_nullable
as bool,confirmDeliveryFailed: null == confirmDeliveryFailed ? _self.confirmDeliveryFailed : confirmDeliveryFailed // ignore: cast_nullable_to_non_nullable
as bool,confirmDeliveryErrorMessage: freezed == confirmDeliveryErrorMessage ? _self.confirmDeliveryErrorMessage : confirmDeliveryErrorMessage // ignore: cast_nullable_to_non_nullable
as String?,driverPosition: freezed == driverPosition ? _self.driverPosition : driverPosition // ignore: cast_nullable_to_non_nullable
as LatLng?,
  ));
}

/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res>? get pickupLatLng {
    if (_self.pickupLatLng == null) {
    return null;
  }

  return $LatLngCopyWith<$Res>(_self.pickupLatLng!, (value) {
    return _then(_self.copyWith(pickupLatLng: value));
  });
}/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res>? get dropoffLatLng {
    if (_self.dropoffLatLng == null) {
    return null;
  }

  return $LatLngCopyWith<$Res>(_self.dropoffLatLng!, (value) {
    return _then(_self.copyWith(dropoffLatLng: value));
  });
}/// Create a copy of RequestState
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
}/// Create a copy of RequestState
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res>? get driverPosition {
    if (_self.driverPosition == null) {
    return null;
  }

  return $LatLngCopyWith<$Res>(_self.driverPosition!, (value) {
    return _then(_self.copyWith(driverPosition: value));
  });
}
}

// dart format on
