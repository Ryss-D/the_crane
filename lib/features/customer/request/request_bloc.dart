import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/api/jobs_repository.dart';
import '../../../core/models/job.dart';
import '../../../core/models/lat_lng.dart';
import '../../../core/models/place_prediction.dart';
import '../../../core/models/quote.dart';
import '../../../core/storage/active_job_store.dart';
import '../../../core/ws/crane_socket.dart';
import '../../../core/ws/server_message.dart';
import 'request_state.dart';

/// Medellín city center, anchor for the fake geocoder below.
const _medellin = LatLng(lat: 6.2442, lng: -75.5812);

/// Deterministic pseudo-geocoding: hashes the typed address into a point
/// near Medellín. FND-6: real Places search and pin-drag now resolve real
/// coordinates (see [RequestPickupLocationSelected]/[RequestPickupPinMoved]
/// and their dropoff equivalents) — this remains the fallback for whatever
/// the customer types but never picks/places a real point for (or if the
/// backend has no Places key configured yet).
LatLng fakeGeocode(String address) {
  final h = address.trim().toLowerCase().hashCode;
  return LatLng(
    lat: _medellin.lat + ((h % 1000) - 500) / 10000.0,
    lng: _medellin.lng + (((h ~/ 1000) % 1000) - 500) / 10000.0,
  );
}

/// Display text for a pin-dropped point: no reverse geocoding available
/// (the Geocoding API isn't enabled), so the raw coordinate is the honest
/// thing to show — same call the web client makes for its own un-geocoded
/// GPS fix.
String _formatCoordinate(LatLng position) =>
    '${position.lat.toStringAsFixed(5)}, ${position.lng.toStringAsFixed(5)}';

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

/// FND-6: the customer picked a real Places suggestion for pickup — sets
/// both the display address and a real coordinate, so [fakeGeocode] is no
/// longer used for this point until the customer types over it by hand.
final class RequestPickupLocationSelected extends RequestEvent {
  const RequestPickupLocationSelected(this.details);
  final PlaceDetails details;
}

/// Same as [RequestPickupLocationSelected], for dropoff.
final class RequestDropoffLocationSelected extends RequestEvent {
  const RequestDropoffLocationSelected(this.details);
  final PlaceDetails details;
}

/// FND-6: the customer dragged the pickup pin to refine it (only possible
/// once one exists — a search already placed it; see the CUS-1 doc note on
/// why pin-only placement, with no prior search, isn't built). No reverse
/// geocoding available (the Geocoding API isn't enabled — see the FND-6
/// note in `01-foundations.md`), so [RequestState.pickupAddress] becomes a
/// plain formatted coordinate string, same honest "show the raw lat/lng"
/// choice the web client makes for its own un-geocoded GPS fix
/// (`RequestPage.tsx`).
final class RequestPickupPinMoved extends RequestEvent {
  const RequestPickupPinMoved(this.position);
  final LatLng position;
}

/// Same as [RequestPickupPinMoved], for dropoff.
final class RequestDropoffPinMoved extends RequestEvent {
  const RequestDropoffPinMoved(this.position);
  final LatLng position;
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

/// Internal (FND-6/CUS-4): a `driver_location` WS push arrived for the
/// active job.
final class RequestDriverPositionUpdated extends RequestEvent {
  const RequestDriverPositionUpdated(this.position);
  final LatLng position;
}

/// CUS-5: the customer confirms delivery on a `delivered` job. [paymentMethod]
/// null (the default) is the original cash path, unchanged; PAY-4: a
/// non-null digital method ("nequi"/"pse"/"card") opts into a Wompi
/// checkout instead — see [JobsRepository.confirmDelivery]'s doc comment.
final class RequestDeliveryConfirmed extends RequestEvent {
  const RequestDeliveryConfirmed({this.paymentMethod});
  final String? paymentMethod;
}

/// Drives the CUS-1/2/3 flow: inputs → quote → confirm → matching →
/// assigned / no-drivers. Pure bloc, fully testable without widgets.
///
/// CUS-4: when [activeJobStore] is provided, this also rehydrates whatever
/// job was in progress the last time the app ran (see [_rehydrate]) and
/// keeps the store in sync as [RequestState.activeJob] changes (see
/// [onChange]) — the one piece of this app's state that needs to survive a
/// full app restart, not just navigating away and back. When [socket] is
/// provided, also relays the assigned driver's live position
/// (`ServerMessage.driverLocation`) into [RequestState.driverPosition] for
/// as long as a job is active — null under fakes (no socket).
class RequestBloc extends Bloc<RequestEvent, RequestState> {
  RequestBloc({
    required JobsRepository jobsRepository,
    ActiveJobStore? activeJobStore,
    CraneSocket? socket,
  })  : _repo = jobsRepository,
        _store = activeJobStore,
        _socket = socket,
        super(const RequestState()) {
    on<RequestPickupChanged>((event, emit) async {
      if (event.value == state.pickupAddress) return;
      // FND-6: manual typing invalidates whatever real coordinate a Places
      // selection previously set for this field -- the customer is now
      // describing a different point, so fakeGeocode(event.value) should
      // take back over until they pick a new suggestion (or don't).
      emit(state.copyWith(pickupAddress: event.value, pickupLatLng: null));
      await _refreshQuote(emit);
    });
    on<RequestDropoffChanged>((event, emit) async {
      if (event.value == state.dropoffAddress) return;
      emit(state.copyWith(dropoffAddress: event.value, dropoffLatLng: null));
      await _refreshQuote(emit);
    });
    on<RequestPickupLocationSelected>((event, emit) async {
      emit(state.copyWith(
        pickupAddress: event.details.formattedAddress,
        pickupLatLng: LatLng(lat: event.details.lat, lng: event.details.lng),
      ));
      await _refreshQuote(emit);
    });
    on<RequestDropoffLocationSelected>((event, emit) async {
      emit(state.copyWith(
        dropoffAddress: event.details.formattedAddress,
        dropoffLatLng: LatLng(lat: event.details.lat, lng: event.details.lng),
      ));
      await _refreshQuote(emit);
    });
    on<RequestPickupPinMoved>((event, emit) async {
      emit(state.copyWith(
        pickupAddress: _formatCoordinate(event.position),
        pickupLatLng: event.position,
      ));
      await _refreshQuote(emit);
    });
    on<RequestDropoffPinMoved>((event, emit) async {
      emit(state.copyWith(
        dropoffAddress: _formatCoordinate(event.position),
        dropoffLatLng: event.position,
      ));
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
      unawaited(_driverLocationSub?.cancel());
      _driverLocationSub = null;
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
      emit(state.copyWith(activeJob: null, driverPosition: null));
    });
    on<RequestJobUpdated>((event, emit) {
      emit(state.copyWith(activeJob: event.job));
    });
    on<RequestDriverPositionUpdated>((event, emit) {
      emit(state.copyWith(driverPosition: event.position));
    });
    on<RequestDeliveryConfirmed>(
      (event, emit) => _confirmDelivery(emit, paymentMethod: event.paymentMethod),
    );

    unawaited(_rehydrate());
  }

  final JobsRepository _repo;
  final ActiveJobStore? _store;
  final CraneSocket? _socket;
  StreamSubscription<Job>? _jobSub;
  StreamSubscription<ServerMessage>? _driverLocationSub;
  int _quoteToken = 0;
  Timer? _staleQuoteTimer;

  /// CUS-2: how long a quote is trusted for when the backend doesn't say
  /// otherwise (`Quote.expiresAt` null) — mirrors the backend's own
  /// `QUOTE_TTL_SECONDS` default (`backend/app/services/pricing.py`), for
  /// whichever `JobsRepository` implementation doesn't populate it (in
  /// practice: none as of this check — `ApiJobsRepository.requestQuote`
  /// now derives it from `expires_in_seconds`, and the fake sets it
  /// directly — but this stays as a sensible fallback rather than assuming
  /// that never changes).
  static const _defaultQuoteTtl = Duration(minutes: 10);

  /// FND-6: the real Places coordinate for the current pickup input if one
  /// was selected and not since typed over, else [fakeGeocode] of whatever
  /// text is there.
  LatLng get _pickupCoord => state.pickupLatLng ?? fakeGeocode(state.pickupAddress);

  /// Same as [_pickupCoord], for dropoff.
  LatLng get _dropoffCoord => state.dropoffLatLng ?? fakeGeocode(state.dropoffAddress);

  Future<void> _refreshQuote(Emitter<RequestState> emit) async {
    // Any input change invalidates whatever quote request is in flight —
    // including a stale one this same re-fetch is about to replace.
    _staleQuoteTimer?.cancel();
    final token = ++_quoteToken;
    if (!state.canQuote) {
      emit(state.copyWith(quote: null, isQuoting: false, quoteFailed: false));
      return;
    }
    emit(state.copyWith(quote: null, isQuoting: true, quoteFailed: false));
    try {
      final quote = await _repo.requestQuote(
        pickup: _pickupCoord,
        dropoff: _dropoffCoord,
        vehicleType: state.vehicleType,
      );
      if (token != _quoteToken) return;
      emit(state.copyWith(quote: quote, isQuoting: false));
      _scheduleStaleRefresh(quote);
    } catch (_) {
      if (token != _quoteToken) return;
      emit(state.copyWith(isQuoting: false, quoteFailed: true));
    }
  }

  /// CUS-2: once [quote] would go stale, automatically re-requests a fresh
  /// one rather than letting the customer try to confirm at a stale price.
  /// A single one-shot `Timer` per quote is the simplest correct approach —
  /// no periodic polling needed, since a fresh quote just reschedules this
  /// again from the top.
  ///
  /// Re-checked at fire time, not just at schedule time: a lot can happen
  /// in up to ~10 minutes, so this is a no-op if [quote] has already been
  /// superseded (a newer quote, or the customer already confirmed and
  /// moved on to matching) by the time the timer actually fires.
  void _scheduleStaleRefresh(Quote quote) {
    final now = DateTime.now();
    final staleAt = quote.expiresAt ?? now.add(_defaultQuoteTtl);
    final delay = staleAt.isAfter(now) ? staleAt.difference(now) : Duration.zero;
    _staleQuoteTimer = Timer(delay, () {
      if (isClosed) return;
      if (state.quote?.quoteId != quote.quoteId) return;
      if (state.activeJob != null) return;
      add(const RequestQuoteRefreshed());
    });
  }

  Future<void> _confirm(Emitter<RequestState> emit) async {
    final quote = state.quote;
    if (quote == null || state.isCreatingJob) return;
    emit(state.copyWith(isCreatingJob: true, createJobFailed: false));
    try {
      final job = await _repo.createJob(
        quoteId: quote.quoteId,
        vehicleType: state.vehicleType,
        pickup: _pickupCoord,
        pickupAddress: state.pickupAddress.trim(),
        dropoff: _dropoffCoord,
        dropoffAddress: state.dropoffAddress.trim(),
      );
      // CUS-2: the quote is spent — nothing left for the stale-refresh
      // timer to do.
      _staleQuoteTimer?.cancel();
      emit(state.copyWith(activeJob: job, isCreatingJob: false));
      _watch(job.id);
    } catch (_) {
      emit(state.copyWith(isCreatingJob: false, createJobFailed: true));
    }
  }

  Future<void> _confirmDelivery(Emitter<RequestState> emit, {String? paymentMethod}) async {
    final job = state.activeJob;
    if (job == null ||
        job.status != JobStatus.delivered ||
        state.isConfirmingDelivery) {
      return;
    }
    emit(state.copyWith(
      isConfirmingDelivery: true,
      confirmDeliveryFailed: false,
      confirmDeliveryErrorMessage: null,
    ));
    try {
      final updated = await _repo.confirmDelivery(job.id, paymentMethod: paymentMethod);
      // The `watchJob` subscription above will likely deliver the same
      // snapshot too (fake broadcast / WS push) — emitting it here as well
      // means the UI doesn't wait on that round trip to see `completed`.
      emit(state.copyWith(activeJob: updated, isConfirmingDelivery: false));
    } on JobStatusRejectedException catch (e) {
      // PAY-4: the 422 "digital fares not enabled" case (the app has no way
      // to know that flag's state ahead of time — see the doc note) surfaces
      // here with the backend's own detail string, same "show the real
      // message" convention ActiveJobCubit's advance()/cancel() already use.
      emit(state.copyWith(
        isConfirmingDelivery: false,
        confirmDeliveryFailed: true,
        confirmDeliveryErrorMessage: e.message,
      ));
    } catch (_) {
      emit(state.copyWith(isConfirmingDelivery: false, confirmDeliveryFailed: true));
    }
  }

  void _watch(String jobId) {
    _jobSub?.cancel();
    _jobSub = _repo.watchJob(jobId).listen((job) {
      if (!isClosed) add(RequestJobUpdated(job));
    });
    // FND-6/CUS-4: relay this job's live driver position, if a socket was
    // wired (null under fakes — nothing to relay). `messages` is shared
    // across every job the socket ever sees, so filter to this one.
    final socket = _socket;
    if (socket == null) return;
    unawaited(_driverLocationSub?.cancel());
    _driverLocationSub = socket.messages.listen((message) {
      if (isClosed) return;
      if (message case ServerMessageDriverLocation(
            jobId: final messageJobId,
            lat: final lat,
            lng: final lng,
          )
          when messageJobId == jobId) {
        add(RequestDriverPositionUpdated(LatLng(lat: lat, lng: lng)));
      }
    });
  }

  /// CUS-4: on construction, resumes whichever job [_store] has on record
  /// from a previous run — re-fetched fresh rather than trusted as-is, since
  /// only the id was ever persisted. A job that's gone terminal since (or
  /// vanished / errors on fetch) just clears the stale id; there's nothing
  /// to resume either way.
  Future<void> _rehydrate() async {
    final store = _store;
    if (store == null) return;
    final jobId = await store.read();
    if (jobId == null || isClosed) return;
    try {
      final job = await _repo.getJob(jobId);
      if (isClosed) return;
      if (job.status.isTerminal) {
        await store.write(null);
        return;
      }
      add(RequestJobUpdated(job));
      _watch(job.id);
    } catch (_) {
      // Gone, or unreachable right now — either way, not resumable from a
      // stale id alone.
      await store.write(null);
    }
  }

  /// CUS-4: the one place [_store] is written, so every handler above that
  /// changes [RequestState.activeJob] (`_confirm`, [RequestJobUpdated],
  /// [RequestMatchingAbandoned], [_confirmDelivery], plus [_rehydrate]
  /// itself) doesn't need its own write call. Only reacts to an actual
  /// change in *which id is worth persisting* — a terminal job persists as
  /// null, same as no job at all — so unrelated state changes (typing an
  /// address, a quote refreshing) don't touch storage.
  @override
  void onChange(Change<RequestState> change) {
    super.onChange(change);
    final store = _store;
    if (store == null) return;
    String? persistedId(Job? job) =>
        (job != null && !job.status.isTerminal) ? job.id : null;
    final previous = persistedId(change.currentState.activeJob);
    final next = persistedId(change.nextState.activeJob);
    if (previous != next) unawaited(store.write(next));
  }

  @override
  Future<void> close() {
    _jobSub?.cancel();
    unawaited(_driverLocationSub?.cancel());
    _staleQuoteTimer?.cancel();
    return super.close();
  }
}
