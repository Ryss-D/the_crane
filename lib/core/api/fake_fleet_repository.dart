import '../models/driver_profile.dart';
import '../models/fleet.dart';
import '../models/truck.dart';
import 'fake_auth_repository.dart';
import 'fleet_repository.dart';

/// In-memory [FleetRepository], used while `Env.useFakeBackend` is true.
///
/// Mirrors the real backend's global `trucks` table: [_trucks] holds every
/// truck the fake "system" knows about (fleet or no fleet), and the
/// caller's [Fleet.trucks] is just the ones whose `fleetId` matches. Two
/// seed trucks are pre-linked onto whatever fleet [createFleet] makes next
/// (one with an available driver, one offline) so "Mi flota" (FLT-3) has
/// something to show right away; one starts genuinely unclaimed and one
/// starts already claimed by a different (unmodeled) fleet, so FLT-4's
/// add-truck flow has both the happy and "already claimed" path to hit.
class FakeFleetRepository implements FleetRepository {
  /// [seeded] defaults to false — a fresh dev install/customer has no fleet
  /// until they actually go through the "become a fleet owner" flow (which
  /// then exercises [createFleet]'s real 409-on-double-create guard).
  /// Widget/cubit tests that sign in directly as `UserRole.fleetOwner` (to
  /// test the FLT-3/4/5 screens rather than the creation flow itself) pass
  /// `seeded: true` instead, so a fleet already exists to load.
  FakeFleetRepository({
    FakeAuthRepository? auth,
    this.actionDelay = const Duration(milliseconds: 300),
    bool seeded = false,
  }) : _auth = auth {
    if (seeded) _seedFleet();
  }

  void _seedFleet() {
    _fleetId = 'fleet-${++_seq}';
    _fleetName = 'Mi flota';
    _createdAt = DateTime.now();
    for (final id in const ['trk-fleet-1', 'trk-fleet-2']) {
      final index = _indexById(id);
      _trucks[index] = _trucks[index].copyWith(fleetId: _fleetId);
    }
  }

  /// AUTH-5/FLT-1: shared with [FakeAuthRepository] so [createFleet] can
  /// flip the fake signed-in user's role the same way the real backend
  /// does in the same request — the real client picks this up on its next
  /// `AuthCubit.refreshUser()` re-sync; this fake mirrors that by mutating
  /// the shared fake user directly. Null in tests that don't wire one up.
  final FakeAuthRepository? _auth;
  final Duration actionDelay;

  String? _fleetId;
  String _fleetName = '';
  DateTime? _createdAt;
  int _seq = 0;

  final List<Truck> _trucks = [
    const Truck(
      id: 'trk-fleet-1',
      plate: 'FLT001',
      type: TruckType.flatbed,
      capacity: TruckCapacity.both,
      driverId: 'drv-fleet-1',
      driverStatus: DriverStatus.available,
      driverName: 'Camilo Ríos',
    ),
    const Truck(
      id: 'trk-fleet-2',
      plate: 'FLT002',
      type: TruckType.car,
      capacity: TruckCapacity.car,
      driverId: 'drv-fleet-2',
      driverStatus: DriverStatus.offline,
      driverName: 'Laura Gómez',
    ),
    const Truck(
      id: 'trk-unclaimed-1',
      plate: 'NEW001',
      type: TruckType.motoOnly,
      capacity: TruckCapacity.moto,
    ),
    const Truck(
      id: 'trk-claimed-1',
      plate: 'OTR001',
      type: TruckType.car,
      capacity: TruckCapacity.car,
      fleetId: 'other-fleet-1',
    ),
  ];

  Fleet _buildFleet() => Fleet(
        id: _fleetId!,
        ownerUserId: 'fleet-owner-001',
        name: _fleetName,
        createdAt: _createdAt!,
        trucks: _trucks.where((t) => t.fleetId == _fleetId).toList(),
      );

  int _indexById(String truckId) =>
      _trucks.indexWhere((t) => t.id == truckId);

  @override
  Future<Fleet> createFleet({required String name}) async {
    await Future<void>.delayed(actionDelay);
    if (_fleetId != null) throw StateError('Already owns a fleet');
    _seedFleet();
    _fleetName = name;
    _auth?.debugPromoteToFleetOwner();
    return _buildFleet();
  }

  @override
  Future<Fleet> getMyFleet() async {
    await Future<void>.delayed(actionDelay);
    if (_fleetId == null) throw StateError('Fleet not found');
    return _buildFleet();
  }

  @override
  Future<Truck> findTruckByPlate(String plate) async {
    await Future<void>.delayed(actionDelay);
    for (final truck in _trucks) {
      if (truck.plate == plate) return truck;
    }
    throw TruckNotFoundException();
  }

  @override
  Future<Fleet> attachTruck(String truckId) async {
    await Future<void>.delayed(actionDelay);
    if (_fleetId == null) throw StateError('Fleet not found');
    final index = _indexById(truckId);
    if (index == -1) throw StateError('Truck not found');
    if (_trucks[index].fleetId != null) {
      throw StateError('Truck already belongs to a fleet');
    }
    _trucks[index] = _trucks[index].copyWith(fleetId: _fleetId);
    return _buildFleet();
  }

  @override
  Future<Fleet> detachTruck(String truckId) async {
    await Future<void>.delayed(actionDelay);
    if (_fleetId == null) throw StateError('Fleet not found');
    final index = _indexById(truckId);
    if (index == -1 || _trucks[index].fleetId != _fleetId) {
      throw StateError('Truck is not a member of this fleet');
    }
    _trucks[index] = _trucks[index].copyWith(fleetId: null);
    return _buildFleet();
  }

  /// Dev-seeded balance, so FLT-5's earnings screen has something to show.
  /// Real balances are the FLT-2 ledger rollup — nothing here simulates
  /// that, it's just fixed seed data matching the two seed drivers above.
  @override
  Future<FleetBalance> getBalance() async {
    await Future<void>.delayed(actionDelay);
    if (_fleetId == null) throw StateError('Fleet not found');
    const members = [
      FleetMemberBalance(
        driverId: 'drv-fleet-1',
        name: 'Camilo Ríos',
        owedBalance: 45000,
      ),
      FleetMemberBalance(
        driverId: 'drv-fleet-2',
        name: 'Laura Gómez',
        owedBalance: 12000,
      ),
    ];
    return FleetBalance(
      fleetId: _fleetId!,
      owedBalance:
          members.fold<int>(0, (sum, member) => sum + member.owedBalance),
      members: members,
    );
  }
}
