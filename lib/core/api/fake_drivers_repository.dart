import 'dart:async';

import '../models/driver_balance.dart';
import '../models/driver_profile.dart';
import '../models/job.dart';
import '../models/job_offer.dart';
import '../models/truck.dart';
import 'drivers_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_jobs_repository.dart';
import 'jobs_repository.dart';

/// In-memory [DriversRepository] with a seeded profile and a dev-only offer
/// trigger, used while dispatch (DSP-2) and the WebSocket (TRK-4) are not
/// built.
class FakeDriversRepository implements DriversRepository {
  FakeDriversRepository({
    required FakeJobsRepository jobs,
    FakeAuthRepository? auth,
    this.actionDelay = const Duration(milliseconds: 300),
    this.offerTtlSeconds = 30,
    bool verified = true,
  })  : _jobs = jobs,
        _auth = auth,
        _profile = DriverProfile(
          id: 'drv-profile-001',
          userId: 'drv-001',
          status: DriverStatus.offline,
          verified: verified,
          truck: const Truck(
            id: 'trk-001',
            driverId: 'drv-001',
            plate: 'TGX 123',
            type: TruckType.flatbed,
            capacity: TruckCapacity.both,
          ),
          ratingAvg: 4.8,
        );

  final FakeJobsRepository _jobs;

  /// AUTH-5: shared with [FakeAuthRepository] so [registerDriver] can flip
  /// the fake signed-in user's role the same way the real backend does in
  /// the same request — the real client picks this up on its next
  /// `AuthCubit.refreshUser()` re-sync; this fake mirrors that by mutating
  /// the shared fake user directly. Null in tests that don't wire one up
  /// (registration then just updates the local profile, no role flip).
  final FakeAuthRepository? _auth;
  final Duration actionDelay;

  /// Offer TTL, normally read from `platform_config` (JOB-2). 30s per DSP-2.
  final int offerTtlSeconds;

  /// Commission preview rate. TODO(JOB-2): read mode/rate per vehicle type
  /// from `platform_config` once it exists.
  static const _commissionRate = 0.15;

  DriverProfile _profile;
  final _offers = StreamController<JobOffer>.broadcast();
  int _offerSeq = 0;

  /// Dev-seeded settlement history (DRV-5), so the balance screen has
  /// something to show. Real settlements come from the admin-recorded
  /// `POST /v1/admin/ledger/{driver_id}/settle` (ADM-2) — nothing here
  /// simulates that flow, it's just fixed seed data.
  final List<Settlement> _settlements = [
    Settlement(
      id: 'set-1',
      amountCents: 180000,
      settledAt: DateTime.now().subtract(const Duration(days: 7)),
      note: 'Liquidación semanal',
    ),
  ];

  /// Test hook: the `lat`/`lng` the caller most recently passed to
  /// [setStatus] — lets tests assert `DriverHomeCubit` actually sends a
  /// fix when going available, without a real backend to 422 on it.
  double? lastLat;
  double? lastLng;

  @override
  Future<DriverProfile> setStatus(
    DriverStatus status, {
    double? lat,
    double? lng,
  }) async {
    await Future<void>.delayed(actionDelay);
    lastLat = lat;
    lastLng = lng;
    _profile = _profile.copyWith(status: status);
    return _profile;
  }

  @override
  Stream<JobOffer> incomingOffers() => _offers.stream;

  int _truckSeq = 0;

  @override
  Future<DriverProfile> registerDriver({
    required String plate,
    required TruckType truckType,
    required TruckCapacity capacity,
    String? licenseUrl,
    String? truckPhotoUrl,
  }) async {
    await Future<void>.delayed(actionDelay);
    // Mirrors the real backend (AUTH-5): a fresh registration is unverified
    // and offline until an admin verifies it (ADM-2), regardless of the
    // constructor's `verified` seed for the pre-existing dev profile.
    _profile = DriverProfile(
      id: 'drv-profile-${++_truckSeq}',
      userId: _profile.userId,
      status: DriverStatus.offline,
      verified: false,
      licenseUrl: licenseUrl,
      truckPhotoUrl: truckPhotoUrl,
      truck: Truck(
        id: 'trk-$_truckSeq',
        driverId: _profile.userId,
        plate: plate,
        type: truckType,
        capacity: capacity,
      ),
    );
    _auth?.debugPromoteToDriver();
    return _profile;
  }

  @override
  Future<DriverBalance> balance() async {
    await Future<void>.delayed(actionDelay);
    // Mirrors the backend formula (`driver_owed_balance` in
    // `backend/app/services/ledger.py`): sum of commission earned on
    // completed jobs, minus settlements already paid out.
    final page =
        await _jobs.listHistory(role: JobHistoryRole.driver, limit: 1000);
    final accrued = page.items
        .where((job) => job.status == JobStatus.completed)
        .fold<int>(0, (sum, job) => sum + _commission(job));
    final settled =
        _settlements.fold<int>(0, (sum, entry) => sum + entry.amountCents);
    return DriverBalance(
      owedCents: accrued - settled,
      recentSettlements: List.unmodifiable(_settlements),
    );
  }

  int _commission(Job job) {
    final fare = job.finalPrice ?? job.quotedPrice;
    return (fare * _commissionRate / 100).round() * 100;
  }

  /// Dev-only: seeds a matching job in the fake jobs repo and pushes an
  /// offer for it, simulating the DSP-2 fan-out. Wired to a debug button on
  /// the driver home screen.
  JobOffer debugTriggerOffer() {
    final job = _jobs.debugSeedIncomingJob();
    final offer = JobOffer(
      offerId: 'off-${++_offerSeq}',
      job: job,
      pickupDistanceKm: 2.3,
      commissionAmount: (job.quotedPrice * _commissionRate / 100).round() * 100,
      ttlSeconds: offerTtlSeconds,
      offeredAt: DateTime.now(),
    );
    _offers.add(offer);
    return offer;
  }
}
