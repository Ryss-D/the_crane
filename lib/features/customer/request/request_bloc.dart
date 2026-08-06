import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';
import '../../../core/models/lat_lng.dart';
import 'request_state.dart';

/// Medellín city center, anchor for the fake geocoder below.
const _medellin = LatLng(lat: 6.2442, lng: -75.5812);

/// Deterministic pseudo-geocoding: hashes the typed address into a point
/// near Medellín so quoting works without Maps.
///
/// TODO(FND-6): replace with pin-drag + Places autocomplete + reverse
/// geocoding once Google Maps is wired; the text fields become search boxes.
LatLng fakeGeocode(String address) {
  final h = address.trim().toLowerCase().hashCode;
  return LatLng(
    lat: _medellin.lat + ((h % 1000) - 500) / 10000.0,
    lng: _medellin.lng + (((h ~/ 1000) % 1000) - 500) / 10000.0,
  );
}

/// Events for the CUS-1/2/3 request flow.
sealed class RequestEvent {
  const RequestEvent();
}

final class RequestPickupChanged extends RequestEvent {
  const RequestPickupChanged(this.value);
  final String value;
}

final class RequestDropoffChanged extends RequestEvent {
  const RequestDropoffChanged(this.value);
  final String value;
}

final class RequestVehicleTypeChanged extends RequestEvent {
  const RequestVehicleTypeChanged(this.value);
  final VehicleType value;
}

/// Manual quote refresh (retry after failure; CUS-2 stale-quote re-fetch).
final class RequestQuoteRefreshed extends RequestEvent {
  const RequestQuoteRefreshed();
}

/// Confirm button: create the job from the current quote.
final class RequestConfirmed extends RequestEvent {
  const RequestConfirmed();
}

/// Retry from the no-drivers state (CUS-3): re-request with the same quote.
final class RequestMatchingRetried extends RequestEvent {
  const RequestMatchingRetried();
}

/// Leave the matching flow and stop tracking the job, cancelling it
/// server-side (best-effort — see the handler) if it isn't terminal yet.
final class RequestMatchingAbandoned extends RequestEvent {
  const RequestMatchingAbandoned();
}

/// Internal: a fresh snapshot arrived on the job watch stream.
final class RequestJobUpdated extends RequestEvent {
  const RequestJobUpdated(this.job);
  final Job job;
}

/// CUS-5: the customer confirms cash payment on a `delivered` job.
final class RequestDeliveryConfirmed extends RequestEvent {
  const RequestDeliveryConfirmed();
}

/// Drives the CUS-1/2/3 flow: inputs → quote → confirm → matching →
/// assigned / no-drivers. Pure bloc, fully testable without widgets.
class RequestBloc extends Bloc<RequestEvent, RequestState> {
  RequestBloc({required JobsRepository jobsRepository})
      : _repo = jobsRepository,
        super(const RequestState()) {
    on<RequestPickupChanged>((event, emit) async {
      if (event.value == state.pickupAddress) return;
      emit(state.copyWith(pickupAddress: event.value));
      await _refreshQuote(emit);
    });
    on<RequestDropoffChanged>((event, emit) async {
      if (event.value == state.dropoffAddress) return;
      emit(state.copyWith(dropoffAddress: event.value));
      await _refreshQuote(emit);
    });
    on<RequestVehicleTypeChanged>((event, emit) async {
      if (event.value == state.vehicleType) return;
      emit(state.copyWith(vehicleType: event.value));
      await _refreshQuote(emit);
    });
    on<RequestQuoteRefreshed>((event, emit) => _refreshQuote(emit));
    on<RequestConfirmed>((event, emit) => _confirm(emit));
    on<RequestMatchingRetried>((event, emit) async {
      if (state.activeJob?.status != JobStatus.noDrivers) return;
      await _confirm(emit);
    });
    on<RequestMatchingAbandoned>((event, emit) async {
      _jobSub?.cancel();
      _jobSub = null;
      final job = state.activeJob;
      // Best-effort: the customer is leaving regardless of whether the
      // backend still considers this job cancellable (it 409s past its
      // grace period, e.g. mid-trip) — nothing to do with that here beyond
      // not bothering to call it on an already-terminal job.
      if (job != null && !job.status.isTerminal) {
        try {
          await _repo.cancelJob(job.id);
        } catch (_) {
          // Ignored — see above.
        }
      }
      emit(state.copyWith(activeJob: null));
    });
    on<RequestJobUpdated>((event, emit) {
      emit(state.copyWith(activeJob: event.job));
    });
    on<RequestDeliveryConfirmed>((event, emit) => _confirmDelivery(emit));
  }

  final JobsRepository _repo;
  StreamSubscription<Job>? _jobSub;
  int _quoteToken = 0;

  Future<void> _refreshQuote(Emitter<RequestState> emit) async {
    // Any input change invalidates whatever quote request is in flight.
    final token = ++_quoteToken;
    if (!state.canQuote) {
      emit(state.copyWith(quote: null, isQuoting: false, quoteFailed: false));
      return;
    }
    emit(state.copyWith(quote: null, isQuoting: true, quoteFailed: false));
    try {
      final quote = await _repo.requestQuote(
        pickup: fakeGeocode(state.pickupAddress),
        dropoff: fakeGeocode(state.dropoffAddress),
        vehicleType: state.vehicleType,
      );
      if (token != _quoteToken) return;
      emit(state.copyWith(quote: quote, isQuoting: false));
    } catch (_) {
      if (token != _quoteToken) return;
      emit(state.copyWith(isQuoting: false, quoteFailed: true));
    }
  }

  Future<void> _confirm(Emitter<RequestState> emit) async {
    final quote = state.quote;
    if (quote == null || state.isCreatingJob) return;
    emit(state.copyWith(isCreatingJob: true, createJobFailed: false));
    try {
      final job = await _repo.createJob(
        quoteId: quote.quoteId,
        pickupAddress: state.pickupAddress.trim(),
        dropoffAddress: state.dropoffAddress.trim(),
      );
      emit(state.copyWith(activeJob: job, isCreatingJob: false));
      _watch(job.id);
    } catch (_) {
      emit(state.copyWith(isCreatingJob: false, createJobFailed: true));
    }
  }

  Future<void> _confirmDelivery(Emitter<RequestState> emit) async {
    final job = state.activeJob;
    if (job == null ||
        job.status != JobStatus.delivered ||
        state.isConfirmingDelivery) {
      return;
    }
    emit(state.copyWith(isConfirmingDelivery: true, confirmDeliveryFailed: false));
    try {
      final updated = await _repo.confirmDelivery(job.id);
      // The `watchJob` subscription above will likely deliver the same
      // snapshot too (fake broadcast / WS push) — emitting it here as well
      // means the UI doesn't wait on that round trip to see `completed`.
      emit(state.copyWith(activeJob: updated, isConfirmingDelivery: false));
    } catch (_) {
      emit(state.copyWith(isConfirmingDelivery: false, confirmDeliveryFailed: true));
    }
  }

  void _watch(String jobId) {
    _jobSub?.cancel();
    _jobSub = _repo.watchJob(jobId).listen((job) {
      if (!isClosed) add(RequestJobUpdated(job));
    });
  }

  @override
  Future<void> close() {
    _jobSub?.cancel();
    return super.close();
  }
}
