import 'package:dio/dio.dart';

import '../models/fleet.dart';
import '../models/truck.dart';

/// Fleet-owner operations (FLT-1/2/3/4/5): create/inspect a fleet, attach or
/// detach trucks, and read the consolidated commission balance.
///
/// Implementations: [ApiFleetRepository] (dio → FastAPI) and
/// `FakeFleetRepository`. The composition root in `lib/app/di.dart` picks
/// one from `Env.useFakeBackend`, same as every other repository.
abstract interface class FleetRepository {
  /// `POST /v1/fleets/me` — a signed-in user becomes a fleet owner: creates
  /// the `fleets` row and flips the caller's role to `fleet_owner`
  /// server-side. Throws if the caller already owns a fleet (409).
  Future<Fleet> createFleet({required String name});

  /// `GET /v1/fleets/me` — the caller's fleet plus every truck currently
  /// attached to it (with FLT-3's live `driverStatus`/`driverName`
  /// rollup). Throws if the caller has no fleet yet (404).
  Future<Fleet> getMyFleet();

  /// `GET /v1/fleets/trucks/by-plate/{plate}` (FLT-4) — look up a truck
  /// before attaching it; a fleet owner knows a driver's plate, not their
  /// truck's id. Throws if no truck has that plate (404). The result's
  /// `fleetId` tells the caller whether it's already claimed.
  Future<Truck> findTruckByPlate(String plate);

  /// `POST /v1/fleets/me/trucks/{truckId}` (FLT-4) — attach an unclaimed
  /// truck to the caller's fleet. Throws if the truck doesn't exist (404)
  /// or already belongs to a fleet (409).
  Future<Fleet> attachTruck(String truckId);

  /// `DELETE /v1/fleets/me/trucks/{truckId}` — detach a truck from the
  /// caller's fleet. Throws if it isn't currently a member (404).
  Future<Fleet> detachTruck(String truckId);

  /// `GET /v1/fleets/me/balance` (FLT-2/FLT-5) — consolidated owed balance
  /// across every driver in the fleet, plus the per-driver breakdown.
  Future<FleetBalance> getBalance();

  /// `POST /v1/fleets/me/invites` (FLT-4) — invite a driver who doesn't
  /// have a truck (or an account) yet: pre-provisions the truck and hands
  /// back a token the driver redeems via `DriversRepository.registerDriver`'s
  /// `inviteToken`. Throws if the caller has no fleet (404), [phone]
  /// already has a pending invite (409), or [plate] is already taken (409).
  Future<DriverInvite> createInvite({
    required String phone,
    required String plate,
    required TruckType truckType,
    required TruckCapacity capacity,
  });

  /// `GET /v1/fleets/me/invites` (FLT-4) — the caller's outstanding
  /// (pending, not yet redeemed) invites.
  Future<List<DriverInvite>> listInvites();
}

/// Thrown by [FleetRepository.findTruckByPlate] when no truck has that
/// plate (backend 404). Both implementations throw this exact type so the
/// FLT-4 add-truck flow can show "no truck with that plate" rather than a
/// generic error, regardless of which is wired up.
class TruckNotFoundException implements Exception {}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiFleetRepository implements FleetRepository {
  ApiFleetRepository(this._dio);

  final Dio _dio;

  @override
  Future<Fleet> createFleet({required String name}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/fleets/me',
      data: {'name': name},
    );
    return Fleet.fromJson(res.data!);
  }

  @override
  Future<Fleet> getMyFleet() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/fleets/me');
    return Fleet.fromJson(res.data!);
  }

  @override
  Future<Truck> findTruckByPlate(String plate) async {
    try {
      final res = await _dio
          .get<Map<String, dynamic>>('/v1/fleets/trucks/by-plate/$plate');
      return Truck.fromJson(res.data!);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) throw TruckNotFoundException();
      rethrow;
    }
  }

  @override
  Future<Fleet> attachTruck(String truckId) async {
    final res =
        await _dio.post<Map<String, dynamic>>('/v1/fleets/me/trucks/$truckId');
    return Fleet.fromJson(res.data!);
  }

  @override
  Future<Fleet> detachTruck(String truckId) async {
    final res = await _dio
        .delete<Map<String, dynamic>>('/v1/fleets/me/trucks/$truckId');
    return Fleet.fromJson(res.data!);
  }

  @override
  Future<FleetBalance> getBalance() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/fleets/me/balance');
    return FleetBalance.fromJson(res.data!);
  }

  @override
  Future<DriverInvite> createInvite({
    required String phone,
    required String plate,
    required TruckType truckType,
    required TruckCapacity capacity,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/fleets/me/invites',
      data: {
        'phone': phone,
        'plate': plate,
        'truck_type': truckType.wire,
        'capacity': capacity.wire,
      },
    );
    return DriverInvite.fromJson(res.data!);
  }

  @override
  Future<List<DriverInvite>> listInvites() async {
    final res = await _dio.get<List<dynamic>>('/v1/fleets/me/invites');
    return res.data!
        .map((e) => DriverInvite.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
