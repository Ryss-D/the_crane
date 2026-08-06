import '../models/job.dart';
import '../models/saved_vehicle.dart';
import 'vehicles_repository.dart';

/// In-memory [VehiclesRepository], seeded with a couple of vehicles so the
/// CUS-6 screens have something to show under `Env.useFakeBackend`.
class FakeVehiclesRepository implements VehiclesRepository {
  FakeVehiclesRepository({this.delay = const Duration(milliseconds: 150)}) {
    _vehicles.addAll(const [
      SavedVehicle(
        id: 'veh-1',
        type: VehicleType.car,
        make: 'Chevrolet',
        model: 'Spark',
        plate: 'ABC123',
      ),
      SavedVehicle(
        id: 'veh-2',
        type: VehicleType.moto,
        make: 'Yamaha',
        model: 'FZ',
        plate: 'XYZ987',
      ),
    ]);
  }

  final Duration delay;
  final List<SavedVehicle> _vehicles = [];
  int _seq = 2;

  @override
  Future<List<SavedVehicle>> listVehicles() async {
    await Future<void>.delayed(delay);
    return List.unmodifiable(_vehicles);
  }

  @override
  Future<SavedVehicle> createVehicle({
    required VehicleType type,
    String? make,
    String? model,
    required String plate,
  }) async {
    await Future<void>.delayed(delay);
    final vehicle = SavedVehicle(
      id: 'veh-${++_seq}',
      type: type,
      make: make,
      model: model,
      plate: plate,
    );
    _vehicles.add(vehicle);
    return vehicle;
  }

  @override
  Future<SavedVehicle> updateVehicle(
    String id, {
    VehicleType? type,
    String? make,
    String? model,
    String? plate,
  }) async {
    await Future<void>.delayed(delay);
    final index = _vehicles.indexWhere((vehicle) => vehicle.id == id);
    if (index == -1) throw StateError('Unknown vehicle: $id');
    final updated = _vehicles[index].copyWith(
      type: type ?? _vehicles[index].type,
      make: make ?? _vehicles[index].make,
      model: model ?? _vehicles[index].model,
      plate: plate ?? _vehicles[index].plate,
    );
    _vehicles[index] = updated;
    return updated;
  }

  @override
  Future<void> deleteVehicle(String id) async {
    await Future<void>.delayed(delay);
    _vehicles.removeWhere((vehicle) => vehicle.id == id);
  }
}
