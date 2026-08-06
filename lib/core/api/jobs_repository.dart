import 'dart:async';

import 'package:dio/dio.dart';

import '../models/job.dart';
import '../models/job_history_page.dart';
import '../models/lat_lng.dart';
import '../models/quote.dart';
import '../models/rating.dart';
import '../ws/crane_socket.dart';
import '../ws/server_message.dart';

/// Whose history `GET /v1/jobs?role=..` should return — mirrors the
/// backend's `role: Literal["customer", "driver"]` query param exactly
/// (`backend/app/api/jobs.py::list_jobs`).
enum JobHistoryRole {
  customer('customer'),
  driver('driver');

  const JobHistoryRole(this.wire);

  final String wire;
}

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
  /// Backed by the `/v1/ws` job channel (TRK-4) when connected: a
  /// `job_event` push re-fetches and re-emits the job. Falls back to polling
  /// (the original TRK-4-era implementation) whenever the socket isn't
  /// connected, so callers never see a gap.
  Stream<Job> watchJob(String id);

  /// `POST /v1/jobs/{id}/accept` — driver accepts an offer.
  Future<Job> acceptJob(String id);

  /// `POST /v1/jobs/{id}/status` — assigned driver advances the state
  /// machine (JOB-6).
  Future<Job> updateJobStatus(String id, JobStatus status);

  /// `POST /v1/jobs/{id}/confirm-delivery` (CUS-5/LED-1) — the job's
  /// customer confirms cash payment on a `delivered` job, completing it and
  /// (server-side) writing the driver's commission ledger entry. Only the
  /// job's customer may call this (`backend/app/services/jobs.py`).
  Future<Job> confirmDelivery(String id);

  /// `POST /v1/jobs/{id}/rating` (RAT-1) — rate the other side of a
  /// completed job. `stars` is 1-5; each side may rate once per job.
  Future<void> submitRating(String jobId, {required int stars, String? comment});

  /// `GET /v1/jobs/{id}/ratings` (RAT-1) — both sides' ratings for a job, if
  /// given yet.
  Future<List<Rating>> getRatings(String jobId);

  /// `GET /v1/jobs?role=..&limit=..&offset=..` (JOB-5/RAT-3) — the caller's
  /// job history as customer or driver, newest first.
  Future<JobHistoryPage> listHistory({
    required JobHistoryRole role,
    int limit = 20,
    int offset = 0,
  });
}

/// Dio-backed implementation hitting the FastAPI v1 endpoints.
class ApiJobsRepository implements JobsRepository {
  ApiJobsRepository(this._dio, [this._socket]);

  final Dio _dio;

  /// The realtime channel (TRK-4). Null when the caller didn't wire one up
  /// (e.g. in a test that only exercises REST calls) — [watchJob] then just
  /// polls, same as before TRK-4.
  final CraneSocket? _socket;

  /// Poll cadence for [watchJob] — used as-is when no socket is wired, and
  /// as the fallback cadence whenever the socket is disconnected.
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
  Stream<Job> watchJob(String id) {
    final socket = _socket;
    if (socket == null) return _pollJob(id);
    return _watchJobViaSocket(id, socket);
  }

  /// The original TRK-4-era loop: poll [getJob] forever. Used directly when
  /// there's no socket at all, and as the fallback stream in
  /// [_watchJobViaSocket] while the socket is disconnected.
  Stream<Job> _pollJob(String id) async* {
    while (true) {
      yield await getJob(id);
      await Future<void>.delayed(pollInterval);
    }
  }

  /// Prefers the WebSocket: subscribes to [id], re-fetches on every
  /// `job_event` for it, and re-emits an immediate snapshot on (re)connect.
  /// While [socket] is disconnected, [_pollJob] fills the gap so the stream
  /// never goes silent.
  Stream<Job> _watchJobViaSocket(String id, CraneSocket socket) {
    late final StreamController<Job> controller;
    StreamSubscription<CraneSocketStatus>? statusSub;
    StreamSubscription<ServerMessage>? messageSub;
    StreamSubscription<Job>? pollSub;

    void stopPolling() {
      pollSub?.cancel();
      pollSub = null;
    }

    void startPolling() {
      if (pollSub != null) return;
      pollSub = _pollJob(id).listen(controller.add, onError: controller.addError);
    }

    Future<void> emitSnapshot() async {
      try {
        controller.add(await getJob(id));
      } catch (error, stackTrace) {
        controller.addError(error, stackTrace);
      }
    }

    controller = StreamController<Job>.broadcast(
      onListen: () {
        socket.connect();
        socket.subscribe(id);
        unawaited(emitSnapshot());
        if (socket.status != CraneSocketStatus.connected) {
          startPolling();
        }
        statusSub = socket.statusStream.listen((status) {
          if (status == CraneSocketStatus.connected) {
            stopPolling();
            unawaited(emitSnapshot());
          } else {
            startPolling();
          }
        });
        messageSub = socket.messages.listen((message) {
          if (message is ServerMessageJobEvent && message.jobId == id) {
            unawaited(emitSnapshot());
          }
        });
      },
      onCancel: () async {
        socket.unsubscribe(id);
        await statusSub?.cancel();
        await messageSub?.cancel();
        stopPolling();
      },
    );
    return controller.stream;
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

  @override
  Future<Job> confirmDelivery(String id) async {
    final res =
        await _dio.post<Map<String, dynamic>>('/v1/jobs/$id/confirm-delivery');
    return Job.fromJson(res.data!);
  }

  @override
  Future<void> submitRating(
    String jobId, {
    required int stars,
    String? comment,
  }) async {
    await _dio.post<void>(
      '/v1/jobs/$jobId/rating',
      data: {
        'stars': stars,
        if (comment != null && comment.trim().isNotEmpty)
          'comment': comment.trim(),
      },
    );
  }

  @override
  Future<List<Rating>> getRatings(String jobId) async {
    // RAT-1's rating endpoints aren't live on the backend yet at the time
    // this client was written (no `app/api/ratings.py`/router registration
    // — only the `Rating` model exists). This defensively accepts either a
    // bare JSON array or a `{"items": [...]}` envelope so it keeps working
    // whichever shape lands.
    final res = await _dio.get<dynamic>('/v1/jobs/$jobId/ratings');
    final data = res.data;
    final list = data is List
        ? data
        : data is Map<String, dynamic>
            ? data['items'] as List? ?? const []
            : const [];
    return list
        .cast<Map<String, dynamic>>()
        .map(Rating.fromJson)
        .toList(growable: false);
  }

  @override
  Future<JobHistoryPage> listHistory({
    required JobHistoryRole role,
    int limit = 20,
    int offset = 0,
  }) async {
    final res = await _dio.get<Map<String, dynamic>>(
      '/v1/jobs',
      queryParameters: {
        'role': role.wire,
        'limit': limit,
        'offset': offset,
      },
    );
    return JobHistoryPage.fromJson(res.data!);
  }
}
