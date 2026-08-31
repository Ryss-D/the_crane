import 'package:freezed_annotation/freezed_annotation.dart';

part 'driver_balance.freezed.dart';
part 'driver_balance.g.dart';

/// One historical settlement/payout against a driver's owed balance.
/// Matches `GET /v1/drivers/me/balance`'s `recent_settlements` items:
/// `{"id": str, "amount_cents": int, "settled_at": ISO8601, "note": str?}`.
///
/// NOTE on units: despite the `_cents` naming in the documented contract,
/// every other money field in this codebase (`Job.quotedPrice`,
/// `Quote.price`, etc.) is a plain integer COP amount — the backend's own
/// money columns are `Numeric(12, 0)` with no decimals at all (see
/// `backend/app/models/ledger.py`). [amountCents] is treated the same way
/// here (formatted directly via `formatCop`, not divided by 100). Flag for
/// reconciliation if the backend team's shipped endpoint disagrees.
@freezed
abstract class Settlement with _$Settlement {
  const factory Settlement({
    required String id,
    required int amountCents,
    required DateTime settledAt,
    String? note,
  }) = _Settlement;

  factory Settlement.fromJson(Map<String, dynamic> json) =>
      _$SettlementFromJson(json);
}

/// A driver's current commission balance (DRV-5/LED-1), as returned by
/// `GET /v1/drivers/me/balance`:
/// ```
/// {
///   "owed_cents": int,
///   "balance_cap_cents": int | null,
///   "recent_settlements": [Settlement, ...]
/// }
/// ```
/// See [Settlement] for the same units caveat — [owedCents]/
/// [balanceCapCents] are plain integer COP here too.
@freezed
abstract class DriverBalance with _$DriverBalance {
  const factory DriverBalance({
    required int owedCents,
    int? balanceCapCents,
    @Default(<Settlement>[]) List<Settlement> recentSettlements,
  }) = _DriverBalance;

  factory DriverBalance.fromJson(Map<String, dynamic> json) =>
      _$DriverBalanceFromJson(json);
}

/// PAY-3 — a digital-settlement method the driver's balance can be paid
/// down with via `POST /v1/drivers/me/settle`. Mirrors the backend's
/// `PaymentMethod` enum (`backend/app/models/job.py`), restricted to the
/// three that make sense for a driver-initiated payout: `cash`/`wallet`
/// aren't checkout-based, so they're not offered here.
enum SettlementPaymentMethod {
  nequi('nequi'),
  pse('pse'),
  card('card');

  const SettlementPaymentMethod(this.wire);

  final String wire;
}

/// What `POST /v1/drivers/me/settle` hands back — enough to complete the
/// checkout, not a balance change (that only happens once Wompi's webhook
/// reports the payment approved; poll [DriversRepository.balance]
/// afterward to see it reflected).
@freezed
abstract class SettlementCheckout with _$SettlementCheckout {
  const factory SettlementCheckout({
    required String paymentReference,
    String? asyncPaymentUrl,
  }) = _SettlementCheckout;
}
