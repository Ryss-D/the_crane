// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_user.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_AppUser _$AppUserFromJson(Map<String, dynamic> json) => _AppUser(
  id: json['id'] as String,
  firebaseUid: json['firebase_uid'] as String,
  role: $enumDecode(_$UserRoleEnumMap, json['role']),
  name: json['name'] as String?,
  phone: json['phone'] as String?,
  email: json['email'] as String?,
  fcmToken: json['fcm_token'] as String?,
);

Map<String, dynamic> _$AppUserToJson(_AppUser instance) => <String, dynamic>{
  'id': instance.id,
  'firebase_uid': instance.firebaseUid,
  'role': _$UserRoleEnumMap[instance.role]!,
  'name': instance.name,
  'phone': instance.phone,
  'email': instance.email,
  'fcm_token': instance.fcmToken,
};

const _$UserRoleEnumMap = {
  UserRole.customer: 'customer',
  UserRole.driver: 'driver',
  UserRole.admin: 'admin',
  UserRole.fleetOwner: 'fleet_owner',
};
