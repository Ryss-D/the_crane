import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/drivers_repository.dart';
import '../../../core/models/driver_balance.dart';

part 'driver_balance_cubit.freezed.dart';

/// DRV-5 state: the driver's current commission balance, loaded once.
@freezed
abstract class DriverBalanceState with _$DriverBalanceState {
  const factory DriverBalanceState({
    DriverBalance? balance,
    @Default(true) bool isLoading,
    @Default(false) bool loadFailed,
  }) = _DriverBalanceState;
}

/// Drives the DRV-5 earnings/balance screen through
/// `DriversRepository.balance`. Also reused by DRV-4's active-job "done"
/// state to show the updated running balance right after a job completes.
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
}
