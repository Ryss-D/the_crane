import 'dart:async';
import 'dart:math' as math;

import '../models/job.dart';
import '../models/lat_lng.dart';
import '../models/quote.dart';
import '../models/truck.dart';
import 'jobs_repository.dart';

/// What the fake dispatcher does with a job after `matchingDelay`.
enum FakeMatchingOutcome { assigned, noDrivers }

/// In-memory [JobsRepository] with seeded data and realistic delays.
///
/// Used while the FastAPI backend is unreachable (see `Env.useFakeBackend`).
/// Pricing mimics JOB-4 (`base + per_km × km`, min fare, COP) with hardcoded
/// dev values; the real numbers live in `platform_config` (JOB-2).
class FakeJobsRepository implements JobsRepository {
  FakeJobsRepository({
    this.quoteDelay = const Duration(milliseconds: 400),
    this.createDelay = const Duration(milliseconds: 350),
    this.actionDelay = const Duration(milliseconds: 250),
    this.matchingDelay = const Duration(seconds: 3),
    this.matchingOutcome = FakeMatchingOutcome.assigned,
  });

  final Duration quoteDelay;
  final Duration createDelay;
  final Duration actionDelay;

  /// How long the fake dispatcher "searches" before resolving.
  final Duration matchingDelay;

  /// Mutable so dev tooling and tests can force the no-drivers path.
  FakeMatchingOutcome matchingOutcome;

  final Map<String, Job> _jobs = {};
  final Map<String, ({LatLng pickup, LatLng dropoff, Quote quote})> _quotes =
      {};
  final Map<String, StreamController<Job>> _watchers = {};
  int _seq = 0;

  /// Dev-seeded pricing per vehicle type: (base, perKm, minFare) in COP.
  static const _pricing = {
    VehicleType.moto: (base: 50000, perKm: 3200, minFare: 60000),
    VehicleType.car: (base: 80000, perKm: 4500, minFare: 95000),
    VehicleType.suv: (base: 95000, perKm: 5200, minFare: 110000),
  };

  static const _seedDriver = JobDriverSummary(
    id: 'drv-001',
    name: 'Carlos Ramírez',
    phone: '+573001112233',
    truckPlate: 'TGX 123',
    truckType: TruckType.flatbed,
    ratingAvg: 4.8,
  );

  @override
  Future<Quote> requestQuote({
    required LatLng pickup,
    required LatLng dropoff,
    required VehicleType vehicleType,
  }) async {
    await Future<void>.delayed(quoteDelay);
    final rates = _pricing[vehicleType]!;
    // Road distance ≈ haversine × 1.35 (Directions comes with FND-6/JOB-4).
    final distanceKm = math.max(1.0, _haversineKm(pickup, dropoff) * 1.35);
    final raw = rates.base + (rates.perKm * distanceKm).round();
    final price = math.max(rates.minFare, (raw / 100).round() * 100);
    final quote = Quote(
      quoteId: 'q-${++_seq}',
      vehicleType: vehicleType,
      price: price,
      etaMinutes: 5 + (distanceKm * 1.5).round(),
      distanceKm: double.parse(distanceKm.toStringAsFixed(1)),
      expiresAt: DateTime.now().add(const Duration(minutes: 10)),
    );
    _quotes[quote.quoteId] = (pickup: pickup, dropoff: dropoff, quote: quote);
    return quote;
  }

  @override
  Future<Job> createJob({
    required String quoteId,
    required String pickupAddress,
    required String dropoffAddress,
  }) async {
    await Future<void>.delayed(createDelay);
    final cached = _quotes[quoteId];
    if (cached == null) {
      throw StateError('Unknown or expired quote: $quoteId');
    }
    final job = Job(
      id: 'job-${++_seq}',
      customerId: 'cus-001',
      status: JobStatus.matching,
      vehicleType: cached.quote.vehicleType,
      pickup: cached.pickup,
      pickupAddress: pickupAddress,
      dropoff: cached.dropoff,
      dropoffAddress: dropoffAddress,
      distanceKm: cached.quote.distanceKm,
      quotedPrice: cached.quote.price,
      requestedAt: DateTime.now(),
    );
    _put(job);
    Timer(matchingDelay, () => _resolveMatching(job.id));
    return job;
  }

  void _resolveMatching(String jobId) {
    final job = _jobs[jobId];
    if (job == null || job.status != JobStatus.matching) return;
    switch (matchingOutcome) {
      case FakeMatchingOutcome.assigned:
        _put(job.copyWith(
          status: JobStatus.assigned,
          driverId: _seedDriver.id,
          driver: _seedDriver,
          assignedAt: DateTime.now(),
        ));
      case FakeMatchingOutcome.noDrivers:
        _put(job.copyWith(status: JobStatus.noDrivers));
    }
  }

  @override
  Future<Job> getJob(String id) async {
    await Future<void>.delayed(actionDelay);
    final job = _jobs[id];
    if (job == null) throw StateError('Unknown job: $id');
    return job;
  }

  @override
  Stream<Job> watchJob(String id) async* {
    final current = _jobs[id];
    if (current != null) yield current;
    yield* _watcher(id).stream;
  }

  @override
  Future<Job> acceptJob(String id) async {
    await Future<void>.delayed(actionDelay);
    final job = _jobs[id];
    if (job == null) throw StateError('Unknown job: $id');
    final accepted = job.copyWith(
      status: JobStatus.assigned,
      driverId: _seedDriver.id,
      driver: _seedDriver,
      assignedAt: DateTime.now(),
    );
    _put(accepted);
    return accepted;
  }

  @override
  Future<Job> updateJobStatus(String id, JobStatus status) async {
    await Future<void>.delayed(actionDelay);
    final job = _jobs[id];
    if (job == null) throw StateError('Unknown job: $id');
    if (job.status.nextDriverStatus != status) {
      throw StateError('Illegal transition ${job.status.wire} → ${status.wire}');
    }
    final now = DateTime.now();
    final updated = job.copyWith(
      status: status,
      pickedUpAt: status == JobStatus.inTransit ? now : job.pickedUpAt,
      completedAt: status == JobStatus.completed ? now : job.completedAt,
    );
    _put(updated);
    return updated;
  }

  /// Seeds a job some other customer requested, for the driver offer flow
  /// (used by `FakeDriversRepository.debugTriggerOffer`).
  Job debugSeedIncomingJob() {
    final job = Job(
      id: 'job-${++_seq}',
      customerId: 'cus-042',
      status: JobStatus.matching,
      vehicleType: VehicleType.car,
      pickup: const LatLng(lat: 6.2088, lng: -75.5679),
      pickupAddress: 'Cra. 43A #5-15, El Poblado, Medellín',
      dropoff: const LatLng(lat: 6.1450, lng: -75.6169),
      dropoffAddress: 'C.C. Mayorca, Sabaneta',
      distanceKm: 9.6,
      quotedPrice: 123200,
      requestedAt: DateTime.now(),
    );
    _put(job);
    return job;
  }

  void _put(Job job) {
    _jobs[job.id] = job;
    _watchers[job.id]?.add(job);
  }

  StreamController<Job> _watcher(String id) =>
      _watchers.putIfAbsent(id, StreamController<Job>.broadcast);

  static double _haversineKm(LatLng a, LatLng b) {
    const r = 6371.0;
    final dLat = _rad(b.lat - a.lat);
    final dLng = _rad(b.lng - a.lng);
    final h = math.pow(math.sin(dLat / 2), 2) +
        math.cos(_rad(a.lat)) * math.cos(_rad(b.lat)) *
            math.pow(math.sin(dLng / 2), 2);
    return 2 * r * math.asin(math.min(1, math.sqrt(h)));
  }

  static double _rad(double deg) => deg * math.pi / 180;
}
