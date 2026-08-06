import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/api/vehicles_repository.dart';
import '../../../core/models/job.dart';
import '../../../core/models/saved_vehicle.dart';

part 'saved_vehicles_cubit.freezed.dart';

/// CUS-6 state: the customer's saved vehicles, loaded once and mutated
/// in place as the list/add/edit/delete screen acts on them.
@freezed
abstract class SavedVehiclesState with _$SavedVehiclesState {
  const factory SavedVehiclesState({
    @Default(<SavedVehicle>[]) List<SavedVehicle> vehicles,
    @Default(true) bool isLoading,
    @Default(false) bool loadFailed,
    @Default(false) bool isSaving,
  }) = _SavedVehiclesState;
}

/// Drives the CUS-6 saved-vehicles screen through [VehiclesRepository].
class SavedVehiclesCubit extends Cubit<SavedVehiclesState> {
  SavedVehiclesCubit({required VehiclesRepository vehiclesRepository})
      : _repo = vehiclesRepository,
        super(const SavedVehiclesState());

  final VehiclesRepository _repo;

  Future<void> load() async {
    emit(state.copyWith(isLoading: true, loadFailed: false));
    try {
      final vehicles = await _repo.listVehicles();
      emit(state.copyWith(vehicles: vehicles, isLoading: false));
    } catch (_) {
      emit(state.copyWith(isLoading: false, loadFailed: true));
    }
  }

  /// Returns true on success, false on failure (the form dialog stays open
  /// and shows an error on false).
  Future<bool> create({
    required VehicleType type,
    String? make,
    String? model,
    required String plate,
  }) async {
    emit(state.copyWith(isSaving: true));
    try {
      final vehicle = await _repo.createVehicle(
        type: type,
        make: make,
        model: model,
        plate: plate,
      );
      emit(state.copyWith(
        vehicles: [...state.vehicles, vehicle],
        isSaving: false,
      ));
      return true;
    } catch (_) {
      emit(state.copyWith(isSaving: false));
      return false;
    }
  }

  Future<bool> update(
    String id, {
    VehicleType? type,
    String? make,
    String? model,
    String? plate,
  }) async {
    emit(state.copyWith(isSaving: true));
    try {
      final updated = await _repo.updateVehicle(
        id,
        type: type,
        make: make,
        model: model,
        plate: plate,
      );
      emit(state.copyWith(
        vehicles: [
          for (final vehicle in state.vehicles)
            if (vehicle.id == id) updated else vehicle,
        ],
        isSaving: false,
      ));
      return true;
    } catch (_) {
      emit(state.copyWith(isSaving: false));
      return false;
    }
  }

  Future<bool> delete(String id) async {
    try {
      await _repo.deleteVehicle(id);
      emit(state.copyWith(
        vehicles: state.vehicles.where((vehicle) => vehicle.id != id).toList(),
      ));
      return true;
    } catch (_) {
      return false;
    }
  }
}
