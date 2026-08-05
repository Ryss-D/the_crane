import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_user.freezed.dart';
part 'app_user.g.dart';

/// Role of a platform user. Mirrors the backend `users.role` column.
@JsonEnum(fieldRename: FieldRename.snake)
enum UserRole {
  customer,
  driver,
  admin,
  fleetOwner,
}

/// Platform user profile as returned by `GET /v1/me`.
///
/// Serves as the working freezed + json_serializable codegen example;
/// model files follow this pattern (run `dart run build_runner build`).
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String firebaseUid,
    required UserRole role,
    required String name,
    required String phone,
    String? email,
    String? fcmToken,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
