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

 String? get id; String get userId; DriverStatus get status; bool get verified; String? get licenseUrl; String? get truckPhotoUrl; Truck? get truck; double get ratingAvg;
/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverProfileCopyWith<DriverProfile> get copyWith => _$DriverProfileCopyWithImpl<DriverProfile>(this as DriverProfile, _$identity);

  /// Serializes this DriverProfile to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.licenseUrl, licenseUrl) || other.licenseUrl == licenseUrl)&&(identical(other.truckPhotoUrl, truckPhotoUrl) || other.truckPhotoUrl == truckPhotoUrl)&&(identical(other.truck, truck) || other.truck == truck)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,status,verified,licenseUrl,truckPhotoUrl,truck,ratingAvg);

@override
String toString() {
  return 'DriverProfile(id: $id, userId: $userId, status: $status, verified: $verified, licenseUrl: $licenseUrl, truckPhotoUrl: $truckPhotoUrl, truck: $truck, ratingAvg: $ratingAvg)';
}


}

/// @nodoc
abstract mixin class $DriverProfileCopyWith<$Res>  {
  factory $DriverProfileCopyWith(DriverProfile value, $Res Function(DriverProfile) _then) = _$DriverProfileCopyWithImpl;
@useResult
$Res call({
 String? id, String userId, DriverStatus status, bool verified, String? licenseUrl, String? truckPhotoUrl, Truck? truck, double ratingAvg
});


$TruckCopyWith<$Res>? get truck;

}
/// @nodoc
class _$DriverProfileCopyWithImpl<$Res>
    implements $DriverProfileCopyWith<$Res> {
  _$DriverProfileCopyWithImpl(this._self, this._then);

  final DriverProfile _self;
  final $Res Function(DriverProfile) _then;

/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = freezed,Object? userId = null,Object? status = null,Object? verified = null,Object? licenseUrl = freezed,Object? truckPhotoUrl = freezed,Object? truck = freezed,Object? ratingAvg = null,}) {
  return _then(_self.copyWith(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DriverStatus,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,licenseUrl: freezed == licenseUrl ? _self.licenseUrl : licenseUrl // ignore: cast_nullable_to_non_nullable
as String?,truckPhotoUrl: freezed == truckPhotoUrl ? _self.truckPhotoUrl : truckPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,truck: freezed == truck ? _self.truck : truck // ignore: cast_nullable_to_non_nullable
as Truck?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,
  ));
}
/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TruckCopyWith<$Res>? get truck {
    if (_self.truck == null) {
    return null;
  }

  return $TruckCopyWith<$Res>(_self.truck!, (value) {
    return _then(_self.copyWith(truck: value));
  });
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String? id,  String userId,  DriverStatus status,  bool verified,  String? licenseUrl,  String? truckPhotoUrl,  Truck? truck,  double ratingAvg)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverProfile() when $default != null:
return $default(_that.id,_that.userId,_that.status,_that.verified,_that.licenseUrl,_that.truckPhotoUrl,_that.truck,_that.ratingAvg);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String? id,  String userId,  DriverStatus status,  bool verified,  String? licenseUrl,  String? truckPhotoUrl,  Truck? truck,  double ratingAvg)  $default,) {final _that = this;
switch (_that) {
case _DriverProfile():
return $default(_that.id,_that.userId,_that.status,_that.verified,_that.licenseUrl,_that.truckPhotoUrl,_that.truck,_that.ratingAvg);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String? id,  String userId,  DriverStatus status,  bool verified,  String? licenseUrl,  String? truckPhotoUrl,  Truck? truck,  double ratingAvg)?  $default,) {final _that = this;
switch (_that) {
case _DriverProfile() when $default != null:
return $default(_that.id,_that.userId,_that.status,_that.verified,_that.licenseUrl,_that.truckPhotoUrl,_that.truck,_that.ratingAvg);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DriverProfile implements DriverProfile {
  const _DriverProfile({this.id, required this.userId, required this.status, required this.verified, this.licenseUrl, this.truckPhotoUrl, this.truck, this.ratingAvg = 0});
  factory _DriverProfile.fromJson(Map<String, dynamic> json) => _$DriverProfileFromJson(json);

@override final  String? id;
@override final  String userId;
@override final  DriverStatus status;
@override final  bool verified;
@override final  String? licenseUrl;
@override final  String? truckPhotoUrl;
@override final  Truck? truck;
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
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverProfile&&(identical(other.id, id) || other.id == id)&&(identical(other.userId, userId) || other.userId == userId)&&(identical(other.status, status) || other.status == status)&&(identical(other.verified, verified) || other.verified == verified)&&(identical(other.licenseUrl, licenseUrl) || other.licenseUrl == licenseUrl)&&(identical(other.truckPhotoUrl, truckPhotoUrl) || other.truckPhotoUrl == truckPhotoUrl)&&(identical(other.truck, truck) || other.truck == truck)&&(identical(other.ratingAvg, ratingAvg) || other.ratingAvg == ratingAvg));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,userId,status,verified,licenseUrl,truckPhotoUrl,truck,ratingAvg);

@override
String toString() {
  return 'DriverProfile(id: $id, userId: $userId, status: $status, verified: $verified, licenseUrl: $licenseUrl, truckPhotoUrl: $truckPhotoUrl, truck: $truck, ratingAvg: $ratingAvg)';
}


}

/// @nodoc
abstract mixin class _$DriverProfileCopyWith<$Res> implements $DriverProfileCopyWith<$Res> {
  factory _$DriverProfileCopyWith(_DriverProfile value, $Res Function(_DriverProfile) _then) = __$DriverProfileCopyWithImpl;
@override @useResult
$Res call({
 String? id, String userId, DriverStatus status, bool verified, String? licenseUrl, String? truckPhotoUrl, Truck? truck, double ratingAvg
});


@override $TruckCopyWith<$Res>? get truck;

}
/// @nodoc
class __$DriverProfileCopyWithImpl<$Res>
    implements _$DriverProfileCopyWith<$Res> {
  __$DriverProfileCopyWithImpl(this._self, this._then);

  final _DriverProfile _self;
  final $Res Function(_DriverProfile) _then;

/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = freezed,Object? userId = null,Object? status = null,Object? verified = null,Object? licenseUrl = freezed,Object? truckPhotoUrl = freezed,Object? truck = freezed,Object? ratingAvg = null,}) {
  return _then(_DriverProfile(
id: freezed == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String?,userId: null == userId ? _self.userId : userId // ignore: cast_nullable_to_non_nullable
as String,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as DriverStatus,verified: null == verified ? _self.verified : verified // ignore: cast_nullable_to_non_nullable
as bool,licenseUrl: freezed == licenseUrl ? _self.licenseUrl : licenseUrl // ignore: cast_nullable_to_non_nullable
as String?,truckPhotoUrl: freezed == truckPhotoUrl ? _self.truckPhotoUrl : truckPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,truck: freezed == truck ? _self.truck : truck // ignore: cast_nullable_to_non_nullable
as Truck?,ratingAvg: null == ratingAvg ? _self.ratingAvg : ratingAvg // ignore: cast_nullable_to_non_nullable
as double,
  ));
}

/// Create a copy of DriverProfile
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$TruckCopyWith<$Res>? get truck {
    if (_self.truck == null) {
    return null;
  }

  return $TruckCopyWith<$Res>(_self.truck!, (value) {
    return _then(_self.copyWith(truck: value));
  });
}
}

// dart format on
