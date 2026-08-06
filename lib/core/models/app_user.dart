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

/// Platform user profile as returned by `POST /v1/auth/sync` / `GET /v1/me`.
///
/// `name`/`phone` are nullable: a fresh phone-only sign-up has no name yet
/// (profile completion asks for it once, post-sign-in) and phone auth is the
/// only source of `phone` server-side.
@freezed
abstract class AppUser with _$AppUser {
  const factory AppUser({
    required String id,
    required String firebaseUid,
    required UserRole role,
    String? name,
    String? phone,
    String? email,
    String? fcmToken,
  }) = _AppUser;

  factory AppUser.fromJson(Map<String, dynamic> json) =>
      _$AppUserFromJson(json);
}
