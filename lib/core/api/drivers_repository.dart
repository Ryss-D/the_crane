import 'package:dio/dio.dart';

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
  Future<DriverProfile> registerDriver({
    required String plate,
    required TruckType truckType,
    required TruckCapacity capacity,
    String? licenseUrl,
    String? truckPhotoUrl,
  });

  /// `PATCH /v1/drivers/me/status` — go available/offline.
  Future<DriverProfile> setStatus(DriverStatus status);

  /// Stream of dispatch offers for this driver.
  ///
  /// Backed by the `/v1/ws` `job_offer` push (TRK-3/TRK-4) when a socket is
  /// wired; the dio implementation returns an empty stream otherwise (no
  /// FCM tap-through when backgrounded yet either — that's still open).
  Stream<JobOffer> incomingOffers();
}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiDriversRepository implements DriversRepository {
  ApiDriversRepository(this._dio, [this._socket]);

  final Dio _dio;

  /// The realtime channel (TRK-4). Null when the caller didn't wire one up.
  final CraneSocket? _socket;

  @override
  Future<DriverProfile> registerDriver({
    required String plate,
    required TruckType truckType,
    required TruckCapacity capacity,
    String? licenseUrl,
    String? truckPhotoUrl,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/drivers/me/register',
      data: {
        'plate': plate,
        'truck_type': truckType.wire,
        'capacity': capacity.wire,
        // ignore: use_null_aware_elements
        if (licenseUrl != null) 'license_url': licenseUrl,
        // ignore: use_null_aware_elements
        if (truckPhotoUrl != null) 'truck_photo_url': truckPhotoUrl,
      },
    );
    return DriverProfile.fromJson(res.data!);
  }

  @override
  Future<DriverProfile> setStatus(DriverStatus status) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/v1/drivers/me/status',
      data: {'status': status.wire},
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

  /// `JobOfferEvent` (see `backend/app/schemas/job.py`) only carries
  /// `vehicle_type`/`pickup`/`dropoff`/`quoted_price`/`expires_in_seconds` —
  /// no addresses, so the offer sheet (which shows `job.pickupAddress`)
  /// needs a real `Job`. Fetches it the same way `ApiJobsRepository.getJob`
  /// does rather than depending on that repository directly.
  Future<JobOffer> _toJobOffer(ServerMessageJobOffer event) async {
    final job = await _fetchJob(event.jobId);
    return JobOffer(
      offerId: event.offerId,
      job: job,
      // TODO(TRK-4/DSP-2): the WS `job_offer` push doesn't include the
      // driver's distance to pickup (needs TRK-5's live position) or the
      // exact commission preview yet. Approximate commission the same way
      // the dev fake does (`FakeDriversRepository._commissionRate`, 15%)
      // until the backend enriches the payload or exposes a config lookup.
      pickupDistanceKm: 0,
      commissionAmount: event.quotedPrice == null
          ? 0
          : ((event.quotedPrice! * 0.15) / 100).round() * 100,
      ttlSeconds: event.expiresInSeconds,
      offeredAt: DateTime.now(),
    );
  }

  Future<Job> _fetchJob(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/jobs/$id');
    return Job.fromJson(res.data!);
  }
}
