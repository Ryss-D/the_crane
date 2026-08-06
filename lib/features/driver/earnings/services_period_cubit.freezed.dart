// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'services_period_cubit.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$ServicesPeriodSummary {

 DateTime get day; int get jobCount; int get totalFare; int get totalCommission;
/// Create a copy of ServicesPeriodSummary
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServicesPeriodSummaryCopyWith<ServicesPeriodSummary> get copyWith => _$ServicesPeriodSummaryCopyWithImpl<ServicesPeriodSummary>(this as ServicesPeriodSummary, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServicesPeriodSummary&&(identical(other.day, day) || other.day == day)&&(identical(other.jobCount, jobCount) || other.jobCount == jobCount)&&(identical(other.totalFare, totalFare) || other.totalFare == totalFare)&&(identical(other.totalCommission, totalCommission) || other.totalCommission == totalCommission));
}


@override
int get hashCode => Object.hash(runtimeType,day,jobCount,totalFare,totalCommission);

@override
String toString() {
  return 'ServicesPeriodSummary(day: $day, jobCount: $jobCount, totalFare: $totalFare, totalCommission: $totalCommission)';
}


}

/// @nodoc
abstract mixin class $ServicesPeriodSummaryCopyWith<$Res>  {
  factory $ServicesPeriodSummaryCopyWith(ServicesPeriodSummary value, $Res Function(ServicesPeriodSummary) _then) = _$ServicesPeriodSummaryCopyWithImpl;
@useResult
$Res call({
 DateTime day, int jobCount, int totalFare, int totalCommission
});




}
/// @nodoc
class _$ServicesPeriodSummaryCopyWithImpl<$Res>
    implements $ServicesPeriodSummaryCopyWith<$Res> {
  _$ServicesPeriodSummaryCopyWithImpl(this._self, this._then);

  final ServicesPeriodSummary _self;
  final $Res Function(ServicesPeriodSummary) _then;

/// Create a copy of ServicesPeriodSummary
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? day = null,Object? jobCount = null,Object? totalFare = null,Object? totalCommission = null,}) {
  return _then(_self.copyWith(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,jobCount: null == jobCount ? _self.jobCount : jobCount // ignore: cast_nullable_to_non_nullable
as int,totalFare: null == totalFare ? _self.totalFare : totalFare // ignore: cast_nullable_to_non_nullable
as int,totalCommission: null == totalCommission ? _self.totalCommission : totalCommission // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [ServicesPeriodSummary].
extension ServicesPeriodSummaryPatterns on ServicesPeriodSummary {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServicesPeriodSummary value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServicesPeriodSummary() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServicesPeriodSummary value)  $default,){
final _that = this;
switch (_that) {
case _ServicesPeriodSummary():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServicesPeriodSummary value)?  $default,){
final _that = this;
switch (_that) {
case _ServicesPeriodSummary() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( DateTime day,  int jobCount,  int totalFare,  int totalCommission)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServicesPeriodSummary() when $default != null:
return $default(_that.day,_that.jobCount,_that.totalFare,_that.totalCommission);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( DateTime day,  int jobCount,  int totalFare,  int totalCommission)  $default,) {final _that = this;
switch (_that) {
case _ServicesPeriodSummary():
return $default(_that.day,_that.jobCount,_that.totalFare,_that.totalCommission);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( DateTime day,  int jobCount,  int totalFare,  int totalCommission)?  $default,) {final _that = this;
switch (_that) {
case _ServicesPeriodSummary() when $default != null:
return $default(_that.day,_that.jobCount,_that.totalFare,_that.totalCommission);case _:
  return null;

}
}

}

/// @nodoc


class _ServicesPeriodSummary implements ServicesPeriodSummary {
  const _ServicesPeriodSummary({required this.day, required this.jobCount, required this.totalFare, required this.totalCommission});
  

@override final  DateTime day;
@override final  int jobCount;
@override final  int totalFare;
@override final  int totalCommission;

/// Create a copy of ServicesPeriodSummary
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServicesPeriodSummaryCopyWith<_ServicesPeriodSummary> get copyWith => __$ServicesPeriodSummaryCopyWithImpl<_ServicesPeriodSummary>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServicesPeriodSummary&&(identical(other.day, day) || other.day == day)&&(identical(other.jobCount, jobCount) || other.jobCount == jobCount)&&(identical(other.totalFare, totalFare) || other.totalFare == totalFare)&&(identical(other.totalCommission, totalCommission) || other.totalCommission == totalCommission));
}


@override
int get hashCode => Object.hash(runtimeType,day,jobCount,totalFare,totalCommission);

@override
String toString() {
  return 'ServicesPeriodSummary(day: $day, jobCount: $jobCount, totalFare: $totalFare, totalCommission: $totalCommission)';
}


}

/// @nodoc
abstract mixin class _$ServicesPeriodSummaryCopyWith<$Res> implements $ServicesPeriodSummaryCopyWith<$Res> {
  factory _$ServicesPeriodSummaryCopyWith(_ServicesPeriodSummary value, $Res Function(_ServicesPeriodSummary) _then) = __$ServicesPeriodSummaryCopyWithImpl;
@override @useResult
$Res call({
 DateTime day, int jobCount, int totalFare, int totalCommission
});




}
/// @nodoc
class __$ServicesPeriodSummaryCopyWithImpl<$Res>
    implements _$ServicesPeriodSummaryCopyWith<$Res> {
  __$ServicesPeriodSummaryCopyWithImpl(this._self, this._then);

  final _ServicesPeriodSummary _self;
  final $Res Function(_ServicesPeriodSummary) _then;

/// Create a copy of ServicesPeriodSummary
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? day = null,Object? jobCount = null,Object? totalFare = null,Object? totalCommission = null,}) {
  return _then(_ServicesPeriodSummary(
day: null == day ? _self.day : day // ignore: cast_nullable_to_non_nullable
as DateTime,jobCount: null == jobCount ? _self.jobCount : jobCount // ignore: cast_nullable_to_non_nullable
as int,totalFare: null == totalFare ? _self.totalFare : totalFare // ignore: cast_nullable_to_non_nullable
as int,totalCommission: null == totalCommission ? _self.totalCommission : totalCommission // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

/// @nodoc
mixin _$ServicesPeriodState {

 List<ServicesPeriodSummary> get periods; bool get isLoading; bool get loadFailed;
/// Create a copy of ServicesPeriodState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServicesPeriodStateCopyWith<ServicesPeriodState> get copyWith => _$ServicesPeriodStateCopyWithImpl<ServicesPeriodState>(this as ServicesPeriodState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServicesPeriodState&&const DeepCollectionEquality().equals(other.periods, periods)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(periods),isLoading,loadFailed);

@override
String toString() {
  return 'ServicesPeriodState(periods: $periods, isLoading: $isLoading, loadFailed: $loadFailed)';
}


}

/// @nodoc
abstract mixin class $ServicesPeriodStateCopyWith<$Res>  {
  factory $ServicesPeriodStateCopyWith(ServicesPeriodState value, $Res Function(ServicesPeriodState) _then) = _$ServicesPeriodStateCopyWithImpl;
@useResult
$Res call({
 List<ServicesPeriodSummary> periods, bool isLoading, bool loadFailed
});




}
/// @nodoc
class _$ServicesPeriodStateCopyWithImpl<$Res>
    implements $ServicesPeriodStateCopyWith<$Res> {
  _$ServicesPeriodStateCopyWithImpl(this._self, this._then);

  final ServicesPeriodState _self;
  final $Res Function(ServicesPeriodState) _then;

/// Create a copy of ServicesPeriodState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? periods = null,Object? isLoading = null,Object? loadFailed = null,}) {
  return _then(_self.copyWith(
periods: null == periods ? _self.periods : periods // ignore: cast_nullable_to_non_nullable
as List<ServicesPeriodSummary>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [ServicesPeriodState].
extension ServicesPeriodStatePatterns on ServicesPeriodState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServicesPeriodState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServicesPeriodState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServicesPeriodState value)  $default,){
final _that = this;
switch (_that) {
case _ServicesPeriodState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServicesPeriodState value)?  $default,){
final _that = this;
switch (_that) {
case _ServicesPeriodState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<ServicesPeriodSummary> periods,  bool isLoading,  bool loadFailed)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServicesPeriodState() when $default != null:
return $default(_that.periods,_that.isLoading,_that.loadFailed);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<ServicesPeriodSummary> periods,  bool isLoading,  bool loadFailed)  $default,) {final _that = this;
switch (_that) {
case _ServicesPeriodState():
return $default(_that.periods,_that.isLoading,_that.loadFailed);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<ServicesPeriodSummary> periods,  bool isLoading,  bool loadFailed)?  $default,) {final _that = this;
switch (_that) {
case _ServicesPeriodState() when $default != null:
return $default(_that.periods,_that.isLoading,_that.loadFailed);case _:
  return null;

}
}

}

/// @nodoc


class _ServicesPeriodState implements ServicesPeriodState {
  const _ServicesPeriodState({final  List<ServicesPeriodSummary> periods = const <ServicesPeriodSummary>[], this.isLoading = true, this.loadFailed = false}): _periods = periods;
  

 final  List<ServicesPeriodSummary> _periods;
@override@JsonKey() List<ServicesPeriodSummary> get periods {
  if (_periods is EqualUnmodifiableListView) return _periods;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_periods);
}

@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool loadFailed;

/// Create a copy of ServicesPeriodState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServicesPeriodStateCopyWith<_ServicesPeriodState> get copyWith => __$ServicesPeriodStateCopyWithImpl<_ServicesPeriodState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServicesPeriodState&&const DeepCollectionEquality().equals(other._periods, _periods)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.loadFailed, loadFailed) || other.loadFailed == loadFailed));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_periods),isLoading,loadFailed);

@override
String toString() {
  return 'ServicesPeriodState(periods: $periods, isLoading: $isLoading, loadFailed: $loadFailed)';
}


}

/// @nodoc
abstract mixin class _$ServicesPeriodStateCopyWith<$Res> implements $ServicesPeriodStateCopyWith<$Res> {
  factory _$ServicesPeriodStateCopyWith(_ServicesPeriodState value, $Res Function(_ServicesPeriodState) _then) = __$ServicesPeriodStateCopyWithImpl;
@override @useResult
$Res call({
 List<ServicesPeriodSummary> periods, bool isLoading, bool loadFailed
});




}
/// @nodoc
class __$ServicesPeriodStateCopyWithImpl<$Res>
    implements _$ServicesPeriodStateCopyWith<$Res> {
  __$ServicesPeriodStateCopyWithImpl(this._self, this._then);

  final _ServicesPeriodState _self;
  final $Res Function(_ServicesPeriodState) _then;

/// Create a copy of ServicesPeriodState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? periods = null,Object? isLoading = null,Object? loadFailed = null,}) {
  return _then(_ServicesPeriodState(
periods: null == periods ? _self._periods : periods // ignore: cast_nullable_to_non_nullable
as List<ServicesPeriodSummary>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,loadFailed: null == loadFailed ? _self.loadFailed : loadFailed // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
