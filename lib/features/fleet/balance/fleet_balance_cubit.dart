import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/fleet_repository.dart';
import '../../../core/models/fleet.dart';

part 'fleet_balance_cubit.freezed.dart';

/// FLT-5 state: the fleet's consolidated commission balance, loaded once.
@freezed
abstract class FleetBalanceState with _$FleetBalanceState {
  const factory FleetBalanceState({
    FleetBalance? balance,
    @Default(true) bool isLoading,
    @Default(false) bool loadFailed,
  }) = _FleetBalanceState;
}

/// Drives the FLT-5 fleet earnings screen through [FleetRepository].
class FleetBalanceCubit extends Cubit<FleetBalanceState> {
  FleetBalanceCubit({required FleetRepository fleetRepository})
      : _repo = fleetRepository,
        super(const FleetBalanceState());

  final FleetRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, loadFailed: false));
    try {
      final balance = await _repo.getBalance();
      emit(state.copyWith(balance: balance, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, loadFailed: true));
    }
  }
}
