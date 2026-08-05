import 'package:dio/dio.dart';

import '../models/job.dart';
import '../models/lat_lng.dart';
import '../models/quote.dart';

/// Job-domain operations used by both the customer and driver flows.
///
/// Implementations: [ApiJobsRepository] (dio → FastAPI) and
/// `FakeJobsRepository` (seeded in-memory data). The composition root in
/// `lib/app/di.dart` picks one from `Env.useFakeBackend`.
abstract interface class JobsRepository {
  /// `POST /v1/jobs/quote` — price + ETA for a pickup/dropoff/vehicle combo.
  Future<Quote> requestQuote({
    required LatLng pickup,
    required LatLng dropoff,
    required VehicleType vehicleType,
  });

  /// `POST /v1/jobs` — create a job from a cached quote id. The job starts
  /// in `matching`.
  Future<Job> createJob({
    required String quoteId,
    required String pickupAddress,
    required String dropoffAddress,
  });

  /// `GET /v1/jobs/{id}`.
  Future<Job> getJob(String id);

  /// Live view of a job. Emits the current snapshot, then every change.
  ///
  /// TODO(TRK-4): back this with the authed WebSocket job channel once it
  /// exists; the dio implementation polls until then.
  Stream<Job> watchJob(String id);

  /// `POST /v1/jobs/{id}/accept` — driver accepts an offer.
  Future<Job> acceptJob(String id);

  /// `POST /v1/jobs/{id}/status` — assigned driver advances the state
  /// machine (JOB-6).
  Future<Job> updateJobStatus(String id, JobStatus status);
}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiJobsRepository implements JobsRepository {
  ApiJobsRepository(this._dio);

  final Dio _dio;

  /// Poll cadence for [watchJob] until TRK-4 replaces it with the WebSocket.
  static const pollInterval = Duration(seconds: 3);

  @override
  Future<Quote> requestQuote({
    required LatLng pickup,
    required LatLng dropoff,
    required VehicleType vehicleType,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/jobs/quote',
      data: {
        'pickup': pickup.toJson(),
        'dropoff': dropoff.toJson(),
        'vehicle_type': vehicleType.wire,
      },
    );
    return Quote.fromJson(res.data!);
  }

  @override
  Future<Job> createJob({
    required String quoteId,
    required String pickupAddress,
    required String dropoffAddress,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/jobs',
      data: {
        'quote_id': quoteId,
        'pickup_address': pickupAddress,
        'dropoff_address': dropoffAddress,
      },
    );
    return Job.fromJson(res.data!);
  }

  @override
  Future<Job> getJob(String id) async {
    final res = await _dio.get<Map<String, dynamic>>('/v1/jobs/$id');
    return Job.fromJson(res.data!);
  }

  @override
  Stream<Job> watchJob(String id) async* {
    // TODO(TRK-4): replace polling with the `/v1/ws` job events channel.
    while (true) {
      yield await getJob(id);
      await Future<void>.delayed(pollInterval);
    }
  }

  @override
  Future<Job> acceptJob(String id) async {
    final res = await _dio.post<Map<String, dynamic>>('/v1/jobs/$id/accept');
    return Job.fromJson(res.data!);
  }

  @override
  Future<Job> updateJobStatus(String id, JobStatus status) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/v1/jobs/$id/status',
      data: {'status': status.wire},
    );
    return Job.fromJson(res.data!);
  }
}
