// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_offer.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JobOffer {

 String get offerId; Job get job; double get pickupDistanceKm; int get commissionAmount; int get ttlSeconds; DateTime get offeredAt;
/// Create a copy of JobOffer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobOfferCopyWith<JobOffer> get copyWith => _$JobOfferCopyWithImpl<JobOffer>(this as JobOffer, _$identity);

  /// Serializes this JobOffer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobOffer&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.job, job) || other.job == job)&&(identical(other.pickupDistanceKm, pickupDistanceKm) || other.pickupDistanceKm == pickupDistanceKm)&&(identical(other.commissionAmount, commissionAmount) || other.commissionAmount == commissionAmount)&&(identical(other.ttlSeconds, ttlSeconds) || other.ttlSeconds == ttlSeconds)&&(identical(other.offeredAt, offeredAt) || other.offeredAt == offeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offerId,job,pickupDistanceKm,commissionAmount,ttlSeconds,offeredAt);

@override
String toString() {
  return 'JobOffer(offerId: $offerId, job: $job, pickupDistanceKm: $pickupDistanceKm, commissionAmount: $commissionAmount, ttlSeconds: $ttlSeconds, offeredAt: $offeredAt)';
}


}

/// @nodoc
abstract mixin class $JobOfferCopyWith<$Res>  {
  factory $JobOfferCopyWith(JobOffer value, $Res Function(JobOffer) _then) = _$JobOfferCopyWithImpl;
@useResult
$Res call({
 String offerId, Job job, double pickupDistanceKm, int commissionAmount, int ttlSeconds, DateTime offeredAt
});


$JobCopyWith<$Res> get job;

}
/// @nodoc
class _$JobOfferCopyWithImpl<$Res>
    implements $JobOfferCopyWith<$Res> {
  _$JobOfferCopyWithImpl(this._self, this._then);

  final JobOffer _self;
  final $Res Function(JobOffer) _then;

/// Create a copy of JobOffer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? offerId = null,Object? job = null,Object? pickupDistanceKm = null,Object? commissionAmount = null,Object? ttlSeconds = null,Object? offeredAt = null,}) {
  return _then(_self.copyWith(
offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,job: null == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as Job,pickupDistanceKm: null == pickupDistanceKm ? _self.pickupDistanceKm : pickupDistanceKm // ignore: cast_nullable_to_non_nullable
as double,commissionAmount: null == commissionAmount ? _self.commissionAmount : commissionAmount // ignore: cast_nullable_to_non_nullable
as int,ttlSeconds: null == ttlSeconds ? _self.ttlSeconds : ttlSeconds // ignore: cast_nullable_to_non_nullable
as int,offeredAt: null == offeredAt ? _self.offeredAt : offeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}
/// Create a copy of JobOffer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobCopyWith<$Res> get job {
  
  return $JobCopyWith<$Res>(_self.job, (value) {
    return _then(_self.copyWith(job: value));
  });
}
}


/// Adds pattern-matching-related methods to [JobOffer].
extension JobOfferPatterns on JobOffer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JobOffer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JobOffer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JobOffer value)  $default,){
final _that = this;
switch (_that) {
case _JobOffer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JobOffer value)?  $default,){
final _that = this;
switch (_that) {
case _JobOffer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String offerId,  Job job,  double pickupDistanceKm,  int commissionAmount,  int ttlSeconds,  DateTime offeredAt)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JobOffer() when $default != null:
return $default(_that.offerId,_that.job,_that.pickupDistanceKm,_that.commissionAmount,_that.ttlSeconds,_that.offeredAt);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String offerId,  Job job,  double pickupDistanceKm,  int commissionAmount,  int ttlSeconds,  DateTime offeredAt)  $default,) {final _that = this;
switch (_that) {
case _JobOffer():
return $default(_that.offerId,_that.job,_that.pickupDistanceKm,_that.commissionAmount,_that.ttlSeconds,_that.offeredAt);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String offerId,  Job job,  double pickupDistanceKm,  int commissionAmount,  int ttlSeconds,  DateTime offeredAt)?  $default,) {final _that = this;
switch (_that) {
case _JobOffer() when $default != null:
return $default(_that.offerId,_that.job,_that.pickupDistanceKm,_that.commissionAmount,_that.ttlSeconds,_that.offeredAt);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JobOffer implements JobOffer {
  const _JobOffer({required this.offerId, required this.job, required this.pickupDistanceKm, required this.commissionAmount, required this.ttlSeconds, required this.offeredAt});
  factory _JobOffer.fromJson(Map<String, dynamic> json) => _$JobOfferFromJson(json);

@override final  String offerId;
@override final  Job job;
@override final  double pickupDistanceKm;
@override final  int commissionAmount;
@override final  int ttlSeconds;
@override final  DateTime offeredAt;

/// Create a copy of JobOffer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobOfferCopyWith<_JobOffer> get copyWith => __$JobOfferCopyWithImpl<_JobOffer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobOfferToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JobOffer&&(identical(other.offerId, offerId) || other.offerId == offerId)&&(identical(other.job, job) || other.job == job)&&(identical(other.pickupDistanceKm, pickupDistanceKm) || other.pickupDistanceKm == pickupDistanceKm)&&(identical(other.commissionAmount, commissionAmount) || other.commissionAmount == commissionAmount)&&(identical(other.ttlSeconds, ttlSeconds) || other.ttlSeconds == ttlSeconds)&&(identical(other.offeredAt, offeredAt) || other.offeredAt == offeredAt));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,offerId,job,pickupDistanceKm,commissionAmount,ttlSeconds,offeredAt);

@override
String toString() {
  return 'JobOffer(offerId: $offerId, job: $job, pickupDistanceKm: $pickupDistanceKm, commissionAmount: $commissionAmount, ttlSeconds: $ttlSeconds, offeredAt: $offeredAt)';
}


}

/// @nodoc
abstract mixin class _$JobOfferCopyWith<$Res> implements $JobOfferCopyWith<$Res> {
  factory _$JobOfferCopyWith(_JobOffer value, $Res Function(_JobOffer) _then) = __$JobOfferCopyWithImpl;
@override @useResult
$Res call({
 String offerId, Job job, double pickupDistanceKm, int commissionAmount, int ttlSeconds, DateTime offeredAt
});


@override $JobCopyWith<$Res> get job;

}
/// @nodoc
class __$JobOfferCopyWithImpl<$Res>
    implements _$JobOfferCopyWith<$Res> {
  __$JobOfferCopyWithImpl(this._self, this._then);

  final _JobOffer _self;
  final $Res Function(_JobOffer) _then;

/// Create a copy of JobOffer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? offerId = null,Object? job = null,Object? pickupDistanceKm = null,Object? commissionAmount = null,Object? ttlSeconds = null,Object? offeredAt = null,}) {
  return _then(_JobOffer(
offerId: null == offerId ? _self.offerId : offerId // ignore: cast_nullable_to_non_nullable
as String,job: null == job ? _self.job : job // ignore: cast_nullable_to_non_nullable
as Job,pickupDistanceKm: null == pickupDistanceKm ? _self.pickupDistanceKm : pickupDistanceKm // ignore: cast_nullable_to_non_nullable
as double,commissionAmount: null == commissionAmount ? _self.commissionAmount : commissionAmount // ignore: cast_nullable_to_non_nullable
as int,ttlSeconds: null == ttlSeconds ? _self.ttlSeconds : ttlSeconds // ignore: cast_nullable_to_non_nullable
as int,offeredAt: null == offeredAt ? _self.offeredAt : offeredAt // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

/// Create a copy of JobOffer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobCopyWith<$Res> get job {
  
  return $JobCopyWith<$Res>(_self.job, (value) {
    return _then(_self.copyWith(job: value));
  });
}
}

// dart format on
