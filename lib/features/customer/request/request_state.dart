import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/job.dart';
import '../../../core/models/lat_lng.dart';
import '../../../core/models/quote.dart';

part 'request_state.freezed.dart';

/// State of the customer request flow (CUS-1/2/3): draft inputs, the current
/// quote and the job being matched.
@freezed
abstract class RequestState with _$RequestState {
  const RequestState._();

  const factory RequestState({
    @Default('') String pickupAddress,
    @Default('') String dropoffAddress,
    // FND-6: real coordinates once resolved via Places search or pin-drag.
    // Null means "no real fix yet for whatever's currently in the matching
    // *Address field" — `fakeGeocode` stands in for that address text until
    // a real one arrives, same "explicit coords win, typed text falls back
    // to fakeGeocode" contract the web client already ships
    // (`RequestPage.tsx`'s `pickupCoords`).
    LatLng? pickupLatLng,
    LatLng? dropoffLatLng,
    @Default(VehicleType.car) VehicleType vehicleType,
    Quote? quote,
    @Default(false) bool isQuoting,
    @Default(false) bool quoteFailed,
    @Default(false) bool isCreatingJob,
    @Default(false) bool createJobFailed,
    Job? activeJob,
    @Default(false) bool isConfirmingDelivery,
    @Default(false) bool confirmDeliveryFailed,
    // PAY-4: the backend's own rejection detail (e.g. "Digital fares are
    // not enabled") when confirmDelivery's failure was a typed
    // JobStatusRejectedException — null for any other failure (network,
    // etc.), which still just flips confirmDeliveryFailed with no message
    // of its own, same as before this field existed.
    String? confirmDeliveryErrorMessage,
    // FND-6/CUS-4: the assigned driver's live position, from the WS
    // `driver_location` push (`ServerMessage.driverLocation`) — was already
    // parsed but never consumed anywhere before this. Null under fakes (no
    // socket) and until the first push for the active job arrives.
    LatLng? driverPosition,
  }) = _RequestState;

  /// Both endpoints entered — a quote can be requested.
  bool get canQuote =>
      pickupAddress.trim().isNotEmpty && dropoffAddress.trim().isNotEmpty;

  /// Quote in hand and no request in flight — confirm is tappable.
  bool get canConfirm => quote != null && !isQuoting && !isCreatingJob;
}
