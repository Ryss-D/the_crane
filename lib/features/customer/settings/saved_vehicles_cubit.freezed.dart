// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'saved_vehicles_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SavedVehiclesState {

 List<SavedVehicle> get vehicles; bool get isLoading; bool get loadFailed; bool get isSaving;
/// Create a copy of SavedVehiclesState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SavedVehiclesStateCopyWith<SavedVehiclesState> get copyWith => _$SavedVehiclesStateCopyWithImpl<SavedVehiclesState>(this as SavedVehiclesState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SavedVehiclesState&&const DeepCollectionEquality().equals(other.vehicles, vehicles)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(vehicles),isLoading,loadFailed,isSaving);

@override
String toString() {
  return 'SavedVehiclesState(vehicles: $vehicles, isLoading: $isLoading, loadFailed: $loadFailed, isSaving: $isSaving)';
}


}

/// @nodoc
abstract mixin class $SavedVehiclesStateCopyWith<$Res>  {
  factory $SavedVehiclesStateCopyWith(SavedVehiclesState value, $Res Function(SavedVehiclesState) _then) = _$SavedVehiclesStateCopyWithImpl;
@useResult
$Res call({
 List<SavedVehicle> vehicles, bool isLoading, bool loadFailed, bool isSaving
});




}
/// @nodoc
class _$SavedVehiclesStateCopyWithImpl<$Res>
    implements $SavedVehiclesStateCopyWith<$Res> {
  _$SavedVehiclesStateCopyWithImpl(this._self, this._then);

  final SavedVehiclesState _self;
  final $Res Function(SavedVehiclesState) _then;

/// Create a copy of SavedVehiclesState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? vehicles = null,Object? isLoading = null,Object? loadFailed = null,Object? isSaving = null,}) {
  return _then(_self.copyWith(
vehicles: null == vehicles ? _self.vehicles : vehicles // ignore: cast_nullable_to_non_nullable
as List<SavedVehicle>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SavedVehiclesState].
extension SavedVehiclesStatePatterns on SavedVehiclesState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SavedVehiclesState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SavedVehiclesState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SavedVehiclesState value)  $default,){
final _that = this;
switch (_that) {
case _SavedVehiclesState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SavedVehiclesState value)?  $default,){
final _that = this;
switch (_that) {
case _SavedVehiclesState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<SavedVehicle> vehicles,  bool isLoading,  bool loadFailed,  bool isSaving)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SavedVehiclesState() when $default != null:
return $default(_that.vehicles,_that.isLoading,_that.loadFailed,_that.isSaving);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<SavedVehicle> vehicles,  bool isLoading,  bool loadFailed,  bool isSaving)  $default,) {final _that = this;
switch (_that) {
case _SavedVehiclesState():
return $default(_that.vehicles,_that.isLoading,_that.loadFailed,_that.isSaving);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<SavedVehicle> vehicles,  bool isLoading,  bool loadFailed,  bool isSaving)?  $default,) {final _that = this;
switch (_that) {
case _SavedVehiclesState() when $default != null:
return $default(_that.vehicles,_that.isLoading,_that.loadFailed,_that.isSaving);case _:
  return null;

}
}

}

/// @nodoc


class _SavedVehiclesState implements SavedVehiclesState {
  const _SavedVehiclesState({final  List<SavedVehicle> vehicles = const <SavedVehicle>[], this.isLoading = true, this.loadFailed = false, this.isSaving = false}): _vehicles = vehicles;
  

 final  List<SavedVehicle> _vehicles;
@override@JsonKey() List<SavedVehicle> get vehicles {
  if (_vehicles is EqualUnmodifiableListView) return _vehicles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_vehicles);
}

@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool loadFailed;
@override@JsonKey() final  bool isSaving;

/// Create a copy of SavedVehiclesState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SavedVehiclesStateCopyWith<_SavedVehiclesState> get copyWith => __$SavedVehiclesStateCopyWithImpl<_SavedVehiclesState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SavedVehiclesState&&const DeepCollectionEquality().equals(other._vehicles, _vehicles)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed)&&(identical(other.isSaving, isSaving) || other.isSaving == isSaving));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_vehicles),isLoading,loadFailed,isSaving);

@override
String toString() {
  return 'SavedVehiclesState(vehicles: $vehicles, isLoading: $isLoading, loadFailed: $loadFailed, isSaving: $isSaving)';
}


}

/// @nodoc
abstract mixin class _$SavedVehiclesStateCopyWith<$Res> implements $SavedVehiclesStateCopyWith<$Res> {
  factory _$SavedVehiclesStateCopyWith(_SavedVehiclesState value, $Res Function(_SavedVehiclesState) _then) = __$SavedVehiclesStateCopyWithImpl;
@override @useResult
$Res call({
 List<SavedVehicle> vehicles, bool isLoading, bool loadFailed, bool isSaving
});




}
/// @nodoc
class __$SavedVehiclesStateCopyWithImpl<$Res>
    implements _$SavedVehiclesStateCopyWith<$Res> {
  __$SavedVehiclesStateCopyWithImpl(this._self, this._then);

  final _SavedVehiclesState _self;
  final $Res Function(_SavedVehiclesState) _then;

/// Create a copy of SavedVehiclesState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? vehicles = null,Object? isLoading = null,Object? loadFailed = null,Object? isSaving = null,}) {
  return _then(_SavedVehiclesState(
vehicles: null == vehicles ? _self._vehicles : vehicles // ignore: cast_nullable_to_non_nullable
as List<SavedVehicle>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,isSaving: null == isSaving ? _self.isSaving : isSaving // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
