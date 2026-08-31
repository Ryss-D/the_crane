// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'driver_balance.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Settlement {

 String get id; int get amountCents; DateTime get settledAt; String? get note;
/// Create a copy of Settlement
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettlementCopyWith<Settlement> get copyWith => _$SettlementCopyWithImpl<Settlement>(this as Settlement, _$identity);

  /// Serializes this Settlement to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Settlement&&(identical(other.id, id) || other.id == id)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.settledAt, settledAt) || other.settledAt == settledAt)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,amountCents,settledAt,note);

@override
String toString() {
  return 'Settlement(id: $id, amountCents: $amountCents, settledAt: $settledAt, note: $note)';
}


}

/// @nodoc
abstract mixin class $SettlementCopyWith<$Res>  {
  factory $SettlementCopyWith(Settlement value, $Res Function(Settlement) _then) = _$SettlementCopyWithImpl;
@useResult
$Res call({
 String id, int amountCents, DateTime settledAt, String? note
});




}
/// @nodoc
class _$SettlementCopyWithImpl<$Res>
    implements $SettlementCopyWith<$Res> {
  _$SettlementCopyWithImpl(this._self, this._then);

  final Settlement _self;
  final $Res Function(Settlement) _then;

/// Create a copy of Settlement
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? amountCents = null,Object? settledAt = null,Object? note = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,settledAt: null == settledAt ? _self.settledAt : settledAt // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [Settlement].
extension SettlementPatterns on Settlement {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Settlement value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Settlement() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Settlement value)  $default,){
final _that = this;
switch (_that) {
case _Settlement():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Settlement value)?  $default,){
final _that = this;
switch (_that) {
case _Settlement() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  int amountCents,  DateTime settledAt,  String? note)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Settlement() when $default != null:
return $default(_that.id,_that.amountCents,_that.settledAt,_that.note);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  int amountCents,  DateTime settledAt,  String? note)  $default,) {final _that = this;
switch (_that) {
case _Settlement():
return $default(_that.id,_that.amountCents,_that.settledAt,_that.note);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  int amountCents,  DateTime settledAt,  String? note)?  $default,) {final _that = this;
switch (_that) {
case _Settlement() when $default != null:
return $default(_that.id,_that.amountCents,_that.settledAt,_that.note);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Settlement implements Settlement {
  const _Settlement({required this.id, required this.amountCents, required this.settledAt, this.note});
  factory _Settlement.fromJson(Map<String, dynamic> json) => _$SettlementFromJson(json);

@override final  String id;
@override final  int amountCents;
@override final  DateTime settledAt;
@override final  String? note;

/// Create a copy of Settlement
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettlementCopyWith<_Settlement> get copyWith => __$SettlementCopyWithImpl<_Settlement>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SettlementToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Settlement&&(identical(other.id, id) || other.id == id)&&(identical(other.amountCents, amountCents) || other.amountCents == amountCents)&&(identical(other.settledAt, settledAt) || other.settledAt == settledAt)&&(identical(other.note, note) || other.note == note));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,amountCents,settledAt,note);

@override
String toString() {
  return 'Settlement(id: $id, amountCents: $amountCents, settledAt: $settledAt, note: $note)';
}


}

/// @nodoc
abstract mixin class _$SettlementCopyWith<$Res> implements $SettlementCopyWith<$Res> {
  factory _$SettlementCopyWith(_Settlement value, $Res Function(_Settlement) _then) = __$SettlementCopyWithImpl;
@override @useResult
$Res call({
 String id, int amountCents, DateTime settledAt, String? note
});




}
/// @nodoc
class __$SettlementCopyWithImpl<$Res>
    implements _$SettlementCopyWith<$Res> {
  __$SettlementCopyWithImpl(this._self, this._then);

  final _Settlement _self;
  final $Res Function(_Settlement) _then;

/// Create a copy of Settlement
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? amountCents = null,Object? settledAt = null,Object? note = freezed,}) {
  return _then(_Settlement(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,amountCents: null == amountCents ? _self.amountCents : amountCents // ignore: cast_nullable_to_non_nullable
as int,settledAt: null == settledAt ? _self.settledAt : settledAt // ignore: cast_nullable_to_non_nullable
as DateTime,note: freezed == note ? _self.note : note // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$DriverBalance {

 int get owedCents; int? get balanceCapCents; List<Settlement> get recentSettlements;
/// Create a copy of DriverBalance
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$DriverBalanceCopyWith<DriverBalance> get copyWith => _$DriverBalanceCopyWithImpl<DriverBalance>(this as DriverBalance, _$identity);

  /// Serializes this DriverBalance to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is DriverBalance&&(identical(other.owedCents, owedCents) || other.owedCents == owedCents)&&(identical(other.balanceCapCents, balanceCapCents) || other.balanceCapCents == balanceCapCents)&&const DeepCollectionEquality().equals(other.recentSettlements, recentSettlements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,owedCents,balanceCapCents,const DeepCollectionEquality().hash(recentSettlements));

@override
String toString() {
  return 'DriverBalance(owedCents: $owedCents, balanceCapCents: $balanceCapCents, recentSettlements: $recentSettlements)';
}


}

/// @nodoc
abstract mixin class $DriverBalanceCopyWith<$Res>  {
  factory $DriverBalanceCopyWith(DriverBalance value, $Res Function(DriverBalance) _then) = _$DriverBalanceCopyWithImpl;
@useResult
$Res call({
 int owedCents, int? balanceCapCents, List<Settlement> recentSettlements
});




}
/// @nodoc
class _$DriverBalanceCopyWithImpl<$Res>
    implements $DriverBalanceCopyWith<$Res> {
  _$DriverBalanceCopyWithImpl(this._self, this._then);

  final DriverBalance _self;
  final $Res Function(DriverBalance) _then;

/// Create a copy of DriverBalance
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? owedCents = null,Object? balanceCapCents = freezed,Object? recentSettlements = null,}) {
  return _then(_self.copyWith(
owedCents: null == owedCents ? _self.owedCents : owedCents // ignore: cast_nullable_to_non_nullable
as int,balanceCapCents: freezed == balanceCapCents ? _self.balanceCapCents : balanceCapCents // ignore: cast_nullable_to_non_nullable
as int?,recentSettlements: null == recentSettlements ? _self.recentSettlements : recentSettlements // ignore: cast_nullable_to_non_nullable
as List<Settlement>,
  ));
}

}


/// Adds pattern-matching-related methods to [DriverBalance].
extension DriverBalancePatterns on DriverBalance {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _DriverBalance value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _DriverBalance() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _DriverBalance value)  $default,){
final _that = this;
switch (_that) {
case _DriverBalance():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _DriverBalance value)?  $default,){
final _that = this;
switch (_that) {
case _DriverBalance() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( int owedCents,  int? balanceCapCents,  List<Settlement> recentSettlements)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _DriverBalance() when $default != null:
return $default(_that.owedCents,_that.balanceCapCents,_that.recentSettlements);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( int owedCents,  int? balanceCapCents,  List<Settlement> recentSettlements)  $default,) {final _that = this;
switch (_that) {
case _DriverBalance():
return $default(_that.owedCents,_that.balanceCapCents,_that.recentSettlements);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( int owedCents,  int? balanceCapCents,  List<Settlement> recentSettlements)?  $default,) {final _that = this;
switch (_that) {
case _DriverBalance() when $default != null:
return $default(_that.owedCents,_that.balanceCapCents,_that.recentSettlements);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _DriverBalance implements DriverBalance {
  const _DriverBalance({required this.owedCents, this.balanceCapCents, final  List<Settlement> recentSettlements = const <Settlement>[]}): _recentSettlements = recentSettlements;
  factory _DriverBalance.fromJson(Map<String, dynamic> json) => _$DriverBalanceFromJson(json);

@override final  int owedCents;
@override final  int? balanceCapCents;
 final  List<Settlement> _recentSettlements;
@override@JsonKey() List<Settlement> get recentSettlements {
  if (_recentSettlements is EqualUnmodifiableListView) return _recentSettlements;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_recentSettlements);
}


/// Create a copy of DriverBalance
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$DriverBalanceCopyWith<_DriverBalance> get copyWith => __$DriverBalanceCopyWithImpl<_DriverBalance>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$DriverBalanceToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _DriverBalance&&(identical(other.owedCents, owedCents) || other.owedCents == owedCents)&&(identical(other.balanceCapCents, balanceCapCents) || other.balanceCapCents == balanceCapCents)&&const DeepCollectionEquality().equals(other._recentSettlements, _recentSettlements));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,owedCents,balanceCapCents,const DeepCollectionEquality().hash(_recentSettlements));

@override
String toString() {
  return 'DriverBalance(owedCents: $owedCents, balanceCapCents: $balanceCapCents, recentSettlements: $recentSettlements)';
}


}

/// @nodoc
abstract mixin class _$DriverBalanceCopyWith<$Res> implements $DriverBalanceCopyWith<$Res> {
  factory _$DriverBalanceCopyWith(_DriverBalance value, $Res Function(_DriverBalance) _then) = __$DriverBalanceCopyWithImpl;
@override @useResult
$Res call({
 int owedCents, int? balanceCapCents, List<Settlement> recentSettlements
});




}
/// @nodoc
class __$DriverBalanceCopyWithImpl<$Res>
    implements _$DriverBalanceCopyWith<$Res> {
  __$DriverBalanceCopyWithImpl(this._self, this._then);

  final _DriverBalance _self;
  final $Res Function(_DriverBalance) _then;

/// Create a copy of DriverBalance
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? owedCents = null,Object? balanceCapCents = freezed,Object? recentSettlements = null,}) {
  return _then(_DriverBalance(
owedCents: null == owedCents ? _self.owedCents : owedCents // ignore: cast_nullable_to_non_nullable
as int,balanceCapCents: freezed == balanceCapCents ? _self.balanceCapCents : balanceCapCents // ignore: cast_nullable_to_non_nullable
as int?,recentSettlements: null == recentSettlements ? _self._recentSettlements : recentSettlements // ignore: cast_nullable_to_non_nullable
as List<Settlement>,
  ));
}


}

/// @nodoc
mixin _$SettlementCheckout {

 String get paymentReference; String? get asyncPaymentUrl;
/// Create a copy of SettlementCheckout
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SettlementCheckoutCopyWith<SettlementCheckout> get copyWith => _$SettlementCheckoutCopyWithImpl<SettlementCheckout>(this as SettlementCheckout, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SettlementCheckout&&(identical(other.paymentReference, paymentReference) || other.paymentReference == paymentReference)&&(identical(other.asyncPaymentUrl, asyncPaymentUrl) || other.asyncPaymentUrl == asyncPaymentUrl));
}


@override
int get hashCode => Object.hash(runtimeType,paymentReference,asyncPaymentUrl);

@override
String toString() {
  return 'SettlementCheckout(paymentReference: $paymentReference, asyncPaymentUrl: $asyncPaymentUrl)';
}


}

/// @nodoc
abstract mixin class $SettlementCheckoutCopyWith<$Res>  {
  factory $SettlementCheckoutCopyWith(SettlementCheckout value, $Res Function(SettlementCheckout) _then) = _$SettlementCheckoutCopyWithImpl;
@useResult
$Res call({
 String paymentReference, String? asyncPaymentUrl
});




}
/// @nodoc
class _$SettlementCheckoutCopyWithImpl<$Res>
    implements $SettlementCheckoutCopyWith<$Res> {
  _$SettlementCheckoutCopyWithImpl(this._self, this._then);

  final SettlementCheckout _self;
  final $Res Function(SettlementCheckout) _then;

/// Create a copy of SettlementCheckout
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? paymentReference = null,Object? asyncPaymentUrl = freezed,}) {
  return _then(_self.copyWith(
paymentReference: null == paymentReference ? _self.paymentReference : paymentReference // ignore: cast_nullable_to_non_nullable
as String,asyncPaymentUrl: freezed == asyncPaymentUrl ? _self.asyncPaymentUrl : asyncPaymentUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [SettlementCheckout].
extension SettlementCheckoutPatterns on SettlementCheckout {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SettlementCheckout value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SettlementCheckout() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SettlementCheckout value)  $default,){
final _that = this;
switch (_that) {
case _SettlementCheckout():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SettlementCheckout value)?  $default,){
final _that = this;
switch (_that) {
case _SettlementCheckout() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String paymentReference,  String? asyncPaymentUrl)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SettlementCheckout() when $default != null:
return $default(_that.paymentReference,_that.asyncPaymentUrl);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String paymentReference,  String? asyncPaymentUrl)  $default,) {final _that = this;
switch (_that) {
case _SettlementCheckout():
return $default(_that.paymentReference,_that.asyncPaymentUrl);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String paymentReference,  String? asyncPaymentUrl)?  $default,) {final _that = this;
switch (_that) {
case _SettlementCheckout() when $default != null:
return $default(_that.paymentReference,_that.asyncPaymentUrl);case _:
  return null;

}
}

}

/// @nodoc


class _SettlementCheckout implements SettlementCheckout {
  const _SettlementCheckout({required this.paymentReference, this.asyncPaymentUrl});
  

@override final  String paymentReference;
@override final  String? asyncPaymentUrl;

/// Create a copy of SettlementCheckout
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SettlementCheckoutCopyWith<_SettlementCheckout> get copyWith => __$SettlementCheckoutCopyWithImpl<_SettlementCheckout>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SettlementCheckout&&(identical(other.paymentReference, paymentReference) || other.paymentReference == paymentReference)&&(identical(other.asyncPaymentUrl, asyncPaymentUrl) || other.asyncPaymentUrl == asyncPaymentUrl));
}


@override
int get hashCode => Object.hash(runtimeType,paymentReference,asyncPaymentUrl);

@override
String toString() {
  return 'SettlementCheckout(paymentReference: $paymentReference, asyncPaymentUrl: $asyncPaymentUrl)';
}


}

/// @nodoc
abstract mixin class _$SettlementCheckoutCopyWith<$Res> implements $SettlementCheckoutCopyWith<$Res> {
  factory _$SettlementCheckoutCopyWith(_SettlementCheckout value, $Res Function(_SettlementCheckout) _then) = __$SettlementCheckoutCopyWithImpl;
@override @useResult
$Res call({
 String paymentReference, String? asyncPaymentUrl
});




}
/// @nodoc
class __$SettlementCheckoutCopyWithImpl<$Res>
    implements _$SettlementCheckoutCopyWith<$Res> {
  __$SettlementCheckoutCopyWithImpl(this._self, this._then);

  final _SettlementCheckout _self;
  final $Res Function(_SettlementCheckout) _then;

/// Create a copy of SettlementCheckout
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? paymentReference = null,Object? asyncPaymentUrl = freezed,}) {
  return _then(_SettlementCheckout(
paymentReference: null == paymentReference ? _self.paymentReference : paymentReference // ignore: cast_nullable_to_non_nullable
as String,asyncPaymentUrl: freezed == asyncPaymentUrl ? _self.asyncPaymentUrl : asyncPaymentUrl // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
