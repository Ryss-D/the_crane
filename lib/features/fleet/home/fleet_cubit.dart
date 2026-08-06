import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/fleet_repository.dart';
import '../../../core/models/fleet.dart';

part 'fleet_cubit.freezed.dart';

/// FLT-3 state: the caller's fleet, loaded once and refreshed after
/// FLT-4's attach/detach actions.
@freezed
abstract class FleetState with _$FleetState {
  const factory FleetState({
    Fleet? fleet,
    @Default(true) bool isLoading,
    @Default(false) bool loadFailed,
  }) = _FleetState;
}

/// Drives the FLT-3 "Mi flota" screen through [FleetRepository].
class FleetCubit extends Cubit<FleetState> {
  FleetCubit({required FleetRepository fleetRepository})
      : _repo = fleetRepository,
        super(const FleetState());

  final FleetRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, loadFailed: false));
    try {
      final fleet = await _repo.getMyFleet();
      emit(state.copyWith(fleet: fleet, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, loadFailed: true));
    }
  }

  /// FLT-4: re-fetches the fleet after an attach/detach action elsewhere so
  /// "Mi flota" reflects the new truck list without a manual pull-to-refresh.
  Future<void> refresh() => load();
}
