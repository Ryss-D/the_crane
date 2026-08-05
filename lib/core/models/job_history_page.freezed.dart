// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'job_history_page.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$JobHistoryPage {

 List<Job> get items; int get total; int get limit; int get offset;
/// Create a copy of JobHistoryPage
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$JobHistoryPageCopyWith<JobHistoryPage> get copyWith => _$JobHistoryPageCopyWithImpl<JobHistoryPage>(this as JobHistoryPage, _$identity);

  /// Serializes this JobHistoryPage to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is JobHistoryPage&&const DeepCollectionEquality().equals(other.items, items)&&(identical(other.total, total) || other.total == total)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(items),total,limit,offset);

@override
String toString() {
  return 'JobHistoryPage(items: $items, total: $total, limit: $limit, offset: $offset)';
}


}

/// @nodoc
abstract mixin class $JobHistoryPageCopyWith<$Res>  {
  factory $JobHistoryPageCopyWith(JobHistoryPage value, $Res Function(JobHistoryPage) _then) = _$JobHistoryPageCopyWithImpl;
@useResult
$Res call({
 List<Job> items, int total, int limit, int offset
});




}
/// @nodoc
class _$JobHistoryPageCopyWithImpl<$Res>
    implements $JobHistoryPageCopyWith<$Res> {
  _$JobHistoryPageCopyWithImpl(this._self, this._then);

  final JobHistoryPage _self;
  final $Res Function(JobHistoryPage) _then;

/// Create a copy of JobHistoryPage
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? items = null,Object? total = null,Object? limit = null,Object? offset = null,}) {
  return _then(_self.copyWith(
items: null == items ? _self.items : items // ignore: cast_nullable_to_non_nullable
as List<Job>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [JobHistoryPage].
extension JobHistoryPagePatterns on JobHistoryPage {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _JobHistoryPage value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _JobHistoryPage() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _JobHistoryPage value)  $default,){
final _that = this;
switch (_that) {
case _JobHistoryPage():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _JobHistoryPage value)?  $default,){
final _that = this;
switch (_that) {
case _JobHistoryPage() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<Job> items,  int total,  int limit,  int offset)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _JobHistoryPage() when $default != null:
return $default(_that.items,_that.total,_that.limit,_that.offset);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<Job> items,  int total,  int limit,  int offset)  $default,) {final _that = this;
switch (_that) {
case _JobHistoryPage():
return $default(_that.items,_that.total,_that.limit,_that.offset);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<Job> items,  int total,  int limit,  int offset)?  $default,) {final _that = this;
switch (_that) {
case _JobHistoryPage() when $default != null:
return $default(_that.items,_that.total,_that.limit,_that.offset);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _JobHistoryPage implements JobHistoryPage {
  const _JobHistoryPage({required final  List<Job> items, required this.total, required this.limit, required this.offset}): _items = items;
  factory _JobHistoryPage.fromJson(Map<String, dynamic> json) => _$JobHistoryPageFromJson(json);

 final  List<Job> _items;
@override List<Job> get items {
  if (_items is EqualUnmodifiableListView) return _items;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_items);
}

@override final  int total;
@override final  int limit;
@override final  int offset;

/// Create a copy of JobHistoryPage
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$JobHistoryPageCopyWith<_JobHistoryPage> get copyWith => __$JobHistoryPageCopyWithImpl<_JobHistoryPage>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$JobHistoryPageToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _JobHistoryPage&&const DeepCollectionEquality().equals(other._items, _items)&&(identical(other.total, total) || other.total == total)&&(identical(other.limit, limit) || other.limit == limit)&&(identical(other.offset, offset) || other.offset == offset));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_items),total,limit,offset);

@override
String toString() {
  return 'JobHistoryPage(items: $items, total: $total, limit: $limit, offset: $offset)';
}


}

/// @nodoc
abstract mixin class _$JobHistoryPageCopyWith<$Res> implements $JobHistoryPageCopyWith<$Res> {
  factory _$JobHistoryPageCopyWith(_JobHistoryPage value, $Res Function(_JobHistoryPage) _then) = __$JobHistoryPageCopyWithImpl;
@override @useResult
$Res call({
 List<Job> items, int total, int limit, int offset
});




}
/// @nodoc
class __$JobHistoryPageCopyWithImpl<$Res>
    implements _$JobHistoryPageCopyWith<$Res> {
  __$JobHistoryPageCopyWithImpl(this._self, this._then);

  final _JobHistoryPage _self;
  final $Res Function(_JobHistoryPage) _then;

/// Create a copy of JobHistoryPage
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? items = null,Object? total = null,Object? limit = null,Object? offset = null,}) {
  return _then(_JobHistoryPage(
items: null == items ? _self._items : items // ignore: cast_nullable_to_non_nullable
as List<Job>,total: null == total ? _self.total : total // ignore: cast_nullable_to_non_nullable
as int,limit: null == limit ? _self.limit : limit // ignore: cast_nullable_to_non_nullable
as int,offset: null == offset ? _self.offset : offset // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
