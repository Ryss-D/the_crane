import 'package:dio/dio.dart';

import '../models/driver_balance.dart';
import '../models/driver_profile.dart';
import '../models/job.dart';
import '../models/job_offer.dart';
import '../models/truck.dart';
import '../ws/crane_socket.dart';
import '../ws/server_message.dart';

/// Driver-side operations (availability, incoming offers).
///
/// Implementations: [ApiDriversRepository] (dio → FastAPI) and
/// `FakeDriversRepository`. The composition root in `lib/app/di.dart`
/// picks one from `Env.useFakeBackend`.
abstract interface class DriversRepository {
  /// `POST /v1/drivers/me/register` (AUTH-5) — a signed-in customer becomes
  /// a driver: creates the `driver_profiles` + `trucks` rows server-side and
  /// flips the caller's role to `driver` (unverified, offline until an
  /// admin verifies it). Document upload is out of scope — `licenseUrl`/
  /// `truckPhotoUrl` are plain strings, same as the backend schema.
  ///
  /// Two mutually exclusive shapes (FLT-4): bring your own truck
  /// ([plate]/[truckType]/[capacity], all three required), or redeem a
  /// fleet owner's invite ([inviteToken] from
  /// `FleetRepository.createInvite`), which already pre-provisioned the
  /// truck — [plate]/[truckType]/[capacity] must be left null in that case.
  /// The backend 422s if both shapes are mixed.
  Future<DriverProfile> registerDriver({
    String? plate,
    TruckType? truckType,
    TruckCapacity? capacity,
    String? inviteToken,
    String? licenseUrl,
    String? truckPhotoUrl,
  });

  /// `PATCH /v1/drivers/me/status` — go available/offline. The backend
  /// requires [lat]/[lng] when [status] is `available` (422 otherwise,
  /// since that's what seeds the Redis geo entry) and ignores them for
  /// `offline`.
  Future<DriverProfile> setStatus(DriverStatus status, {double? lat, double? lng});

  /// Stream of dispatch offers for this driver.
  ///
  /// Backed by the `/v1/ws` `job_offer` push (TRK-3/TRK-4) when a socket is
  /// wired; the dio implementation returns an empty stream otherwise (no
  /// FCM tap-through when backgrounded yet either — that's still open).
  Stream<JobOffer> incomingOffers();

  /// `GET /v1/drivers/me/balance` (DRV-5/LED-1) — owed commission balance
  /// plus recent settlements.
  Future<DriverBalance> balance();
}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiDriversRepository implements DriversRepository {
  ApiDriversRepository(this._dio, [this._socket]);

  final Dio _dio;

  /// The realtime channel (TRK-4). Null when the caller didn't wire one up.
  final CraneSocket? _socket;

  @override
  Future<DriverProfile> registerDriver({
    String? plate,
    TruckType? truckType,
    TruckCapacity? capacity,
    String? inviteToken,
    String? licenseUrl,
    String? truckPhotoUrl,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/drivers/me/register',
      data: {
        // ignore: use_null_aware_elements
        if (plate != null) 'plate': plate,
        // ignore: use_null_aware_elements
        if (truckType != null) 'truck_type': truckType.wire,
        // ignore: use_null_aware_elements
        if (capacity != null) 'capacity': capacity.wire,
        // ignore: use_null_aware_elements
        if (inviteToken != null) 'invite_token': inviteToken,
        // ignore: use_null_aware_elements
        if (licenseUrl != null) 'license_url': licenseUrl,
        // ignore: use_null_aware_elements
        if (truckPhotoUrl != null) 'truck_photo_url': truckPhotoUrl,
      },
    );
    return DriverProfile.fromJson(res.data!);
  }

  @override
  Future<DriverProfile> setStatus(
    DriverStatus status, {
    double? lat,
    double? lng,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/drivers/me/status',
      data: {
        'status': status.wire,
        // ignore: use_null_aware_elements
        if (lat != null) 'lat': lat,
        // ignore: use_null_aware_elements
        if (lng != null) 'lng': lng,
      },
    );
    return DriverProfile.fromJson(res.data!);
  }

  @override
  Stream<JobOffer> incomingOffers() {
    final socket = _socket;
    if (socket == null) return const Stream.empty();
    socket.connect();
    return socket.messages
        .where((message) => message is ServerMessageJobOffer)
        .cast<ServerMessageJobOffer>()
        .asyncMap(_toJobOffer);
  }

  /// `JobOfferEvent` (see `backend/app/schemas/job.py`) doesn't carry
  /// addresses, so the offer sheet (which shows `job.pickupAddress`) needs a
  /// real `Job`. Fetches it the same way `ApiJobsRepository.getJob` does
  /// rather than depending on that repository directly.
  Future<JobOffer> _toJobOffer(ServerMessageJobOffer event) async {
    final job = await _fetchJob(event.jobId);
    return JobOffer(
      offerId: event.offerId,
      job: job,
      // The backend computes both from the offered driver's live Redis geo
      // position and the job's real commission config (see
      // `notify_driver_offer` in `backend/app/services/realtime.py`) — but
      // both are best-effort there (no geo entry, or no quoted_price yet)
      // and fall back to the same flat-15%-of-quoted-price approximation
      // `FakeDriversRepository` uses when the real value is missing.
      pickupDistanceKm: event.pickupDistanceKm ?? 0,
      commissionAmount: event.commissionAmount ??
          (event.quotedPrice == null
              ? 0
              : ((event.quotedPrice! * 0.15) / 100).round() * 100),
      ttlSeconds: event.expiresInSeconds,
      offeredAt: DateTime.now(),
    );
  }

  Future<Job> _fetchJob(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/jobs/$id');
    return Job.fromJson(res.data!);
  }

  @override
  Future<DriverBalance> balance() async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/drivers/me/balance');
    return DriverBalance.fromJson(res.data!);
  }
}
