import 'dart:async';

import 'package:dio/dio.dart';

import '../models/driver_balance.dart';
import '../models/driver_profile.dart';
import '../models/job.dart';
import '../models/job_offer.dart';
import '../models/truck.dart';
import 'drivers_repository.dart';
import 'fake_auth_repository.dart';
import 'fake_fleet_repository.dart';
import 'fake_jobs_repository.dart';
import 'jobs_repository.dart';

/// In-memory [DriversRepository] with a seeded profile and a dev-only offer
/// trigger, used while dispatch (DSP-2) and the WebSocket (TRK-4) are not
/// built.
class FakeDriversRepository implements DriversRepository {
  FakeDriversRepository({
    required FakeJobsRepository jobs,
    FakeAuthRepository? auth,
    FakeFleetRepository? fleet,
    this.actionDelay = const Duration(milliseconds: 300),
    this.offerTtlSeconds = 30,
    bool verified = true,
    DriverStatus status = DriverStatus.offline,
  })  : _jobs = jobs,
        _auth = auth,
        _fleet = fleet,
        _profile = DriverProfile(
          id: 'drv-profile-001',
          userId: 'drv-001',
          status: status,
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

  /// FLT-4: shared with `FakeFleetRepository` so [registerDriver] can
  /// redeem an [DriverInvite] the same way the real backend's
  /// `POST /v1/drivers/me/register` does for `invite_token` — links onto
  /// the invite's pre-provisioned truck instead of creating a new one. Null
  /// in tests that don't wire one up (redeeming an invite then just throws,
  /// same as the real backend's 404 for an unknown token).
  final FakeFleetRepository? _fleet;
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

  /// DRV-1 test hook: when true, the *next* `setStatus(available)` call
  /// throws a `DioException` shaped exactly like the real backend's
  /// balance-cap rejection (403, `detail: "Balance owed to the platform
  /// exceeds the allowed cap"`), then resets to false. Lets fake-mode tests
  /// trigger `DriverHomeCubit`'s `DriverBlockReason.balanceCap` path
  /// without replicating the real balance calculation.
  bool rejectNextAvailableWithBalanceCap = false;

  @override
  Future<DriverProfile> setStatus(
    DriverStatus status, {
    double? lat,
    double? lng,
  }) async {
    await Future<void>.delayed(actionDelay);
    lastLat = lat;
    lastLng = lng;
    if (status == DriverStatus.available && rejectNextAvailableWithBalanceCap) {
      rejectNextAvailableWithBalanceCap = false;
      const path = '/v1/drivers/me/status';
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<Map<String, dynamic>>(
          requestOptions: RequestOptions(path: path),
          statusCode: 403,
          data: const {
            'detail': 'Balance owed to the platform exceeds the allowed cap',
          },
        ),
        type: DioExceptionType.badResponse,
      );
    }
    // Mirrors the real backend refusing to change status while blocked
    // (403) — but, like the unverified case below, this fake stays
    // permissive rather than throwing, so a widget/cubit test can still
    // observe the resulting DriverHomeState (verified/blocked flow through
    // to state.profile either way; only offline<->available actually toggle).
    if (_profile.status != DriverStatus.blocked) {
      _profile = _profile.copyWith(status: status);
    }
    return _profile;
  }

  @override
  Stream<JobOffer> incomingOffers() => _offers.stream;

  int _truckSeq = 0;

  @override
  Future<DriverProfile> registerDriver({
    String? plate,
    TruckType? truckType,
    TruckCapacity? capacity,
    String? inviteToken,
    String? licenseUrl,
    String? truckPhotoUrl,
  }) async {
    await Future<void>.delayed(actionDelay);
    final Truck truck;
    if (inviteToken != null) {
      // FLT-4: redeem a fleet owner's invite instead of creating a new
      // truck. Mirrors the real backend checking the invite's phone
      // against the caller's own verified phone.
      final fleet = _fleet;
      if (fleet == null) throw StateError('Invite not found');
      truck = fleet.redeemInvite(
        inviteToken: inviteToken,
        phone: _auth?.currentPhone ?? '',
        driverId: _profile.userId,
      );
    } else {
      truck = Truck(
        id: 'trk-${++_truckSeq}',
        driverId: _profile.userId,
        plate: plate!,
        type: truckType!,
        capacity: capacity!,
      );
    }
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
      truck: truck,
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

  /// PAY-3 test hook: the *next* [settleBalance] call throws the same
  /// `SettlementRejectedException` a real backend with no Wompi key
  /// configured would (503) — the actual, common state today, since no
  /// real Wompi account exists yet.
  bool rejectNextSettleAsUnavailable = false;

  @override
  Future<SettlementCheckout> settleBalance({
    required int amountCop,
    SettlementPaymentMethod method = SettlementPaymentMethod.nequi,
  }) async {
    await Future<void>.delayed(actionDelay);
    if (rejectNextSettleAsUnavailable) {
      rejectNextSettleAsUnavailable = false;
      throw SettlementRejectedException('wompi_private_key is not configured');
    }
    if (amountCop <= 0) {
      throw SettlementRejectedException('amount must be positive');
    }
    final owed = (await balance()).owedCents;
    if (owed <= 0) {
      throw SettlementRejectedException('No balance owed');
    }
    if (amountCop > owed) {
      throw SettlementRejectedException('amount exceeds the owed balance');
    }
    // Deliberately doesn't touch `_settlements` -- a real settlement only
    // applies once Wompi's webhook reports the payment approved (PAY-1),
    // which this fake has no equivalent of simulating. `balance()` stays
    // unchanged until a caller re-seeds it directly, same honesty the real
    // backend has (the balance genuinely doesn't move at checkout time).
    return SettlementCheckout(
      paymentReference: 'fake_settlement_${DateTime.now().millisecondsSinceEpoch}',
      asyncPaymentUrl: method == SettlementPaymentMethod.nequi
          ? null
          : 'https://checkout.wompi.co/fake/$method',
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
