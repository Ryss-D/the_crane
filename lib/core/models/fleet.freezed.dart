// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'fleet.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Fleet {

 String get id; String get ownerUserId; String get name; DateTime get createdAt; List<Truck> get trucks;
/// Create a copy of Fleet
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FleetCopyWith<Fleet> get copyWith => _$FleetCopyWithImpl<Fleet>(this as Fleet, _$identity);

  /// Serializes this Fleet to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Fleet&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerUserId, ownerUserId) || other.ownerUserId == ownerUserId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other.trucks, trucks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ownerUserId,name,createdAt,const DeepCollectionEquality().hash(trucks));

@override
String toString() {
  return 'Fleet(id: $id, ownerUserId: $ownerUserId, name: $name, createdAt: $createdAt, trucks: $trucks)';
}


}

/// @nodoc
abstract mixin class $FleetCopyWith<$Res>  {
  factory $FleetCopyWith(Fleet value, $Res Function(Fleet) _then) = _$FleetCopyWithImpl;
@useResult
$Res call({
 String id, String ownerUserId, String name, DateTime createdAt, List<Truck> trucks
});




}
/// @nodoc
class _$FleetCopyWithImpl<$Res>
    implements $FleetCopyWith<$Res> {
  _$FleetCopyWithImpl(this._self, this._then);

  final Fleet _self;
  final $Res Function(Fleet) _then;

/// Create a copy of Fleet
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? ownerUserId = null,Object? name = null,Object? createdAt = null,Object? trucks = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerUserId: null == ownerUserId ? _self.ownerUserId : ownerUserId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,trucks: null == trucks ? _self.trucks : trucks // ignore: cast_nullable_to_non_nullable
as List<Truck>,
  ));
}

}


/// Adds pattern-matching-related methods to [Fleet].
extension FleetPatterns on Fleet {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Fleet value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Fleet() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Fleet value)  $default,){
final _that = this;
switch (_that) {
case _Fleet():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Fleet value)?  $default,){
final _that = this;
switch (_that) {
case _Fleet() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String ownerUserId,  String name,  DateTime createdAt,  List<Truck> trucks)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Fleet() when $default != null:
return $default(_that.id,_that.ownerUserId,_that.name,_that.createdAt,_that.trucks);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String ownerUserId,  String name,  DateTime createdAt,  List<Truck> trucks)  $default,) {final _that = this;
switch (_that) {
case _Fleet():
return $default(_that.id,_that.ownerUserId,_that.name,_that.createdAt,_that.trucks);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String ownerUserId,  String name,  DateTime createdAt,  List<Truck> trucks)?  $default,) {final _that = this;
switch (_that) {
case _Fleet() when $default != null:
return $default(_that.id,_that.ownerUserId,_that.name,_that.createdAt,_that.trucks);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Fleet implements Fleet {
  const _Fleet({required this.id, required this.ownerUserId, required this.name, required this.createdAt, final  List<Truck> trucks = const <Truck>[]}): _trucks = trucks;
  factory _Fleet.fromJson(Map<String, dynamic> json) => _$FleetFromJson(json);

@override final  String id;
@override final  String ownerUserId;
@override final  String name;
@override final  DateTime createdAt;
 final  List<Truck> _trucks;
@override@JsonKey() List<Truck> get trucks {
  if (_trucks is EqualUnmodifiableListView) return _trucks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trucks);
}


/// Create a copy of Fleet
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FleetCopyWith<_Fleet> get copyWith => __$FleetCopyWithImpl<_Fleet>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FleetToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Fleet&&(identical(other.id, id) || other.id == id)&&(identical(other.ownerUserId, ownerUserId) || other.ownerUserId == ownerUserId)&&(identical(other.name, name) || other.name == name)&&(identical(other.createdAt, createdAt) || other.createdAt == createdAt)&&const DeepCollectionEquality().equals(other._trucks, _trucks));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,ownerUserId,name,createdAt,const DeepCollectionEquality().hash(_trucks));

@override
String toString() {
  return 'Fleet(id: $id, ownerUserId: $ownerUserId, name: $name, createdAt: $createdAt, trucks: $trucks)';
}


}

/// @nodoc
abstract mixin class _$FleetCopyWith<$Res> implements $FleetCopyWith<$Res> {
  factory _$FleetCopyWith(_Fleet value, $Res Function(_Fleet) _then) = __$FleetCopyWithImpl;
@override @useResult
$Res call({
 String id, String ownerUserId, String name, DateTime createdAt, List<Truck> trucks
});




}
/// @nodoc
class __$FleetCopyWithImpl<$Res>
    implements _$FleetCopyWith<$Res> {
  __$FleetCopyWithImpl(this._self, this._then);

  final _Fleet _self;
  final $Res Function(_Fleet) _then;

/// Create a copy of Fleet
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? ownerUserId = null,Object? name = null,Object? createdAt = null,Object? trucks = null,}) {
  return _then(_Fleet(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,ownerUserId: null == ownerUserId ? _self.ownerUserId : ownerUserId // ignore: cast_nullable_to_non_nullable
as String,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,createdAt: null == createdAt ? _self.createdAt : createdAt // ignore: cast_nullable_to_non_nullable
as DateTime,trucks: null == trucks ? _self._trucks : trucks // ignore: cast_nullable_to_non_nullable
as List<Truck>,
  ));
}


}


/// @nodoc
mixin _$FleetMemberBalance {

 String get driverId; String? get name; int get owedBalance;
/// Create a copy of FleetMemberBalance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FleetMemberBalanceCopyWith<FleetMemberBalance> get copyWith => _$FleetMemberBalanceCopyWithImpl<FleetMemberBalance>(this as FleetMemberBalance, _$identity);

  /// Serializes this FleetMemberBalance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FleetMemberBalance&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.owedBalance, owedBalance) || other.owedBalance == owedBalance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,driverId,name,owedBalance);

@override
String toString() {
  return 'FleetMemberBalance(driverId: $driverId, name: $name, owedBalance: $owedBalance)';
}


}

/// @nodoc
abstract mixin class $FleetMemberBalanceCopyWith<$Res>  {
  factory $FleetMemberBalanceCopyWith(FleetMemberBalance value, $Res Function(FleetMemberBalance) _then) = _$FleetMemberBalanceCopyWithImpl;
@useResult
$Res call({
 String driverId, String? name, int owedBalance
});




}
/// @nodoc
class _$FleetMemberBalanceCopyWithImpl<$Res>
    implements $FleetMemberBalanceCopyWith<$Res> {
  _$FleetMemberBalanceCopyWithImpl(this._self, this._then);

  final FleetMemberBalance _self;
  final $Res Function(FleetMemberBalance) _then;

/// Create a copy of FleetMemberBalance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? driverId = null,Object? name = freezed,Object? owedBalance = null,}) {
  return _then(_self.copyWith(
driverId: null == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,owedBalance: null == owedBalance ? _self.owedBalance : owedBalance // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [FleetMemberBalance].
extension FleetMemberBalancePatterns on FleetMemberBalance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FleetMemberBalance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FleetMemberBalance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FleetMemberBalance value)  $default,){
final _that = this;
switch (_that) {
case _FleetMemberBalance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FleetMemberBalance value)?  $default,){
final _that = this;
switch (_that) {
case _FleetMemberBalance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String driverId,  String? name,  int owedBalance)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FleetMemberBalance() when $default != null:
return $default(_that.driverId,_that.name,_that.owedBalance);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String driverId,  String? name,  int owedBalance)  $default,) {final _that = this;
switch (_that) {
case _FleetMemberBalance():
return $default(_that.driverId,_that.name,_that.owedBalance);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String driverId,  String? name,  int owedBalance)?  $default,) {final _that = this;
switch (_that) {
case _FleetMemberBalance() when $default != null:
return $default(_that.driverId,_that.name,_that.owedBalance);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FleetMemberBalance implements FleetMemberBalance {
  const _FleetMemberBalance({required this.driverId, this.name, required this.owedBalance});
  factory _FleetMemberBalance.fromJson(Map<String, dynamic> json) => _$FleetMemberBalanceFromJson(json);

@override final  String driverId;
@override final  String? name;
@override final  int owedBalance;

/// Create a copy of FleetMemberBalance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FleetMemberBalanceCopyWith<_FleetMemberBalance> get copyWith => __$FleetMemberBalanceCopyWithImpl<_FleetMemberBalance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FleetMemberBalanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FleetMemberBalance&&(identical(other.driverId, driverId) || other.driverId == driverId)&&(identical(other.name, name) || other.name == name)&&(identical(other.owedBalance, owedBalance) || other.owedBalance == owedBalance));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,driverId,name,owedBalance);

@override
String toString() {
  return 'FleetMemberBalance(driverId: $driverId, name: $name, owedBalance: $owedBalance)';
}


}

/// @nodoc
abstract mixin class _$FleetMemberBalanceCopyWith<$Res> implements $FleetMemberBalanceCopyWith<$Res> {
  factory _$FleetMemberBalanceCopyWith(_FleetMemberBalance value, $Res Function(_FleetMemberBalance) _then) = __$FleetMemberBalanceCopyWithImpl;
@override @useResult
$Res call({
 String driverId, String? name, int owedBalance
});




}
/// @nodoc
class __$FleetMemberBalanceCopyWithImpl<$Res>
    implements _$FleetMemberBalanceCopyWith<$Res> {
  __$FleetMemberBalanceCopyWithImpl(this._self, this._then);

  final _FleetMemberBalance _self;
  final $Res Function(_FleetMemberBalance) _then;

/// Create a copy of FleetMemberBalance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? driverId = null,Object? name = freezed,Object? owedBalance = null,}) {
  return _then(_FleetMemberBalance(
driverId: null == driverId ? _self.driverId : driverId // ignore: cast_nullable_to_non_nullable
as String,name: freezed == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String?,owedBalance: null == owedBalance ? _self.owedBalance : owedBalance // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}


/// @nodoc
mixin _$FleetBalance {

 String get fleetId; int get owedBalance; List<FleetMemberBalance> get members;
/// Create a copy of FleetBalance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$FleetBalanceCopyWith<FleetBalance> get copyWith => _$FleetBalanceCopyWithImpl<FleetBalance>(this as FleetBalance, _$identity);

  /// Serializes this FleetBalance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is FleetBalance&&(identical(other.fleetId, fleetId) || other.fleetId == fleetId)&&(identical(other.owedBalance, owedBalance) || other.owedBalance == owedBalance)&&const DeepCollectionEquality().equals(other.members, members));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fleetId,owedBalance,const DeepCollectionEquality().hash(members));

@override
String toString() {
  return 'FleetBalance(fleetId: $fleetId, owedBalance: $owedBalance, members: $members)';
}


}

/// @nodoc
abstract mixin class $FleetBalanceCopyWith<$Res>  {
  factory $FleetBalanceCopyWith(FleetBalance value, $Res Function(FleetBalance) _then) = _$FleetBalanceCopyWithImpl;
@useResult
$Res call({
 String fleetId, int owedBalance, List<FleetMemberBalance> members
});




}
/// @nodoc
class _$FleetBalanceCopyWithImpl<$Res>
    implements $FleetBalanceCopyWith<$Res> {
  _$FleetBalanceCopyWithImpl(this._self, this._then);

  final FleetBalance _self;
  final $Res Function(FleetBalance) _then;

/// Create a copy of FleetBalance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? fleetId = null,Object? owedBalance = null,Object? members = null,}) {
  return _then(_self.copyWith(
fleetId: null == fleetId ? _self.fleetId : fleetId // ignore: cast_nullable_to_non_nullable
as String,owedBalance: null == owedBalance ? _self.owedBalance : owedBalance // ignore: cast_nullable_to_non_nullable
as int,members: null == members ? _self.members : members // ignore: cast_nullable_to_non_nullable
as List<FleetMemberBalance>,
  ));
}

}


/// Adds pattern-matching-related methods to [FleetBalance].
extension FleetBalancePatterns on FleetBalance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _FleetBalance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _FleetBalance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _FleetBalance value)  $default,){
final _that = this;
switch (_that) {
case _FleetBalance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _FleetBalance value)?  $default,){
final _that = this;
switch (_that) {
case _FleetBalance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String fleetId,  int owedBalance,  List<FleetMemberBalance> members)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _FleetBalance() when $default != null:
return $default(_that.fleetId,_that.owedBalance,_that.members);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String fleetId,  int owedBalance,  List<FleetMemberBalance> members)  $default,) {final _that = this;
switch (_that) {
case _FleetBalance():
return $default(_that.fleetId,_that.owedBalance,_that.members);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String fleetId,  int owedBalance,  List<FleetMemberBalance> members)?  $default,) {final _that = this;
switch (_that) {
case _FleetBalance() when $default != null:
return $default(_that.fleetId,_that.owedBalance,_that.members);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _FleetBalance implements FleetBalance {
  const _FleetBalance({required this.fleetId, required this.owedBalance, final  List<FleetMemberBalance> members = const <FleetMemberBalance>[]}): _members = members;
  factory _FleetBalance.fromJson(Map<String, dynamic> json) => _$FleetBalanceFromJson(json);

@override final  String fleetId;
@override final  int owedBalance;
 final  List<FleetMemberBalance> _members;
@override@JsonKey() List<FleetMemberBalance> get members {
  if (_members is EqualUnmodifiableListView) return _members;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_members);
}


/// Create a copy of FleetBalance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$FleetBalanceCopyWith<_FleetBalance> get copyWith => __$FleetBalanceCopyWithImpl<_FleetBalance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$FleetBalanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _FleetBalance&&(identical(other.fleetId, fleetId) || other.fleetId == fleetId)&&(identical(other.owedBalance, owedBalance) || other.owedBalance == owedBalance)&&const DeepCollectionEquality().equals(other._members, _members));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,fleetId,owedBalance,const DeepCollectionEquality().hash(_members));

@override
String toString() {
  return 'FleetBalance(fleetId: $fleetId, owedBalance: $owedBalance, members: $members)';
}


}

/// @nodoc
abstract mixin class _$FleetBalanceCopyWith<$Res> implements $FleetBalanceCopyWith<$Res> {
  factory _$FleetBalanceCopyWith(_FleetBalance value, $Res Function(_FleetBalance) _then) = __$FleetBalanceCopyWithImpl;
@override @useResult
$Res call({
 String fleetId, int owedBalance, List<FleetMemberBalance> members
});




}
/// @nodoc
class __$FleetBalanceCopyWithImpl<$Res>
    implements _$FleetBalanceCopyWith<$Res> {
  __$FleetBalanceCopyWithImpl(this._self, this._then);

  final _FleetBalance _self;
  final $Res Function(_FleetBalance) _then;

/// Create a copy of FleetBalance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? fleetId = null,Object? owedBalance = null,Object? members = null,}) {
  return _then(_FleetBalance(
fleetId: null == fleetId ? _self.fleetId : fleetId // ignore: cast_nullable_to_non_nullable
as String,owedBalance: null == owedBalance ? _self.owedBalance : owedBalance // ignore: cast_nullable_to_non_nullable
as int,members: null == members ? _self._members : members // ignore: cast_nullable_to_non_nullable
as List<FleetMemberBalance>,
  ));
}


}

// dart format on
