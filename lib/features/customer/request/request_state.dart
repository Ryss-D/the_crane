import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/models/job.dart';
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
    @Default(VehicleType.car) VehicleType vehicleType,
    Quote? quote,
    @Default(false) bool isQuoting,
    @Default(false) bool quoteFailed,
    @Default(false) bool isCreatingJob,
    @Default(false) bool createJobFailed,
    Job? activeJob,
  }) = _RequestState;

  /// Both endpoints entered — a quote can be requested.
  bool get canQuote =>
      pickupAddress.trim().isNotEmpty && dropoffAddress.trim().isNotEmpty;

  /// Quote in hand and no request in flight — confirm is tappable.
  bool get canConfirm => quote != null && !isQuoting && !isCreatingJob;
}
