// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_vehicle.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$SavedVehicle {

 String get id; VehicleType get type; String? get make; String? get model; String get plate;
/// Create a copy of SavedVehicle
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedVehicleCopyWith<SavedVehicle> get copyWith => _$SavedVehicleCopyWithImpl<SavedVehicle>(this as SavedVehicle, _$identity);

  /// Serializes this SavedVehicle to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedVehicle&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model)&&(identical(other.plate, plate) || other.plate == plate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,make,model,plate);

@override
String toString() {
  return 'SavedVehicle(id: $id, type: $type, make: $make, model: $model, plate: $plate)';
}


}

/// @nodoc
abstract mixin class $SavedVehicleCopyWith<$Res>  {
  factory $SavedVehicleCopyWith(SavedVehicle value, $Res Function(SavedVehicle) _then) = _$SavedVehicleCopyWithImpl;
@useResult
$Res call({
 String id, VehicleType type, String? make, String? model, String plate
});




}
/// @nodoc
class _$SavedVehicleCopyWithImpl<$Res>
    implements $SavedVehicleCopyWith<$Res> {
  _$SavedVehicleCopyWithImpl(this._self, this._then);

  final SavedVehicle _self;
  final $Res Function(SavedVehicle) _then;

/// Create a copy of SavedVehicle
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? type = null,Object? make = freezed,Object? model = freezed,Object? plate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VehicleType,make: freezed == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedVehicle].
extension SavedVehiclePatterns on SavedVehicle {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedVehicle value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedVehicle() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedVehicle value)  $default,){
final _that = this;
switch (_that) {
case _SavedVehicle():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedVehicle value)?  $default,){
final _that = this;
switch (_that) {
case _SavedVehicle() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  VehicleType type,  String? make,  String? model,  String plate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedVehicle() when $default != null:
return $default(_that.id,_that.type,_that.make,_that.model,_that.plate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  VehicleType type,  String? make,  String? model,  String plate)  $default,) {final _that = this;
switch (_that) {
case _SavedVehicle():
return $default(_that.id,_that.type,_that.make,_that.model,_that.plate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  VehicleType type,  String? make,  String? model,  String plate)?  $default,) {final _that = this;
switch (_that) {
case _SavedVehicle() when $default != null:
return $default(_that.id,_that.type,_that.make,_that.model,_that.plate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SavedVehicle implements SavedVehicle {
  const _SavedVehicle({required this.id, required this.type, this.make, this.model, required this.plate});
  factory _SavedVehicle.fromJson(Map<String, dynamic> json) => _$SavedVehicleFromJson(json);

@override final  String id;
@override final  VehicleType type;
@override final  String? make;
@override final  String? model;
@override final  String plate;

/// Create a copy of SavedVehicle
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedVehicleCopyWith<_SavedVehicle> get copyWith => __$SavedVehicleCopyWithImpl<_SavedVehicle>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SavedVehicleToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedVehicle&&(identical(other.id, id) || other.id == id)&&(identical(other.type, type) || other.type == type)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model)&&(identical(other.plate, plate) || other.plate == plate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,type,make,model,plate);

@override
String toString() {
  return 'SavedVehicle(id: $id, type: $type, make: $make, model: $model, plate: $plate)';
}


}

/// @nodoc
abstract mixin class _$SavedVehicleCopyWith<$Res> implements $SavedVehicleCopyWith<$Res> {
  factory _$SavedVehicleCopyWith(_SavedVehicle value, $Res Function(_SavedVehicle) _then) = __$SavedVehicleCopyWithImpl;
@override @useResult
$Res call({
 String id, VehicleType type, String? make, String? model, String plate
});




}
/// @nodoc
class __$SavedVehicleCopyWithImpl<$Res>
    implements _$SavedVehicleCopyWith<$Res> {
  __$SavedVehicleCopyWithImpl(this._self, this._then);

  final _SavedVehicle _self;
  final $Res Function(_SavedVehicle) _then;

/// Create a copy of SavedVehicle
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? type = null,Object? make = freezed,Object? model = freezed,Object? plate = null,}) {
  return _then(_SavedVehicle(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as VehicleType,make: freezed == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
