import 'package:freezed_annotation/freezed_annotation.dart';

import '../models/job.dart';
import '../models/lat_lng.dart';

part 'server_message.freezed.dart';

/// Parsed pushes from `WS /v1/ws` (TRK-1/2/3). The wire protocol —
/// `backend/app/api/ws.py`'s module docstring plus the `*Event` schemas in
/// `backend/app/schemas/job.py` — is the ground truth this union mirrors.
///
/// [ServerMessage.fromWire] is hand-written rather than generated: the
/// `type` field picks the variant, and `job_event` deliberately does *not*
/// try to reconstruct a full [Job] from its partial payload (it omits
/// addresses, distance, vehicle type, the driver summary, …). Instead it
/// carries just enough (`jobId`, `status`) for a listener to treat the push
/// as a "something changed, re-fetch" signal — see
/// `ApiJobsRepository.watchJob`, which does exactly that.
@freezed
sealed class ServerMessage with _$ServerMessage {
  const factory ServerMessage.subscribed({required String jobId}) =
      ServerMessageSubscribed;

  const factory ServerMessage.unsubscribed({required String jobId}) =
      ServerMessageUnsubscribed;

  const factory ServerMessage.jobEvent({
    required String jobId,
    required String status,
  }) = ServerMessageJobEvent;

  const factory ServerMessage.driverLocation({
    required String jobId,
    required double lat,
    required double lng,
  }) = ServerMessageDriverLocation;

  /// TRK-3, pushed straight to the offered driver's live connections.
  /// `quotedPrice`/`expiresInSeconds` mirror `JobOfferEvent`.
  /// `pickupDistanceKm`/`commissionAmount` are best-effort on the backend
  /// (`app/services/realtime.py::notify_driver_offer`) — null if the
  /// offered driver somehow has no live Redis geo position (distance) or
  /// `quotedPrice` is unset (commission); see `ApiDriversRepository._toJobOffer`
  /// for the fallback approximation used when either is missing.
  const factory ServerMessage.jobOffer({
    required String jobId,
    required String offerId,
    required VehicleType vehicleType,
    required LatLng pickup,
    required LatLng dropoff,
    int? quotedPrice,
    required int expiresInSeconds,
    double? pickupDistanceKm,
    int? commissionAmount,
  }) = ServerMessageJobOffer;

  /// Rejected client message. The server field is `detail` (see
  /// `app/api/ws.py`'s `manager.send_json(..., {"type": "error", "detail":
  /// ...})`); `message` is accepted too in case that ever changes.
  const factory ServerMessage.error({required String detail}) =
      ServerMessageError;

  /// Server heartbeat, ~every 20s. [CraneSocket] answers with `{"type":
  /// "pong"}` to keep the connection's activity clock fresh.
  const factory ServerMessage.ping() = ServerMessagePing;

  /// Anything unrecognized — a future message type, or a malformed frame.
  /// Kept instead of throwing so one bad push never kills the listener.
  const factory ServerMessage.unknown({required Map<String, dynamic> raw}) =
      ServerMessageUnknown;

  /// Parses one decoded JSON frame (already `jsonDecode`d into a map).
  factory ServerMessage.fromWire(Map<String, dynamic> json) {
    switch (json['type']) {
      case 'subscribed':
        final jobId = json['job_id'];
        if (jobId is String) return ServerMessage.subscribed(jobId: jobId);
      case 'unsubscribed':
        final jobId = json['job_id'];
        if (jobId is String) return ServerMessage.unsubscribed(jobId: jobId);
      case 'job_event':
        final jobId = json['job_id'];
        final status = json['status'];
        if (jobId is String && status is String) {
          return ServerMessage.jobEvent(jobId: jobId, status: status);
        }
      case 'driver_location':
        final jobId = json['job_id'];
        final lat = json['lat'];
        final lng = json['lng'];
        if (jobId is String && lat is num && lng is num) {
          return ServerMessage.driverLocation(
            jobId: jobId,
            lat: lat.toDouble(),
            lng: lng.toDouble(),
          );
        }
      case 'job_offer':
        final jobId = json['job_id'];
        final offerId = json['offer_id'];
        final vehicleType = json['vehicle_type'];
        final pickup = json['pickup'];
        final dropoff = json['dropoff'];
        final expiresIn = json['expires_in_seconds'];
        if (jobId is String &&
            offerId is String &&
            vehicleType is String &&
            pickup is Map<String, dynamic> &&
            dropoff is Map<String, dynamic> &&
            expiresIn is num) {
          return ServerMessage.jobOffer(
            jobId: jobId,
            offerId: offerId,
            vehicleType: _vehicleTypeFromWire(vehicleType),
            pickup: LatLng.fromJson(pickup),
            dropoff: LatLng.fromJson(dropoff),
            quotedPrice: (json['quoted_price'] as num?)?.toInt(),
            expiresInSeconds: expiresIn.toInt(),
            pickupDistanceKm: (json['pickup_distance_km'] as num?)?.toDouble(),
            commissionAmount: (json['commission_amount'] as num?)?.toInt(),
          );
        }
      case 'error':
        final detail = json['detail'] ?? json['message'];
        return ServerMessage.error(
          detail: detail is String ? detail : 'Unknown error',
        );
      case 'ping':
        return const ServerMessage.ping();
    }
    return ServerMessage.unknown(raw: json);
  }
}

VehicleType _vehicleTypeFromWire(String wire) => VehicleType.values
    .firstWhere((type) => type.wire == wire, orElse: () => VehicleType.car);
