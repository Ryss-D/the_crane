// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JobDriverSummary {

 String get id; String get name; String? get phone; String get truckPlate; TruckType? get truckType; double get ratingAvg; String? get photoUrl;
/// Create a copy of JobDriverSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobDriverSummaryCopyWith<JobDriverSummary> get copyWith => _$JobDriverSummaryCopyWithImpl<JobDriverSummary>(this as JobDriverSummary, _$identity);

  /// Serializes this JobDriverSummary to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobDriverSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.truckPlate, truckPlate) || other.truckPlate == truckPlate)&&(identical(other.truckType, truckType) || other.truckType == truckType)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,phone,truckPlate,truckType,ratingAvg,photoUrl);

@override
String toString() {
  return 'JobDriverSummary(id: $id, name: $name, phone: $phone, truckPlate: $truckPlate, truckType: $truckType, ratingAvg: $ratingAvg, photoUrl: $photoUrl)';
}


}

/// @nodoc
abstract mixin class $JobDriverSummaryCopyWith<$Res>  {
  factory $JobDriverSummaryCopyWith(JobDriverSummary value, $Res Function(JobDriverSummary) _then) = _$JobDriverSummaryCopyWithImpl;
@useResult
$Res call({
 String id, String name, String? phone, String truckPlate, TruckType? truckType, double ratingAvg, String? photoUrl
});




}
/// @nodoc
class _$JobDriverSummaryCopyWithImpl<$Res>
    implements $JobDriverSummaryCopyWith<$Res> {
  _$JobDriverSummaryCopyWithImpl(this._self, this._then);

  final JobDriverSummary _self;
  final $Res Function(JobDriverSummary) _then;

/// Create a copy of JobDriverSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? name = null,Object? phone = freezed,Object? truckPlate = null,Object? truckType = freezed,Object? ratingAvg = null,Object? photoUrl = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,truckPlate: null == truckPlate ? _self.truckPlate : truckPlate // ignore: cast_nullable_to_non_nullable
as String,truckType: freezed == truckType ? _self.truckType : truckType // ignore: cast_nullable_to_non_nullable
as TruckType?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [JobDriverSummary].
extension JobDriverSummaryPatterns on JobDriverSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JobDriverSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JobDriverSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JobDriverSummary value)  $default,){
final _that = this;
switch (_that) {
case _JobDriverSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JobDriverSummary value)?  $default,){
final _that = this;
switch (_that) {
case _JobDriverSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String name,  String? phone,  String truckPlate,  TruckType? truckType,  double ratingAvg,  String? photoUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JobDriverSummary() when $default != null:
return $default(_that.id,_that.name,_that.phone,_that.truckPlate,_that.truckType,_that.ratingAvg,_that.photoUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String name,  String? phone,  String truckPlate,  TruckType? truckType,  double ratingAvg,  String? photoUrl)  $default,) {final _that = this;
switch (_that) {
case _JobDriverSummary():
return $default(_that.id,_that.name,_that.phone,_that.truckPlate,_that.truckType,_that.ratingAvg,_that.photoUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String name,  String? phone,  String truckPlate,  TruckType? truckType,  double ratingAvg,  String? photoUrl)?  $default,) {final _that = this;
switch (_that) {
case _JobDriverSummary() when $default != null:
return $default(_that.id,_that.name,_that.phone,_that.truckPlate,_that.truckType,_that.ratingAvg,_that.photoUrl);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JobDriverSummary implements JobDriverSummary {
  const _JobDriverSummary({required this.id, required this.name, this.phone, required this.truckPlate, this.truckType, this.ratingAvg = 0, this.photoUrl});
  factory _JobDriverSummary.fromJson(Map<String, dynamic> json) => _$JobDriverSummaryFromJson(json);

@override final  String id;
@override final  String name;
@override final  String? phone;
@override final  String truckPlate;
@override final  TruckType? truckType;
@override@JsonKey() final  double ratingAvg;
@override final  String? photoUrl;

/// Create a copy of JobDriverSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobDriverSummaryCopyWith<_JobDriverSummary> get copyWith => __$JobDriverSummaryCopyWithImpl<_JobDriverSummary>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobDriverSummaryToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JobDriverSummary&&(identical(other.id, id) || other.id == id)&&(identical(other.name, name) || other.name == name)&&(identical(other.phone, phone) || other.phone == phone)&&(identical(other.truckPlate, truckPlate) || other.truckPlate == truckPlate)&&(identical(other.truckType, truckType) || other.truckType == truckType)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg)&&(identical(other.photoUrl, photoUrl) || other.photoUrl == photoUrl));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,name,phone,truckPlate,truckType,ratingAvg,photoUrl);

@override
String toString() {
  return 'JobDriverSummary(id: $id, name: $name, phone: $phone, truckPlate: $truckPlate, truckType: $truckType, ratingAvg: $ratingAvg, photoUrl: $photoUrl)';
}


}

/// @nodoc
abstract mixin class _$JobDriverSummaryCopyWith<$Res> implements $JobDriverSummaryCopyWith<$Res> {
  factory _$JobDriverSummaryCopyWith(_JobDriverSummary value, $Res Function(_JobDriverSummary) _then) = __$JobDriverSummaryCopyWithImpl;
@override @useResult
$Res call({
 String id, String name, String? phone, String truckPlate, TruckType? truckType, double ratingAvg, String? photoUrl
});




}
/// @nodoc
class __$JobDriverSummaryCopyWithImpl<$Res>
    implements _$JobDriverSummaryCopyWith<$Res> {
  __$JobDriverSummaryCopyWithImpl(this._self, this._then);

  final _JobDriverSummary _self;
  final $Res Function(_JobDriverSummary) _then;

/// Create a copy of JobDriverSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? name = null,Object? phone = freezed,Object? truckPlate = null,Object? truckType = freezed,Object? ratingAvg = null,Object? photoUrl = freezed,}) {
  return _then(_JobDriverSummary(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,phone: freezed == phone ? _self.phone : phone // ignore: cast_nullable_to_non_nullable
as String?,truckPlate: null == truckPlate ? _self.truckPlate : truckPlate // ignore: cast_nullable_to_non_nullable
as String,truckType: freezed == truckType ? _self.truckType : truckType // ignore: cast_nullable_to_non_nullable
as TruckType?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,photoUrl: freezed == photoUrl ? _self.photoUrl : photoUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$Job {

 String get id; String get customerId; String? get driverId; JobStatus get status; VehicleType get vehicleType; LatLng get pickup; String get pickupAddress; LatLng get dropoff; String get dropoffAddress; double get distanceKm; int get quotedPrice; int? get finalPrice; String get paymentMethod; JobDriverSummary? get driver; DateTime get requestedAt; DateTime? get assignedAt; DateTime? get pickedUpAt; DateTime? get completedAt; DateTime? get cancelledAt; String? get cancelReason;
/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobCopyWith<Job> get copyWith => _$JobCopyWithImpl<Job>(this as Job, _$identity);

  /// Serializes this Job to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Job&&(identical(other.id, id) || other.id == id)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.status, status) || other.status == status)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.pickup, pickup) || other.pickup == pickup)&&(identical(other.pickupAddress, pickupAddress) || other.pickupAddress == pickupAddress)&&(identical(other.dropoff, dropoff) || other.dropoff == dropoff)&&(identical(other.dropoffAddress, dropoffAddress) || other.dropoffAddress == dropoffAddress)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.quotedPrice, quotedPrice) || other.quotedPrice == quotedPrice)&&(identical(other.finalPrice, finalPrice) || other.finalPrice == finalPrice)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.pickedUpAt, pickedUpAt) || other.pickedUpAt == pickedUpAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancelReason, cancelReason) || other.cancelReason == cancelReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,customerId,driverId,status,vehicleType,pickup,pickupAddress,dropoff,dropoffAddress,distanceKm,quotedPrice,finalPrice,paymentMethod,driver,requestedAt,assignedAt,pickedUpAt,completedAt,cancelledAt,cancelReason]);

@override
String toString() {
  return 'Job(id: $id, customerId: $customerId, driverId: $driverId, status: $status, vehicleType: $vehicleType, pickup: $pickup, pickupAddress: $pickupAddress, dropoff: $dropoff, dropoffAddress: $dropoffAddress, distanceKm: $distanceKm, quotedPrice: $quotedPrice, finalPrice: $finalPrice, paymentMethod: $paymentMethod, driver: $driver, requestedAt: $requestedAt, assignedAt: $assignedAt, pickedUpAt: $pickedUpAt, completedAt: $completedAt, cancelledAt: $cancelledAt, cancelReason: $cancelReason)';
}


}

/// @nodoc
abstract mixin class $JobCopyWith<$Res>  {
  factory $JobCopyWith(Job value, $Res Function(Job) _then) = _$JobCopyWithImpl;
@useResult
$Res call({
 String id, String customerId, String? driverId, JobStatus status, VehicleType vehicleType, LatLng pickup, String pickupAddress, LatLng dropoff, String dropoffAddress, double distanceKm, int quotedPrice, int? finalPrice, String paymentMethod, JobDriverSummary? driver, DateTime requestedAt, DateTime? assignedAt, DateTime? pickedUpAt, DateTime? completedAt, DateTime? cancelledAt, String? cancelReason
});


$LatLngCopyWith<$Res> get pickup;$LatLngCopyWith<$Res> get dropoff;$JobDriverSummaryCopyWith<$Res>? get driver;

}
/// @nodoc
class _$JobCopyWithImpl<$Res>
    implements $JobCopyWith<$Res> {
  _$JobCopyWithImpl(this._self, this._then);

  final Job _self;
  final $Res Function(Job) _then;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? customerId = null,Object? driverId = freezed,Object? status = null,Object? vehicleType = null,Object? pickup = null,Object? pickupAddress = null,Object? dropoff = null,Object? dropoffAddress = null,Object? distanceKm = null,Object? quotedPrice = null,Object? finalPrice = freezed,Object? paymentMethod = null,Object? driver = freezed,Object? requestedAt = null,Object? assignedAt = freezed,Object? pickedUpAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? cancelReason = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,pickup: null == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as LatLng,pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,dropoff: null == dropoff ? _self.dropoff : dropoff // ignore: cast_nullable_to_non_nullable
as LatLng,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,quotedPrice: null == quotedPrice ? _self.quotedPrice : quotedPrice // ignore: cast_nullable_to_non_nullable
as int,finalPrice: freezed == finalPrice ? _self.finalPrice : finalPrice // ignore: cast_nullable_to_non_nullable
as int?,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,driver: freezed == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as JobDriverSummary?,requestedAt: null == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pickedUpAt: freezed == pickedUpAt ? _self.pickedUpAt : pickedUpAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelReason: freezed == cancelReason ? _self.cancelReason : cancelReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}
/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res> get pickup {
  
  return $LatLngCopyWith<$Res>(_self.pickup, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res> get dropoff {
  
  return $LatLngCopyWith<$Res>(_self.dropoff, (value) {
    return _then(_self.copyWith(dropoff: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobDriverSummaryCopyWith<$Res>? get driver {
    if (_self.driver == null) {
    return null;
  }

  return $JobDriverSummaryCopyWith<$Res>(_self.driver!, (value) {
    return _then(_self.copyWith(driver: value));
  });
}
}


/// Adds pattern-matching-related methods to [Job].
extension JobPatterns on Job {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Job value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Job() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Job value)  $default,){
final _that = this;
switch (_that) {
case _Job():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Job value)?  $default,){
final _that = this;
switch (_that) {
case _Job() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String customerId,  String? driverId,  JobStatus status,  VehicleType vehicleType,  LatLng pickup,  String pickupAddress,  LatLng dropoff,  String dropoffAddress,  double distanceKm,  int quotedPrice,  int? finalPrice,  String paymentMethod,  JobDriverSummary? driver,  DateTime requestedAt,  DateTime? assignedAt,  DateTime? pickedUpAt,  DateTime? completedAt,  DateTime? cancelledAt,  String? cancelReason)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that.id,_that.customerId,_that.driverId,_that.status,_that.vehicleType,_that.pickup,_that.pickupAddress,_that.dropoff,_that.dropoffAddress,_that.distanceKm,_that.quotedPrice,_that.finalPrice,_that.paymentMethod,_that.driver,_that.requestedAt,_that.assignedAt,_that.pickedUpAt,_that.completedAt,_that.cancelledAt,_that.cancelReason);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String customerId,  String? driverId,  JobStatus status,  VehicleType vehicleType,  LatLng pickup,  String pickupAddress,  LatLng dropoff,  String dropoffAddress,  double distanceKm,  int quotedPrice,  int? finalPrice,  String paymentMethod,  JobDriverSummary? driver,  DateTime requestedAt,  DateTime? assignedAt,  DateTime? pickedUpAt,  DateTime? completedAt,  DateTime? cancelledAt,  String? cancelReason)  $default,) {final _that = this;
switch (_that) {
case _Job():
return $default(_that.id,_that.customerId,_that.driverId,_that.status,_that.vehicleType,_that.pickup,_that.pickupAddress,_that.dropoff,_that.dropoffAddress,_that.distanceKm,_that.quotedPrice,_that.finalPrice,_that.paymentMethod,_that.driver,_that.requestedAt,_that.assignedAt,_that.pickedUpAt,_that.completedAt,_that.cancelledAt,_that.cancelReason);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String customerId,  String? driverId,  JobStatus status,  VehicleType vehicleType,  LatLng pickup,  String pickupAddress,  LatLng dropoff,  String dropoffAddress,  double distanceKm,  int quotedPrice,  int? finalPrice,  String paymentMethod,  JobDriverSummary? driver,  DateTime requestedAt,  DateTime? assignedAt,  DateTime? pickedUpAt,  DateTime? completedAt,  DateTime? cancelledAt,  String? cancelReason)?  $default,) {final _that = this;
switch (_that) {
case _Job() when $default != null:
return $default(_that.id,_that.customerId,_that.driverId,_that.status,_that.vehicleType,_that.pickup,_that.pickupAddress,_that.dropoff,_that.dropoffAddress,_that.distanceKm,_that.quotedPrice,_that.finalPrice,_that.paymentMethod,_that.driver,_that.requestedAt,_that.assignedAt,_that.pickedUpAt,_that.completedAt,_that.cancelledAt,_that.cancelReason);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Job implements Job {
  const _Job({required this.id, required this.customerId, this.driverId, required this.status, required this.vehicleType, required this.pickup, required this.pickupAddress, required this.dropoff, required this.dropoffAddress, required this.distanceKm, required this.quotedPrice, this.finalPrice, this.paymentMethod = 'cash', this.driver, required this.requestedAt, this.assignedAt, this.pickedUpAt, this.completedAt, this.cancelledAt, this.cancelReason});
  factory _Job.fromJson(Map<String, dynamic> json) => _$JobFromJson(json);

@override final  String id;
@override final  String customerId;
@override final  String? driverId;
@override final  JobStatus status;
@override final  VehicleType vehicleType;
@override final  LatLng pickup;
@override final  String pickupAddress;
@override final  LatLng dropoff;
@override final  String dropoffAddress;
@override final  double distanceKm;
@override final  int quotedPrice;
@override final  int? finalPrice;
@override@JsonKey() final  String paymentMethod;
@override final  JobDriverSummary? driver;
@override final  DateTime requestedAt;
@override final  DateTime? assignedAt;
@override final  DateTime? pickedUpAt;
@override final  DateTime? completedAt;
@override final  DateTime? cancelledAt;
@override final  String? cancelReason;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobCopyWith<_Job> get copyWith => __$JobCopyWithImpl<_Job>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Job&&(identical(other.id, id) || other.id == id)&&(identical(other.customerId, customerId) || other.customerId == customerId)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.status, status) || other.status == status)&&(identical(other.vehicleType, vehicleType) || other.vehicleType == vehicleType)&&(identical(other.pickup, pickup) || other.pickup == pickup)&&(identical(other.pickupAddress, pickupAddress) || other.pickupAddress == pickupAddress)&&(identical(other.dropoff, dropoff) || other.dropoff == dropoff)&&(identical(other.dropoffAddress, dropoffAddress) || other.dropoffAddress == dropoffAddress)&&(identical(other.distanceKm, distanceKm) || other.distanceKm == distanceKm)&&(identical(other.quotedPrice, quotedPrice) || other.quotedPrice == quotedPrice)&&(identical(other.finalPrice, finalPrice) || other.finalPrice == finalPrice)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.driver, driver) || other.driver == driver)&&(identical(other.requestedAt, requestedAt) || other.requestedAt == requestedAt)&&(identical(other.assignedAt, assignedAt) || other.assignedAt == assignedAt)&&(identical(other.pickedUpAt, pickedUpAt) || other.pickedUpAt == pickedUpAt)&&(identical(other.completedAt, completedAt) || other.completedAt == completedAt)&&(identical(other.cancelledAt, cancelledAt) || other.cancelledAt == cancelledAt)&&(identical(other.cancelReason, cancelReason) || other.cancelReason == cancelReason));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hashAll([runtimeType,id,customerId,driverId,status,vehicleType,pickup,pickupAddress,dropoff,dropoffAddress,distanceKm,quotedPrice,finalPrice,paymentMethod,driver,requestedAt,assignedAt,pickedUpAt,completedAt,cancelledAt,cancelReason]);

@override
String toString() {
  return 'Job(id: $id, customerId: $customerId, driverId: $driverId, status: $status, vehicleType: $vehicleType, pickup: $pickup, pickupAddress: $pickupAddress, dropoff: $dropoff, dropoffAddress: $dropoffAddress, distanceKm: $distanceKm, quotedPrice: $quotedPrice, finalPrice: $finalPrice, paymentMethod: $paymentMethod, driver: $driver, requestedAt: $requestedAt, assignedAt: $assignedAt, pickedUpAt: $pickedUpAt, completedAt: $completedAt, cancelledAt: $cancelledAt, cancelReason: $cancelReason)';
}


}

/// @nodoc
abstract mixin class _$JobCopyWith<$Res> implements $JobCopyWith<$Res> {
  factory _$JobCopyWith(_Job value, $Res Function(_Job) _then) = __$JobCopyWithImpl;
@override @useResult
$Res call({
 String id, String customerId, String? driverId, JobStatus status, VehicleType vehicleType, LatLng pickup, String pickupAddress, LatLng dropoff, String dropoffAddress, double distanceKm, int quotedPrice, int? finalPrice, String paymentMethod, JobDriverSummary? driver, DateTime requestedAt, DateTime? assignedAt, DateTime? pickedUpAt, DateTime? completedAt, DateTime? cancelledAt, String? cancelReason
});


@override $LatLngCopyWith<$Res> get pickup;@override $LatLngCopyWith<$Res> get dropoff;@override $JobDriverSummaryCopyWith<$Res>? get driver;

}
/// @nodoc
class __$JobCopyWithImpl<$Res>
    implements _$JobCopyWith<$Res> {
  __$JobCopyWithImpl(this._self, this._then);

  final _Job _self;
  final $Res Function(_Job) _then;

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? customerId = null,Object? driverId = freezed,Object? status = null,Object? vehicleType = null,Object? pickup = null,Object? pickupAddress = null,Object? dropoff = null,Object? dropoffAddress = null,Object? distanceKm = null,Object? quotedPrice = null,Object? finalPrice = freezed,Object? paymentMethod = null,Object? driver = freezed,Object? requestedAt = null,Object? assignedAt = freezed,Object? pickedUpAt = freezed,Object? completedAt = freezed,Object? cancelledAt = freezed,Object? cancelReason = freezed,}) {
  return _then(_Job(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,customerId: null == customerId ? _self.customerId : customerId // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as JobStatus,vehicleType: null == vehicleType ? _self.vehicleType : vehicleType // ignore: cast_nullable_to_non_nullable
as VehicleType,pickup: null == pickup ? _self.pickup : pickup // ignore: cast_nullable_to_non_nullable
as LatLng,pickupAddress: null == pickupAddress ? _self.pickupAddress : pickupAddress // ignore: cast_nullable_to_non_nullable
as String,dropoff: null == dropoff ? _self.dropoff : dropoff // ignore: cast_nullable_to_non_nullable
as LatLng,dropoffAddress: null == dropoffAddress ? _self.dropoffAddress : dropoffAddress // ignore: cast_nullable_to_non_nullable
as String,distanceKm: null == distanceKm ? _self.distanceKm : distanceKm // ignore: cast_nullable_to_non_nullable
as double,quotedPrice: null == quotedPrice ? _self.quotedPrice : quotedPrice // ignore: cast_nullable_to_non_nullable
as int,finalPrice: freezed == finalPrice ? _self.finalPrice : finalPrice // ignore: cast_nullable_to_non_nullable
as int?,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,driver: freezed == driver ? _self.driver : driver // ignore: cast_nullable_to_non_nullable
as JobDriverSummary?,requestedAt: null == requestedAt ? _self.requestedAt : requestedAt // ignore: cast_nullable_to_non_nullable
as DateTime,assignedAt: freezed == assignedAt ? _self.assignedAt : assignedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,pickedUpAt: freezed == pickedUpAt ? _self.pickedUpAt : pickedUpAt // ignore: cast_nullable_to_non_nullable
as DateTime?,completedAt: freezed == completedAt ? _self.completedAt : completedAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelledAt: freezed == cancelledAt ? _self.cancelledAt : cancelledAt // ignore: cast_nullable_to_non_nullable
as DateTime?,cancelReason: freezed == cancelReason ? _self.cancelReason : cancelReason // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res> get pickup {
  
  return $LatLngCopyWith<$Res>(_self.pickup, (value) {
    return _then(_self.copyWith(pickup: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$LatLngCopyWith<$Res> get dropoff {
  
  return $LatLngCopyWith<$Res>(_self.dropoff, (value) {
    return _then(_self.copyWith(dropoff: value));
  });
}/// Create a copy of Job
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobDriverSummaryCopyWith<$Res>? get driver {
    if (_self.driver == null) {
    return null;
  }

  return $JobDriverSummaryCopyWith<$Res>(_self.driver!, (value) {
    return _then(_self.copyWith(driver: value));
  });
}
}

// dart format on
