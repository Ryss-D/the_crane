import 'dart:async';

import '../models/driver_profile.dart';
import '../models/job_offer.dart';
import '../models/truck.dart';
import 'drivers_repository.dart';
import 'fake_jobs_repository.dart';

/// In-memory [DriversRepository] with a seeded profile and a dev-only offer
/// trigger, used while dispatch (DSP-2) and the WebSocket (TRK-4) are not
/// built.
class FakeDriversRepository implements DriversRepository {
  FakeDriversRepository({
    required FakeJobsRepository jobs,
    this.actionDelay = const Duration(milliseconds: 300),
    this.offerTtlSeconds = 30,
    bool verified = true,
  })  : _jobs = jobs,
        _profile = DriverProfile(
          userId: 'drv-001',
          status: DriverStatus.offline,
          verified: verified,
          truckPlate: 'TGX 123',
          truckType: TruckType.flatbed,
          capacity: TruckCapacity.both,
          ratingAvg: 4.8,
        );

  final FakeJobsRepository _jobs;
  final Duration actionDelay;

  /// Offer TTL, normally read from `platform_config` (JOB-2). 30s per DSP-2.
  final int offerTtlSeconds;

  /// Commission preview rate. TODO(JOB-2): read mode/rate per vehicle type
  /// from `platform_config` once it exists.
  static const _commissionRate = 0.15;

  DriverProfile _profile;
  final _offers = StreamController<JobOffer>.broadcast();
  int _offerSeq = 0;

  @override
  Future<DriverProfile> setStatus(DriverStatus status) async {
    await Future<void>.delayed(actionDelay);
    _profile = _profile.copyWith(status: status);
    return _profile;
  }

  @override
  Stream<JobOffer> incomingOffers() => _offers.stream;

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
