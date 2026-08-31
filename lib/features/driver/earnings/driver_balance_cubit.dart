import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/models/driver_balance.dart';

part 'driver_balance_cubit.freezed.dart';

/// DRV-5 state: the driver's current commission balance, loaded once, plus
/// PAY-3's in-flight/last-result settlement attempt.
@freezed
abstract class DriverBalanceState with _$DriverBalanceState {
  const factory DriverBalanceState({
    DriverBalance? balance,
    @Default(true) bool isLoading,
    @Default(false) bool loadFailed,
    @Default(false) bool isSettling,
    // Transient: the UI consumes these once (open the URL / show the
    // message) and calls `clearSettlementResult` — they don't persist
    // across rebuilds the way `balance` does.
    SettlementCheckout? lastCheckout,
    String? settlementError,
  }) = _DriverBalanceState;
}

/// Drives the DRV-5 earnings/balance screen through
/// `DriversRepository.balance`. Also reused by DRV-4's active-job "done"
/// state to show the updated running balance right after a job completes.
///
/// PAY-3: also drives "pay my balance" via `DriversRepository.settleBalance`
/// — starts a Wompi checkout, never touches [DriverBalanceState.balance]
/// itself (the real balance only moves once Wompi's webhook reports the
/// payment approved; call [load] again later to see it reflected).
class DriverBalanceCubit extends Cubit<DriverBalanceState> {
  DriverBalanceCubit({required DriversRepository driversRepository})
      : _repo = driversRepository,
        super(const DriverBalanceState());

  final DriversRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, loadFailed: false));
    try {
      final balance = await _repo.balance();
      emit(state.copyWith(balance: balance, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, loadFailed: true));
    }
  }

  Future<void> settle({
    required int amountCop,
    required SettlementPaymentMethod method,
  }) async {
    if (state.isSettling) return;
    emit(state.copyWith(isSettling: true, settlementError: null, lastCheckout: null));
    try {
      final checkout = await _repo.settleBalance(amountCop: amountCop, method: method);
      emit(state.copyWith(isSettling: false, lastCheckout: checkout));
    } on SettlementRejectedException catch (e) {
      emit(state.copyWith(isSettling: false, settlementError: e.message));
    } catch (_) {
      emit(state.copyWith(isSettling: false, settlementError: null));
    }
  }

  /// Call once the UI has acted on [DriverBalanceState.lastCheckout]/
  /// [DriverBalanceState.settlementError] (opened the URL, shown the
  /// message) so it doesn't fire again on the next unrelated rebuild.
  void clearSettlementResult() {
    emit(state.copyWith(lastCheckout: null, settlementError: null));
  }
}
