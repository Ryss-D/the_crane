// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'server_message.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServerMessage {





@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessage);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ServerMessage()';
}


}

/// @nodoc
class $ServerMessageCopyWith<$Res>  {
$ServerMessageCopyWith(ServerMessage _, $Res Function(ServerMessage) __);
}


/// Adds pattern-matching-related methods to [ServerMessage].
extension ServerMessagePatterns on ServerMessage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>({TResult Function( ServerMessageSubscribed value)?  subscribed,TResult Function( ServerMessageUnsubscribed value)?  unsubscribed,TResult Function( ServerMessageJobEvent value)?  jobEvent,TResult Function( ServerMessageDriverLocation value)?  driverLocation,TResult Function( ServerMessageJobOffer value)?  jobOffer,TResult Function( ServerMessageError value)?  error,TResult Function( ServerMessagePing value)?  ping,TResult Function( ServerMessageUnknown value)?  unknown,required TResult orElse(),}){
final _that = this;
switch (_that) {
case ServerMessageSubscribed() when subscribed != null:
return subscribed(_that);case ServerMessageUnsubscribed() when unsubscribed != null:
return unsubscribed(_that);case ServerMessageJobEvent() when jobEvent != null:
return jobEvent(_that);case ServerMessageDriverLocation() when driverLocation != null:
return driverLocation(_that);case ServerMessageJobOffer() when jobOffer != null:
return jobOffer(_that);case ServerMessageError() when error != null:
return error(_that);case ServerMessagePing() when ping != null:
return ping(_that);case ServerMessageUnknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult map<TResult extends Object?>({required TResult Function( ServerMessageSubscribed value)  subscribed,required TResult Function( ServerMessageUnsubscribed value)  unsubscribed,required TResult Function( ServerMessageJobEvent value)  jobEvent,required TResult Function( ServerMessageDriverLocation value)  driverLocation,required TResult Function( ServerMessageJobOffer value)  jobOffer,required TResult Function( ServerMessageError value)  error,required TResult Function( ServerMessagePing value)  ping,required TResult Function( ServerMessageUnknown value)  unknown,}){
final _that = this;
switch (_that) {
case ServerMessageSubscribed():
return subscribed(_that);case ServerMessageUnsubscribed():
return unsubscribed(_that);case ServerMessageJobEvent():
return jobEvent(_that);case ServerMessageDriverLocation():
return driverLocation(_that);case ServerMessageJobOffer():
return jobOffer(_that);case ServerMessageError():
return error(_that);case ServerMessagePing():
return ping(_that);case ServerMessageUnknown():
return unknown(_that);}
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>({TResult? Function( ServerMessageSubscribed value)?  subscribed,TResult? Function( ServerMessageUnsubscribed value)?  unsubscribed,TResult? Function( ServerMessageJobEvent value)?  jobEvent,TResult? Function( ServerMessageDriverLocation value)?  driverLocation,TResult? Function( ServerMessageJobOffer value)?  jobOffer,TResult? Function( ServerMessageError value)?  error,TResult? Function( ServerMessagePing value)?  ping,TResult? Function( ServerMessageUnknown value)?  unknown,}){
final _that = this;
switch (_that) {
case ServerMessageSubscribed() when subscribed != null:
return subscribed(_that);case ServerMessageUnsubscribed() when unsubscribed != null:
return unsubscribed(_that);case ServerMessageJobEvent() when jobEvent != null:
return jobEvent(_that);case ServerMessageDriverLocation() when driverLocation != null:
return driverLocation(_that);case ServerMessageJobOffer() when jobOffer != null:
return jobOffer(_that);case ServerMessageError() when error != null:
return error(_that);case ServerMessagePing() when ping != null:
return ping(_that);case ServerMessageUnknown() when unknown != null:
return unknown(_that);case _:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>({TResult Function( String jobId)?  subscribed,TResult Function( String jobId)?  unsubscribed,TResult Function( String jobId,  String status)?  jobEvent,TResult Function( String jobId,  double lat,  double lng)?  driverLocation,TResult Function( String jobId,  String offerId,  VehicleType vehicleType,  LatLng pickup,  LatLng dropoff,  int? quotedPrice,  int expiresInSeconds,  double? pickupDistanceKm,  int? commissionAmount)?  jobOffer,TResult Function( String detail)?  error,TResult Function()?  ping,TResult Function( Map<String, dynamic> raw)?  unknown,required TResult orElse(),}) {final _that = this;
switch (_that) {
case ServerMessageSubscribed() when subscribed != null:
return subscribed(_that.jobId);case ServerMessageUnsubscribed() when unsubscribed != null:
return unsubscribed(_that.jobId);case ServerMessageJobEvent() when jobEvent != null:
return jobEvent(_that.jobId,_that.status);case ServerMessageDriverLocation() when driverLocation != null:
return driverLocation(_that.jobId,_that.lat,_that.lng);case ServerMessageJobOffer() when jobOffer != null:
return jobOffer(_that.jobId,_that.offerId,_that.vehicleType,_that.pickup,_that.dropoff,_that.quotedPrice,_that.expiresInSeconds,_that.pickupDistanceKm,_that.commissionAmount);case ServerMessageError() when error != null:
return error(_that.detail);case ServerMessagePing() when ping != null:
return ping();case ServerMessageUnknown() when unknown != null:
return unknown(_that.raw);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>({required TResult Function( String jobId)  subscribed,required TResult Function( String jobId)  unsubscribed,required TResult Function( String jobId,  String status)  jobEvent,required TResult Function( String jobId,  double lat,  double lng)  driverLocation,required TResult Function( String jobId,  String offerId,  VehicleType vehicleType,  LatLng pickup,  LatLng dropoff,  int? quotedPrice,  int expiresInSeconds,  double? pickupDistanceKm,  int? commissionAmount)  jobOffer,required TResult Function( String detail)  error,required TResult Function()  ping,required TResult Function( Map<String, dynamic> raw)  unknown,}) {final _that = this;
switch (_that) {
case ServerMessageSubscribed():
return subscribed(_that.jobId);case ServerMessageUnsubscribed():
return unsubscribed(_that.jobId);case ServerMessageJobEvent():
return jobEvent(_that.jobId,_that.status);case ServerMessageDriverLocation():
return driverLocation(_that.jobId,_that.lat,_that.lng);case ServerMessageJobOffer():
return jobOffer(_that.jobId,_that.offerId,_that.vehicleType,_that.pickup,_that.dropoff,_that.quotedPrice,_that.expiresInSeconds,_that.pickupDistanceKm,_that.commissionAmount);case ServerMessageError():
return error(_that.detail);case ServerMessagePing():
return ping();case ServerMessageUnknown():
return unknown(_that.raw);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>({TResult? Function( String jobId)?  subscribed,TResult? Function( String jobId)?  unsubscribed,TResult? Function( String jobId,  String status)?  jobEvent,TResult? Function( String jobId,  double lat,  double lng)?  driverLocation,TResult? Function( String jobId,  String offerId,  VehicleType vehicleType,  LatLng pickup,  LatLng dropoff,  int? quotedPrice,  int expiresInSeconds,  double? pickupDistanceKm,  int? commissionAmount)?  jobOffer,TResult? Function( String detail)?  error,TResult? Function()?  ping,TResult? Function( Map<String, dynamic> raw)?  unknown,}) {final _that = this;
switch (_that) {
case ServerMessageSubscribed() when subscribed != null:
return subscribed(_that.jobId);case ServerMessageUnsubscribed() when unsubscribed != null:
return unsubscribed(_that.jobId);case ServerMessageJobEvent() when jobEvent != null:
return jobEvent(_that.jobId,_that.status);case ServerMessageDriverLocation() when driverLocation != null:
return driverLocation(_that.jobId,_that.lat,_that.lng);case ServerMessageJobOffer() when jobOffer != null:
return jobOffer(_that.jobId,_that.offerId,_that.vehicleType,_that.pickup,_that.dropoff,_that.quotedPrice,_that.expiresInSeconds,_that.pickupDistanceKm,_that.commissionAmount);case ServerMessageError() when error != null:
return error(_that.detail);case ServerMessagePing() when ping != null:
return ping();case ServerMessageUnknown() when unknown != null:
return unknown(_that.raw);case _:
  return null;

}
}

}

/// @nodoc


class ServerMessageSubscribed implements ServerMessage {
  const ServerMessageSubscribed({required this.jobId});
  

 final  String jobId;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessageSubscribedCopyWith<ServerMessageSubscribed> get copyWith => _$ServerMessageSubscribedCopyWithImpl<ServerMessageSubscribed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessageSubscribed&&(identical(other.jobId, jobId) || other.jobId == jobId));
}


@override
int get hashCode => Object.hash(runtimeType,jobId);

@override
String toString() {
  return 'ServerMessage.subscribed(jobId: $jobId)';
}


}

/// @nodoc
abstract mixin class $ServerMessageSubscribedCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessageSubscribedCopyWith(ServerMessageSubscribed value, $Res Function(ServerMessageSubscribed) _then) = _$ServerMessageSubscribedCopyWithImpl;
@useResult
$Res call({
 String jobId
});




}
/// @nodoc
class _$ServerMessageSubscribedCopyWithImpl<$Res>
    implements $ServerMessageSubscribedCopyWith<$Res> {
  _$ServerMessageSubscribedCopyWithImpl(this._self, this._then);

  final ServerMessageSubscribed _self;
  final $Res Function(ServerMessageSubscribed) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? jobId = null,}) {
  return _then(ServerMessageSubscribed(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ServerMessageUnsubscribed implements ServerMessage {
  const ServerMessageUnsubscribed({required this.jobId});
  

 final  String jobId;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessageUnsubscribedCopyWith<ServerMessageUnsubscribed> get copyWith => _$ServerMessageUnsubscribedCopyWithImpl<ServerMessageUnsubscribed>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessageUnsubscribed&&(identical(other.jobId, jobId) || other.jobId == jobId));
}


@override
int get hashCode => Object.hash(runtimeType,jobId);

@override
String toString() {
  return 'ServerMessage.unsubscribed(jobId: $jobId)';
}


}

/// @nodoc
abstract mixin class $ServerMessageUnsubscribedCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessageUnsubscribedCopyWith(ServerMessageUnsubscribed value, $Res Function(ServerMessageUnsubscribed) _then) = _$ServerMessageUnsubscribedCopyWithImpl;
@useResult
$Res call({
 String jobId
});




}
/// @nodoc
class _$ServerMessageUnsubscribedCopyWithImpl<$Res>
    implements $ServerMessageUnsubscribedCopyWith<$Res> {
  _$ServerMessageUnsubscribedCopyWithImpl(this._self, this._then);

  final ServerMessageUnsubscribed _self;
  final $Res Function(ServerMessageUnsubscribed) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? jobId = null,}) {
  return _then(ServerMessageUnsubscribed(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ServerMessageJobEvent implements ServerMessage {
  const ServerMessageJobEvent({required this.jobId, required this.status});
  

 final  String jobId;
 final  String status;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessageJobEventCopyWith<ServerMessageJobEvent> get copyWith => _$ServerMessageJobEventCopyWithImpl<ServerMessageJobEvent>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessageJobEvent&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.status, status) || other.status == status));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,status);

@override
String toString() {
  return 'ServerMessage.jobEvent(jobId: $jobId, status: $status)';
}


}

/// @nodoc
abstract mixin class $ServerMessageJobEventCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessageJobEventCopyWith(ServerMessageJobEvent value, $Res Function(ServerMessageJobEvent) _then) = _$ServerMessageJobEventCopyWithImpl;
@useResult
$Res call({
 String jobId, String status
});




}
/// @nodoc
class _$ServerMessageJobEventCopyWithImpl<$Res>
    implements $ServerMessageJobEventCopyWith<$Res> {
  _$ServerMessageJobEventCopyWithImpl(this._self, this._then);

  final ServerMessageJobEvent _self;
  final $Res Function(ServerMessageJobEvent) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? status = null,}) {
  return _then(ServerMessageJobEvent(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ServerMessageDriverLocation implements ServerMessage {
  const ServerMessageDriverLocation({required this.jobId, required this.lat, required this.lng});
  

 final  String jobId;
 final  double lat;
 final  double lng;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessageDriverLocationCopyWith<ServerMessageDriverLocation> get copyWith => _$ServerMessageDriverLocationCopyWithImpl<ServerMessageDriverLocation>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessageDriverLocation&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.lat, lat) || other.lat == lat)&&(identical(other.lng, lng) || other.lng == lng));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,lat,lng);

@override
String toString() {
  return 'ServerMessage.driverLocation(jobId: $jobId, lat: $lat, lng: $lng)';
}


}

/// @nodoc
abstract mixin class $ServerMessageDriverLocationCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessageDriverLocationCopyWith(ServerMessageDriverLocation value, $Res Function(ServerMessageDriverLocation) _then) = _$ServerMessageDriverLocationCopyWithImpl;
@useResult
$Res call({
 String jobId, double lat, double lng
});




}
/// @nodoc
class _$ServerMessageDriverLocationCopyWithImpl<$Res>
    implements $ServerMessageDriverLocationCopyWith<$Res> {
  _$ServerMessageDriverLocationCopyWithImpl(this._self, this._then);

  final ServerMessageDriverLocation _self;
  final $Res Function(ServerMessageDriverLocation) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? lat = null,Object? lng = null,}) {
  return _then(ServerMessageDriverLocation(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,lat: null == lat ? _self.lat : lat // ignore: cast_nullable_to_non_nullable
as double,lng: null == lng ? _self.lng : lng // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

/// @nodoc


class ServerMessageJobOffer implements ServerMessage {
  const ServerMessageJobOffer({required this.jobId, required this.offerId, required this.vehicleType, required this.pickup, required this.dropoff, this.quotedPrice, required this.expiresInSeconds, this.pickupDistanceKm, this.commissionAmount});
  

 final  String jobId;
 final  String offerId;
 final  VehicleType vehicleType;
 final  LatLng pickup;
 final  LatLng dropoff;
 final  int? quotedPrice;
 final  int expiresInSeconds;
 final  double? pickupDistanceKm;
 final  int? commissionAmount;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessageJobOfferCopyWith<ServerMessageJobOffer> get copyWith => _$ServerMessageJobOfferCopyWithImpl<ServerMessageJobOffer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessageJobOffer&&(identical(other.jobId, jobId) || other.jobId == jobId)&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.pickup, pickup) || other.pickup == pickup)&&(identical(other.dropoff, dropoff) || other.dropoff == dropoff)&&(identical(other.quotedPrice, quotedPrice) || other.quotedPrice == quotedPrice)&&(identical(other.expiresInSeconds, expiresInSeconds) || other.expiresInSeconds == expiresInSeconds)&&(identical(other.pickupDistanceKm, pickupDistanceKm) || other.pickupDistanceKm == pickupDistanceKm)&&(identical(other.commissionAmount, commissionAmount) || other.commissionAmount == commissionAmount));
}


@override
int get hashCode => Object.hash(runtimeType,jobId,offerId,vehicleType,pickup,dropoff,quotedPrice,expiresInSeconds,pickupDistanceKm,commissionAmount);

@override
String toString() {
  return 'ServerMessage.jobOffer(jobId: $jobId, offerId: $offerId, vehicleType: $vehicleType, pickup: $pickup, dropoff: $dropoff, quotedPrice: $quotedPrice, expiresInSeconds: $expiresInSeconds, pickupDistanceKm: $pickupDistanceKm, commissionAmount: $commissionAmount)';
}


}

/// @nodoc
abstract mixin class $ServerMessageJobOfferCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessageJobOfferCopyWith(ServerMessageJobOffer value, $Res Function(ServerMessageJobOffer) _then) = _$ServerMessageJobOfferCopyWithImpl;
@useResult
$Res call({
 String jobId, String offerId, VehicleType vehicleType, LatLng pickup, LatLng dropoff, int? quotedPrice, int expiresInSeconds, double? pickupDistanceKm, int? commissionAmount
});


$LatLngCopyWith<$Res> get pickup;$LatLngCopyWith<$Res> get dropoff;

}
/// @nodoc
class _$ServerMessageJobOfferCopyWithImpl<$Res>
    implements $ServerMessageJobOfferCopyWith<$Res> {
  _$ServerMessageJobOfferCopyWithImpl(this._self, this._then);

  final ServerMessageJobOffer _self;
  final $Res Function(ServerMessageJobOffer) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? jobId = null,Object? offerId = null,Object? vehicleType = null,Object? pickup = null,Object? dropoff = null,Object? quotedPrice = freezed,Object? expiresInSeconds = null,Object? pickupDistanceKm = freezed,Object? commissionAmount = freezed,}) {
  return _then(ServerMessageJobOffer(
jobId: null == jobId ? _self.jobId : jobId // ignore: cast_nullable_to_non_nullable
as String,offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,pickup: null == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as LatLng,dropoff: null == dropoff ? _self.dropoff : dropoff // ignore: cast_nullable_to_non_nullable
as LatLng,quotedPrice: freezed == quotedPrice ? _self.quotedPrice : quotedPrice // ignore: cast_nullable_to_non_nullable
as int?,expiresInSeconds: null == expiresInSeconds ? _self.expiresInSeconds : expiresInSeconds // ignore: cast_nullable_to_non_nullable
as int,pickupDistanceKm: freezed == pickupDistanceKm ? _self.pickupDistanceKm : pickupDistanceKm // ignore: cast_nullable_to_non_nullable
as double?,commissionAmount: freezed == commissionAmount ? _self.commissionAmount : commissionAmount // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res> get pickup {
  
  return $LatLngCopyWith<$Res>(_self.pickup, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res> get dropoff {
  
  return $LatLngCopyWith<$Res>(_self.dropoff, (value) {
    return _then(_self.copyWith(dropoff: value));
  });
}
}

/// @nodoc


class ServerMessageError implements ServerMessage {
  const ServerMessageError({required this.detail});
  

 final  String detail;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessageErrorCopyWith<ServerMessageError> get copyWith => _$ServerMessageErrorCopyWithImpl<ServerMessageError>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessageError&&(identical(other.detail, detail) || other.detail == detail));
}


@override
int get hashCode => Object.hash(runtimeType,detail);

@override
String toString() {
  return 'ServerMessage.error(detail: $detail)';
}


}

/// @nodoc
abstract mixin class $ServerMessageErrorCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessageErrorCopyWith(ServerMessageError value, $Res Function(ServerMessageError) _then) = _$ServerMessageErrorCopyWithImpl;
@useResult
$Res call({
 String detail
});




}
/// @nodoc
class _$ServerMessageErrorCopyWithImpl<$Res>
    implements $ServerMessageErrorCopyWith<$Res> {
  _$ServerMessageErrorCopyWithImpl(this._self, this._then);

  final ServerMessageError _self;
  final $Res Function(ServerMessageError) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? detail = null,}) {
  return _then(ServerMessageError(
detail: null == detail ? _self.detail : detail // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

/// @nodoc


class ServerMessagePing implements ServerMessage {
  const ServerMessagePing();
  






@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessagePing);
}


@override
int get hashCode => runtimeType.hashCode;

@override
String toString() {
  return 'ServerMessage.ping()';
}


}




/// @nodoc


class ServerMessageUnknown implements ServerMessage {
  const ServerMessageUnknown({required final  Map<String, dynamic> raw}): _raw = raw;
  

 final  Map<String, dynamic> _raw;
 Map<String, dynamic> get raw {
  if (_raw is EqualUnmodifiableMapView) return _raw;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_raw);
}


/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServerMessageUnknownCopyWith<ServerMessageUnknown> get copyWith => _$ServerMessageUnknownCopyWithImpl<ServerMessageUnknown>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServerMessageUnknown&&const DeepCollectionEquality().equals(other._raw, _raw));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_raw));

@override
String toString() {
  return 'ServerMessage.unknown(raw: $raw)';
}


}

/// @nodoc
abstract mixin class $ServerMessageUnknownCopyWith<$Res> implements $ServerMessageCopyWith<$Res> {
  factory $ServerMessageUnknownCopyWith(ServerMessageUnknown value, $Res Function(ServerMessageUnknown) _then) = _$ServerMessageUnknownCopyWithImpl;
@useResult
$Res call({
 Map<String, dynamic> raw
});




}
/// @nodoc
class _$ServerMessageUnknownCopyWithImpl<$Res>
    implements $ServerMessageUnknownCopyWith<$Res> {
  _$ServerMessageUnknownCopyWithImpl(this._self, this._then);

  final ServerMessageUnknown _self;
  final $Res Function(ServerMessageUnknown) _then;

/// Create a copy of ServerMessage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') $Res call({Object? raw = null,}) {
  return _then(ServerMessageUnknown(
raw: null == raw ? _self._raw : raw // ignore: cast_nullable_to_non_nullable
as Map<String, dynamic>,
  ));
}


}

// dart format on
