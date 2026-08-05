// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'offer_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ActiveOffer {

 JobOffer get offer; int get remainingSeconds;
/// Create a copy of ActiveOffer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ActiveOfferCopyWith<ActiveOffer> get copyWith => _$ActiveOfferCopyWithImpl<ActiveOffer>(this as ActiveOffer, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ActiveOffer&&(identical(other.offer, offer) || other.offer == offer)&&(identical(other.remainingSeconds, remainingSeconds) || other.remainingSeconds == remainingSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,offer,remainingSeconds);

@override
String toString() {
  return 'ActiveOffer(offer: $offer, remainingSeconds: $remainingSeconds)';
}


}

/// @nodoc
abstract mixin class $ActiveOfferCopyWith<$Res>  {
  factory $ActiveOfferCopyWith(ActiveOffer value, $Res Function(ActiveOffer) _then) = _$ActiveOfferCopyWithImpl;
@useResult
$Res call({
 JobOffer offer, int remainingSeconds
});


$JobOfferCopyWith<$Res> get offer;

}
/// @nodoc
class _$ActiveOfferCopyWithImpl<$Res>
    implements $ActiveOfferCopyWith<$Res> {
  _$ActiveOfferCopyWithImpl(this._self, this._then);

  final ActiveOffer _self;
  final $Res Function(ActiveOffer) _then;

/// Create a copy of ActiveOffer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? offer = null,Object? remainingSeconds = null,}) {
  return _then(_self.copyWith(
offer: null == offer ? _self.offer : offer // ignore: cast_nullable_to_non_nullable
as JobOffer,remainingSeconds: null == remainingSeconds ? _self.remainingSeconds : remainingSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}
/// Create a copy of ActiveOffer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobOfferCopyWith<$Res> get offer {
  
  return $JobOfferCopyWith<$Res>(_self.offer, (value) {
    return _then(_self.copyWith(offer: value));
  });
}
}


/// Adds pattern-matching-related methods to [ActiveOffer].
extension ActiveOfferPatterns on ActiveOffer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ActiveOffer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ActiveOffer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ActiveOffer value)  $default,){
final _that = this;
switch (_that) {
case _ActiveOffer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ActiveOffer value)?  $default,){
final _that = this;
switch (_that) {
case _ActiveOffer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( JobOffer offer,  int remainingSeconds)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ActiveOffer() when $default != null:
return $default(_that.offer,_that.remainingSeconds);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( JobOffer offer,  int remainingSeconds)  $default,) {final _that = this;
switch (_that) {
case _ActiveOffer():
return $default(_that.offer,_that.remainingSeconds);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( JobOffer offer,  int remainingSeconds)?  $default,) {final _that = this;
switch (_that) {
case _ActiveOffer() when $default != null:
return $default(_that.offer,_that.remainingSeconds);case _:
  return null;

}
}

}

/// @nodoc


class _ActiveOffer implements ActiveOffer {
  const _ActiveOffer({required this.offer, required this.remainingSeconds});
  

@override final  JobOffer offer;
@override final  int remainingSeconds;

/// Create a copy of ActiveOffer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ActiveOfferCopyWith<_ActiveOffer> get copyWith => __$ActiveOfferCopyWithImpl<_ActiveOffer>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ActiveOffer&&(identical(other.offer, offer) || other.offer == offer)&&(identical(other.remainingSeconds, remainingSeconds) || other.remainingSeconds == remainingSeconds));
}


@override
int get hashCode => Object.hash(runtimeType,offer,remainingSeconds);

@override
String toString() {
  return 'ActiveOffer(offer: $offer, remainingSeconds: $remainingSeconds)';
}


}

/// @nodoc
abstract mixin class _$ActiveOfferCopyWith<$Res> implements $ActiveOfferCopyWith<$Res> {
  factory _$ActiveOfferCopyWith(_ActiveOffer value, $Res Function(_ActiveOffer) _then) = __$ActiveOfferCopyWithImpl;
@override @useResult
$Res call({
 JobOffer offer, int remainingSeconds
});


@override $JobOfferCopyWith<$Res> get offer;

}
/// @nodoc
class __$ActiveOfferCopyWithImpl<$Res>
    implements _$ActiveOfferCopyWith<$Res> {
  __$ActiveOfferCopyWithImpl(this._self, this._then);

  final _ActiveOffer _self;
  final $Res Function(_ActiveOffer) _then;

/// Create a copy of ActiveOffer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? offer = null,Object? remainingSeconds = null,}) {
  return _then(_ActiveOffer(
offer: null == offer ? _self.offer : offer // ignore: cast_nullable_to_non_nullable
as JobOffer,remainingSeconds: null == remainingSeconds ? _self.remainingSeconds : remainingSeconds // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

/// Create a copy of ActiveOffer
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$JobOfferCopyWith<$Res> get offer {
  
  return $JobOfferCopyWith<$Res>(_self.offer, (value) {
    return _then(_self.copyWith(offer: value));
  });
}
}

// dart format on
