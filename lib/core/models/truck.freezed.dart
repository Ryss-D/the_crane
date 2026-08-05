// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'truck.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Truck {

 String get id; String? get driverId; String get plate; TruckType get type; TruckCapacity get capacity; String? get make; String? get model;
/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$TruckCopyWith<Truck> get copyWith => _$TruckCopyWithImpl<Truck>(this as Truck, _$identity);

  /// Serializes this Truck to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Truck&&(identical(other.id, id) || other.id == id)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.plate, plate) || other.plate == plate)&&(identical(other.type, type) || other.type == type)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,driverId,plate,type,capacity,make,model);

@override
String toString() {
  return 'Truck(id: $id, driverId: $driverId, plate: $plate, type: $type, capacity: $capacity, make: $make, model: $model)';
}


}

/// @nodoc
abstract mixin class $TruckCopyWith<$Res>  {
  factory $TruckCopyWith(Truck value, $Res Function(Truck) _then) = _$TruckCopyWithImpl;
@useResult
$Res call({
 String id, String? driverId, String plate, TruckType type, TruckCapacity capacity, String? make, String? model
});




}
/// @nodoc
class _$TruckCopyWithImpl<$Res>
    implements $TruckCopyWith<$Res> {
  _$TruckCopyWithImpl(this._self, this._then);

  final Truck _self;
  final $Res Function(Truck) _then;

/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? driverId = freezed,Object? plate = null,Object? type = null,Object? capacity = null,Object? make = freezed,Object? model = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TruckType,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as TruckCapacity,make: freezed == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Truck].
extension TruckPatterns on Truck {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Truck value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Truck() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Truck value)  $default,){
final _that = this;
switch (_that) {
case _Truck():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Truck value)?  $default,){
final _that = this;
switch (_that) {
case _Truck() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? driverId,  String plate,  TruckType type,  TruckCapacity capacity,  String? make,  String? model)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Truck() when $default != null:
return $default(_that.id,_that.driverId,_that.plate,_that.type,_that.capacity,_that.make,_that.model);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? driverId,  String plate,  TruckType type,  TruckCapacity capacity,  String? make,  String? model)  $default,) {final _that = this;
switch (_that) {
case _Truck():
return $default(_that.id,_that.driverId,_that.plate,_that.type,_that.capacity,_that.make,_that.model);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? driverId,  String plate,  TruckType type,  TruckCapacity capacity,  String? make,  String? model)?  $default,) {final _that = this;
switch (_that) {
case _Truck() when $default != null:
return $default(_that.id,_that.driverId,_that.plate,_that.type,_that.capacity,_that.make,_that.model);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Truck implements Truck {
  const _Truck({required this.id, this.driverId, required this.plate, required this.type, required this.capacity, this.make, this.model});
  factory _Truck.fromJson(Map<String, dynamic> json) => _$TruckFromJson(json);

@override final  String id;
@override final  String? driverId;
@override final  String plate;
@override final  TruckType type;
@override final  TruckCapacity capacity;
@override final  String? make;
@override final  String? model;

/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$TruckCopyWith<_Truck> get copyWith => __$TruckCopyWithImpl<_Truck>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$TruckToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Truck&&(identical(other.id, id) || other.id == id)&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.plate, plate) || other.plate == plate)&&(identical(other.type, type) || other.type == type)&&(identical(other.capacity, capacity) || other.capacity == capacity)&&(identical(other.make, make) || other.make == make)&&(identical(other.model, model) || other.model == model));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,driverId,plate,type,capacity,make,model);

@override
String toString() {
  return 'Truck(id: $id, driverId: $driverId, plate: $plate, type: $type, capacity: $capacity, make: $make, model: $model)';
}


}

/// @nodoc
abstract mixin class _$TruckCopyWith<$Res> implements $TruckCopyWith<$Res> {
  factory _$TruckCopyWith(_Truck value, $Res Function(_Truck) _then) = __$TruckCopyWithImpl;
@override @useResult
$Res call({
 String id, String? driverId, String plate, TruckType type, TruckCapacity capacity, String? make, String? model
});




}
/// @nodoc
class __$TruckCopyWithImpl<$Res>
    implements _$TruckCopyWith<$Res> {
  __$TruckCopyWithImpl(this._self, this._then);

  final _Truck _self;
  final $Res Function(_Truck) _then;

/// Create a copy of Truck
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? driverId = freezed,Object? plate = null,Object? type = null,Object? capacity = null,Object? make = freezed,Object? model = freezed,}) {
  return _then(_Truck(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,driverId: freezed == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String?,plate: null == plate ? _self.plate : plate // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as TruckType,capacity: null == capacity ? _self.capacity : capacity // ignore: cast_nullable_to_non_nullable
as TruckCapacity,make: freezed == make ? _self.make : make // ignore: cast_nullable_to_non_nullable
as String?,model: freezed == model ? _self.model : model // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
