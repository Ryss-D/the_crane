// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver_profile.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$DriverProfile {

 String get userId; DriverStatus get status; bool get verified; String? get licenseUrl; String? get truckPlate; TruckType? get truckType; TruckCapacity? get capacity; double get ratingAvg;
/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverProfileCopyWith<DriverProfile> get copyWith => _$DriverProfileCopyWithImpl<DriverProfile>(this as DriverProfile, _$identity);

  /// Serializes this DriverProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverProfile&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.licenseUrl, licenseUrl) || other.licenseUrl == licenseUrl)&&(identical(other.truckPlate, truckPlate) || other.truckPlate == truckPlate)&&(identical(other.truckType, truckType) || other.truckType == truckType)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,status,verified,licenseUrl,truckPlate,truckType,capacity,ratingAvg);

@override
String toString() {
  return 'DriverProfile(userId: $userId, status: $status, verified: $verified, licenseUrl: $licenseUrl, truckPlate: $truckPlate, truckType: $truckType, capacity: $capacity, ratingAvg: $ratingAvg)';
}


}

/// @nodoc
abstract mixin class $DriverProfileCopyWith<$Res>  {
  factory $DriverProfileCopyWith(DriverProfile value, $Res Function(DriverProfile) _then) = _$DriverProfileCopyWithImpl;
@useResult
$Res call({
 String userId, DriverStatus status, bool verified, String? licenseUrl, String? truckPlate, TruckType? truckType, TruckCapacity? capacity, double ratingAvg
});




}
/// @nodoc
class _$DriverProfileCopyWithImpl<$Res>
    implements $DriverProfileCopyWith<$Res> {
  _$DriverProfileCopyWithImpl(this._self, this._then);

  final DriverProfile _self;
  final $Res Function(DriverProfile) _then;

/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? userId = null,Object? status = null,Object? verified = null,Object? licenseUrl = freezed,Object? truckPlate = freezed,Object? truckType = freezed,Object? capacity = freezed,Object? ratingAvg = null,}) {
  return _then(_self.copyWith(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DriverStatus,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,licenseUrl: freezed == licenseUrl ? _self.licenseUrl : licenseUrl // ignore: cast_nullable_to_non_nullable
as String?,truckPlate: freezed == truckPlate ? _self.truckPlate : truckPlate // ignore: cast_nullable_to_non_nullable
as String?,truckType: freezed == truckType ? _self.truckType : truckType // ignore: cast_nullable_to_non_nullable
as TruckType?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as TruckCapacity?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

}


/// Adds pattern-matching-related methods to [DriverProfile].
extension DriverProfilePatterns on DriverProfile {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverProfile value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverProfile() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverProfile value)  $default,){
final _that = this;
switch (_that) {
case _DriverProfile():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverProfile value)?  $default,){
final _that = this;
switch (_that) {
case _DriverProfile() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String userId,  DriverStatus status,  bool verified,  String? licenseUrl,  String? truckPlate,  TruckType? truckType,  TruckCapacity? capacity,  double ratingAvg)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverProfile() when $default != null:
return $default(_that.userId,_that.status,_that.verified,_that.licenseUrl,_that.truckPlate,_that.truckType,_that.capacity,_that.ratingAvg);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String userId,  DriverStatus status,  bool verified,  String? licenseUrl,  String? truckPlate,  TruckType? truckType,  TruckCapacity? capacity,  double ratingAvg)  $default,) {final _that = this;
switch (_that) {
case _DriverProfile():
return $default(_that.userId,_that.status,_that.verified,_that.licenseUrl,_that.truckPlate,_that.truckType,_that.capacity,_that.ratingAvg);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String userId,  DriverStatus status,  bool verified,  String? licenseUrl,  String? truckPlate,  TruckType? truckType,  TruckCapacity? capacity,  double ratingAvg)?  $default,) {final _that = this;
switch (_that) {
case _DriverProfile() when $default != null:
return $default(_that.userId,_that.status,_that.verified,_that.licenseUrl,_that.truckPlate,_that.truckType,_that.capacity,_that.ratingAvg);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DriverProfile implements DriverProfile {
  const _DriverProfile({required this.userId, required this.status, required this.verified, this.licenseUrl, this.truckPlate, this.truckType, this.capacity, this.ratingAvg = 0});
  factory _DriverProfile.fromJson(Map<String, dynamic> json) => _$DriverProfileFromJson(json);

@override final  String userId;
@override final  DriverStatus status;
@override final  bool verified;
@override final  String? licenseUrl;
@override final  String? truckPlate;
@override final  TruckType? truckType;
@override final  TruckCapacity? capacity;
@override@JsonKey() final  double ratingAvg;

/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverProfileCopyWith<_DriverProfile> get copyWith => __$DriverProfileCopyWithImpl<_DriverProfile>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DriverProfileToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverProfile&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.licenseUrl, licenseUrl) || other.licenseUrl == licenseUrl)&&(identical(other.truckPlate, truckPlate) || other.truckPlate == truckPlate)&&(identical(other.truckType, truckType) || other.truckType == truckType)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,userId,status,verified,licenseUrl,truckPlate,truckType,capacity,ratingAvg);

@override
String toString() {
  return 'DriverProfile(userId: $userId, status: $status, verified: $verified, licenseUrl: $licenseUrl, truckPlate: $truckPlate, truckType: $truckType, capacity: $capacity, ratingAvg: $ratingAvg)';
}


}

/// @nodoc
abstract mixin class _$DriverProfileCopyWith<$Res> implements $DriverProfileCopyWith<$Res> {
  factory _$DriverProfileCopyWith(_DriverProfile value, $Res Function(_DriverProfile) _then) = __$DriverProfileCopyWithImpl;
@override @useResult
$Res call({
 String userId, DriverStatus status, bool verified, String? licenseUrl, String? truckPlate, TruckType? truckType, TruckCapacity? capacity, double ratingAvg
});




}
/// @nodoc
class __$DriverProfileCopyWithImpl<$Res>
    implements _$DriverProfileCopyWith<$Res> {
  __$DriverProfileCopyWithImpl(this._self, this._then);

  final _DriverProfile _self;
  final $Res Function(_DriverProfile) _then;

/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? userId = null,Object? status = null,Object? verified = null,Object? licenseUrl = freezed,Object? truckPlate = freezed,Object? truckType = freezed,Object? capacity = freezed,Object? ratingAvg = null,}) {
  return _then(_DriverProfile(
userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DriverStatus,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,licenseUrl: freezed == licenseUrl ? _self.licenseUrl : licenseUrl // ignore: cast_nullable_to_non_nullable
as String?,truckPlate: freezed == truckPlate ? _self.truckPlate : truckPlate // ignore: cast_nullable_to_non_nullable
as String?,truckType: freezed == truckType ? _self.truckType : truckType // ignore: cast_nullable_to_non_nullable
as TruckType?,capacity: freezed == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as TruckCapacity?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,
  ));
}


}

// dart format on
