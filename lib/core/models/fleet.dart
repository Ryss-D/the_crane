import 'package:freezed_annotation/freezed_annotation.dart';

import 'truck.dart';

part 'fleet.freezed.dart';
part 'fleet.g.dart';

/// A fleet owner's fleet (FLT-1), as returned by `POST/GET /v1/fleets/me`:
/// ```
/// {
///   "id": str, "owner_user_id": str, "name": str, "created_at": ISO8601,
///   "trucks": [TruckRead, ...]
/// }
/// ```
/// [trucks] carries the live per-truck `driverStatus`/`driverName` rollup
/// (FLT-3) — see `Truck`'s doc comment.
@freezed
abstract class Fleet with _$Fleet {
  const factory Fleet({
    required String id,
    required String ownerUserId,
    required String name,
    required DateTime createdAt,
    @Default(<Truck>[]) List<Truck> trucks,
  }) = _Fleet;

  factory Fleet.fromJson(Map<String, dynamic> json) => _$FleetFromJson(json);
}

/// One driver's owed balance within a fleet, as returned inside
/// `GET /v1/fleets/me/balance`'s `members` list:
/// `{"driver_id": str, "name": str?, "owed_balance": int}`.
///
/// NOTE on units: despite other money-shaped contracts in this codebase
/// using a `_cents` suffix that's actually plain COP (see `DriverBalance`'s
/// doc comment), this backend field is named `owed_balance` outright and is
/// documented as a plain integer COP amount too — consistent either way,
/// formatted directly via `formatCop`.
@freezed
abstract class FleetMemberBalance with _$FleetMemberBalance {
  const factory FleetMemberBalance({
    required String driverId,
    String? name,
    required int owedBalance,
  }) = _FleetMemberBalance;

  factory FleetMemberBalance.fromJson(Map<String, dynamic> json) =>
      _$FleetMemberBalanceFromJson(json);
}

/// A fleet's consolidated commission balance (FLT-2/FLT-5), as returned by
/// `GET /v1/fleets/me/balance`:
/// ```
/// {"fleet_id": str, "owed_balance": int, "members": [FleetMemberBalance, ...]}
/// ```
@freezed
abstract class FleetBalance with _$FleetBalance {
  const factory FleetBalance({
    required String fleetId,
    required int owedBalance,
    @Default(<FleetMemberBalance>[]) List<FleetMemberBalance> members,
  }) = _FleetBalance;

  factory FleetBalance.fromJson(Map<String, dynamic> json) =>
      _$FleetBalanceFromJson(json);
}

/// FLT-4: a pending invite for a driver who doesn't have a truck (or an
/// account) yet, as returned by both `POST` and `GET /v1/fleets/me/invites`:
/// `{"invite_token": uuid, "truck_id": uuid, "phone": str}`.
///
/// [inviteToken] is what the invited driver passes as `inviteToken` on
/// `DriversRepository.registerDriver` to redeem it and land linked onto
/// [truckId] instead of creating a new truck.
@freezed
abstract class DriverInvite with _$DriverInvite {
  const factory DriverInvite({
    required String inviteToken,
    required String truckId,
    required String phone,
  }) = _DriverInvite;

  factory DriverInvite.fromJson(Map<String, dynamic> json) =>
      _$DriverInviteFromJson(json);
}
