import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';
import '../../../core/models/job_offer.dart';

part 'offer_cubit.freezed.dart';

/// An offer currently on screen, with its live countdown.
@freezed
abstract class ActiveOffer with _$ActiveOffer {
  const factory ActiveOffer({
    required JobOffer offer,
    required int remainingSeconds,
  }) = _ActiveOffer;
}

/// DRV-2 — listens for incoming offers and runs the TTL countdown.
///
/// State is null when no offer is showing. Timeout auto-dismisses and counts
/// as no-response (DSP-2 then moves to the next driver).
class OfferCubit extends Cubit<ActiveOffer?> {
  OfferCubit({
    required DriversRepository driversRepository,
    required JobsRepository jobsRepository,
    this.tickInterval = const Duration(seconds: 1),
  })  : _jobsRepo = jobsRepository,
        super(null) {
    _subscription = driversRepository.incomingOffers().listen(_onOffer);
  }

  final JobsRepository _jobsRepo;

  /// One countdown tick. Injectable so tests can run the 30s TTL quickly.
  final Duration tickInterval;

  late final StreamSubscription<JobOffer> _subscription;
  Timer? _ticker;

  void _onOffer(JobOffer offer) {
    _ticker?.cancel();
    emit(ActiveOffer(offer: offer, remainingSeconds: offer.ttlSeconds));
    _ticker = Timer.periodic(tickInterval, (timer) {
      final current = state;
      if (current == null) {
        timer.cancel();
        return;
      }
      final remaining = current.remainingSeconds - 1;
      if (remaining <= 0) {
        timer.cancel();
        // Timeout = no-response. TODO(DSP-2): the backend times the offer
        // out server-side; nothing to send from here.
        emit(null);
      } else {
        emit(current.copyWith(remainingSeconds: remaining));
      }
    });
  }

  /// Explicit rejection. TODO(DSP-2): send the rejection so dispatch can
  /// move on immediately instead of waiting out the TTL.
  void reject() {
    _ticker?.cancel();
    emit(null);
  }

  /// Accepts via `POST /v1/jobs/{id}/accept`. Returns the assigned job (the
  /// caller seeds `ActiveJobCubit` with it), or null on failure/expiry.
  Future<Job?> accept() async {
    final current = state;
    if (current == null) return null;
    _ticker?.cancel();
    try {
      final job = await _jobsRepo.acceptJob(current.offer.job.id);
      emit(null);
      return job;
    } catch (_) {
      emit(null);
      return null;
    }
  }

  @override
  Future<void> close() {
    _ticker?.cancel();
    _subscription.cancel();
    return super.close();
  }
}
