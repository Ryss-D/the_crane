import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:the_crane/core/api/fleet_repository.dart';
import 'package:the_crane/core/models/driver_profile.dart';
import 'package:the_crane/core/models/fleet.dart';
import 'package:the_crane/core/models/truck.dart';

class MockDio extends Mock implements Dio {}

/// `FleetRead` shape, per `backend/app/schemas/fleet.py`.
Map<String, dynamic> _fleetJson({
  String id = 'fleet-1',
  String ownerUserId = 'owner-1',
  String name = 'Grúas del Valle',
  List<Map<String, dynamic>> trucks = const [],
}) => {
  'id': id,
  'owner_user_id': ownerUserId,
  'name': name,
  'created_at': '2026-01-01T00:00:00Z',
  'trucks': trucks,
};

/// `TruckRead` shape, per `backend/app/schemas/driver.py`. FLT-3's rollup
/// (`driver_status`/`driver_name`) is only ever populated here, by
/// `fleets.py::_serialize_fleet` -- other endpoints leave both null.
Map<String, dynamic> _truckJson({
  String id = 'truck-1',
  String? driverId,
  String? fleetId = 'fleet-1',
  String plate = 'ABC123',
  String type = 'flatbed',
  String capacity = 'car',
  String? driverStatus,
  String? driverName,
}) => {
  'id': id,
  'plate': plate,
  'type': type,
  'capacity': capacity,
  'driver_id': driverId,
  'fleet_id': fleetId,
  'driver_status': driverStatus,
  'driver_name': driverName,
};

/// `FleetBalanceRead` shape, per `backend/app/schemas/fleet.py`.
Map<String, dynamic> _balanceJson({
  String fleetId = 'fleet-1',
  int owedBalance = 0,
  List<Map<String, dynamic>> members = const [],
}) => {
  'fleet_id': fleetId,
  'owed_balance': owedBalance,
  'members': members,
};

Map<String, dynamic> _memberBalanceJson({
  String driverId = 'drv-1',
  String? name = 'Ana Torres',
  int owedBalance = 15000,
}) => {
  'driver_id': driverId,
  'name': name,
  'owed_balance': owedBalance,
};

/// `InviteRead` shape, per `backend/app/schemas/fleet.py`.
Map<String, dynamic> _inviteJson({
  String inviteToken = 'invite-1',
  String truckId = 'truck-2',
  String phone = '+573001234567',
}) => {
  'invite_token': inviteToken,
  'truck_id': truckId,
  'phone': phone,
};

Response<T> _okResponse<T>(
  T data, {
  int statusCode = 200,
  String path = '/x',
}) => Response(
  requestOptions: RequestOptions(path: path),
  statusCode: statusCode,
  data: data,
);

DioException _dioError(int statusCode, {String path = '/x', Object? data}) =>
    DioException(
      requestOptions: RequestOptions(path: path),
      response: Response(
        requestOptions: RequestOptions(path: path),
        statusCode: statusCode,
        data: data,
      ),
      type: DioExceptionType.badResponse,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  late MockDio dio;
  late ApiFleetRepository repo;

  setUp(() {
    dio = MockDio();
    repo = ApiFleetRepository(dio);
  });

  group('ApiFleetRepository.createFleet', () {
    test('posts {name} and parses the created fleet', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _okResponse(
          _fleetJson(id: 'fleet-9', name: 'Grúas del Norte'),
          statusCode: 201,
        ),
      );

      final fleet = await repo.createFleet(name: 'Grúas del Norte');

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/fleets/me');
      expect(captured[1], {'name': 'Grúas del Norte'});
      expect(fleet.id, 'fleet-9');
      expect(fleet.name, 'Grúas del Norte');
      expect(fleet.trucks, isEmpty);
    });

    test('propagates a 409 when the caller already owns a fleet', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(_dioError(409, path: '/v1/fleets/me'));

      expect(
        () => repo.createFleet(name: 'x'),
        throwsA(
          isA<DioException>()
              .having((e) => e.response?.statusCode, 'statusCode', 409),
        ),
      );
    });
  });

  group('ApiFleetRepository.getMyFleet', () {
    test(
        'gets /v1/fleets/me and parses trucks with the FLT-3 driver-status '
        'rollup', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(
          _fleetJson(trucks: [
            _truckJson(
              id: 'truck-1',
              driverId: 'drv-1',
              driverStatus: 'available',
              driverName: 'Ana Torres',
            ),
            _truckJson(id: 'truck-2', plate: 'XYZ999'),
          ]),
        ),
      );

      final fleet = await repo.getMyFleet();

      verify(() => dio.get<Map<String, dynamic>>('/v1/fleets/me')).called(1);
      expect(fleet.trucks, hasLength(2));
      expect(fleet.trucks[0].driverStatus, DriverStatus.available);
      expect(fleet.trucks[0].driverName, 'Ana Torres');
      expect(fleet.trucks[1].driverStatus, isNull);
      expect(fleet.trucks[1].plate, 'XYZ999');
    });

    test('propagates a 404 when the caller has no fleet yet', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenThrow(_dioError(404, path: '/v1/fleets/me'));

      expect(() => repo.getMyFleet(), throwsA(isA<DioException>()));
    });
  });

  group('ApiFleetRepository.findTruckByPlate', () {
    test('gets by-plate and parses the truck', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_truckJson(plate: 'PLT001', fleetId: null)),
      );

      final truck = await repo.findTruckByPlate('PLT001');

      verify(
        () => dio.get<Map<String, dynamic>>('/v1/fleets/trucks/by-plate/PLT001'),
      ).called(1);
      expect(truck.plate, 'PLT001');
      expect(truck.fleetId, isNull);
    });

    test('maps a 404 into TruckNotFoundException', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        _dioError(404, path: '/v1/fleets/trucks/by-plate/NOPE'),
      );

      expect(
        () => repo.findTruckByPlate('NOPE'),
        throwsA(isA<TruckNotFoundException>()),
      );
    });

    test('rethrows a plain DioException for other status codes', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        _dioError(500, path: '/v1/fleets/trucks/by-plate/X'),
      );

      expect(
        () => repo.findTruckByPlate('X'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiFleetRepository.attachTruck', () {
    test('posts to /me/trucks/{id} with no body and parses the fleet',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(
          _fleetJson(trucks: [_truckJson(id: 'truck-3')]),
        ),
      );

      final fleet = await repo.attachTruck('truck-3');

      verify(
        () => dio.post<Map<String, dynamic>>('/v1/fleets/me/trucks/truck-3'),
      ).called(1);
      expect(fleet.trucks, hasLength(1));
      expect(fleet.trucks.single.id, 'truck-3');
    });

    test('propagates a 409 when the truck already belongs to a fleet',
        () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        _dioError(409, path: '/v1/fleets/me/trucks/truck-3'),
      );

      expect(
        () => repo.attachTruck('truck-3'),
        throwsA(isA<DioException>()),
      );
    });

    test('propagates a 404 when the truck doesn\'t exist', () async {
      when(() => dio.post<Map<String, dynamic>>(any())).thenThrow(
        _dioError(404, path: '/v1/fleets/me/trucks/unknown'),
      );

      expect(
        () => repo.attachTruck('unknown'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiFleetRepository.detachTruck', () {
    test('deletes /me/trucks/{id} and parses the fleet', () async {
      when(() => dio.delete<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(_fleetJson(trucks: const [])),
      );

      final fleet = await repo.detachTruck('truck-3');

      verify(
        () => dio.delete<Map<String, dynamic>>('/v1/fleets/me/trucks/truck-3'),
      ).called(1);
      expect(fleet.trucks, isEmpty);
    });

    test('propagates a 404 when the truck isn\'t a member of this fleet',
        () async {
      when(() => dio.delete<Map<String, dynamic>>(any())).thenThrow(
        _dioError(404, path: '/v1/fleets/me/trucks/truck-3'),
      );

      expect(
        () => repo.detachTruck('truck-3'),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiFleetRepository.getBalance', () {
    test('gets /v1/fleets/me/balance and parses the per-driver breakdown',
        () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => _okResponse(
          _balanceJson(
            owedBalance: 37500,
            members: [
              _memberBalanceJson(driverId: 'drv-1', owedBalance: 15000),
              _memberBalanceJson(driverId: 'drv-2', name: null, owedBalance: 22500),
            ],
          ),
        ),
      );

      final balance = await repo.getBalance();

      verify(() => dio.get<Map<String, dynamic>>('/v1/fleets/me/balance'))
          .called(1);
      expect(balance.owedBalance, 37500);
      expect(balance.members, hasLength(2));
      expect(balance.members[0].driverId, 'drv-1');
      expect(balance.members[0].owedBalance, 15000);
      expect(balance.members[1].name, isNull);
    });

    test('propagates a 404 when the caller has no fleet', () async {
      when(() => dio.get<Map<String, dynamic>>(any()))
          .thenThrow(_dioError(404, path: '/v1/fleets/me/balance'));

      expect(() => repo.getBalance(), throwsA(isA<DioException>()));
    });
  });

  group('ApiFleetRepository.createInvite', () {
    test('posts phone/plate/truck_type/capacity and parses the invite',
        () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenAnswer(
        (_) async => _okResponse(
          _inviteJson(inviteToken: 'invite-9', truckId: 'truck-9'),
          statusCode: 201,
        ),
      );

      final invite = await repo.createInvite(
        phone: '+573001234567',
        plate: 'INV009',
        truckType: TruckType.car,
        capacity: TruckCapacity.car,
      );

      final captured = verify(
        () => dio.post<Map<String, dynamic>>(
          captureAny(),
          data: captureAny(named: 'data'),
        ),
      ).captured;
      expect(captured[0], '/v1/fleets/me/invites');
      expect(captured[1], {
        'phone': '+573001234567',
        'plate': 'INV009',
        'truck_type': 'car',
        'capacity': 'car',
      });
      expect(invite.inviteToken, 'invite-9');
      expect(invite.truckId, 'truck-9');
    });

    test('propagates a 409 when the phone already has a pending invite',
        () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(_dioError(409, path: '/v1/fleets/me/invites'));

      expect(
        () => repo.createInvite(
          phone: '+573001234567',
          plate: 'X',
          truckType: TruckType.car,
          capacity: TruckCapacity.car,
        ),
        throwsA(isA<DioException>()),
      );
    });

    test('propagates a 409 when the plate is already registered', () async {
      when(
        () => dio.post<Map<String, dynamic>>(any(), data: any(named: 'data')),
      ).thenThrow(_dioError(409, path: '/v1/fleets/me/invites'));

      expect(
        () => repo.createInvite(
          phone: '+573000000000',
          plate: 'TAKEN1',
          truckType: TruckType.flatbed,
          capacity: TruckCapacity.both,
        ),
        throwsA(isA<DioException>()),
      );
    });
  });

  group('ApiFleetRepository.listInvites', () {
    test('gets a bare JSON array and parses every pending invite', () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => _okResponse<List<dynamic>>([
          _inviteJson(inviteToken: 'invite-1', phone: '+573001111111'),
          _inviteJson(inviteToken: 'invite-2', phone: '+573002222222'),
        ]),
      );

      final invites = await repo.listInvites();

      verify(() => dio.get<List<dynamic>>('/v1/fleets/me/invites')).called(1);
      expect(invites, hasLength(2));
      expect(invites[0].inviteToken, 'invite-1');
      expect(invites[1].phone, '+573002222222');
    });

    test('returns an empty list when there are no pending invites',
        () async {
      when(() => dio.get<List<dynamic>>(any())).thenAnswer(
        (_) async => _okResponse<List<dynamic>>(<dynamic>[]),
      );

      final invites = await repo.listInvites();

      expect(invites, isEmpty);
    });

    test('propagates a 404 when the caller has no fleet', () async {
      when(() => dio.get<List<dynamic>>(any()))
          .thenThrow(_dioError(404, path: '/v1/fleets/me/invites'));

      expect(() => repo.listInvites(), throwsA(isA<DioException>()));
    });
  });

  // Every repository call above only ever exercises `fromJson` (the
  // backend -> Flutter direction). Nothing in the app ever sends a `Fleet`/
  // `FleetBalance`/`DriverInvite` back to the server, so `toJson` has no
  // other call site to be covered from -- these round-trips are here purely
  // to close that gap.
  group('Fleet/FleetBalance/DriverInvite toJson round-trips', () {
    test('Fleet round-trips through JSON, including nested trucks', () {
      final fleet = Fleet(
        id: 'fleet-1',
        ownerUserId: 'owner-1',
        name: 'Grúas del Valle',
        createdAt: DateTime.utc(2026, 1, 1),
        trucks: const [
          Truck(
            id: 'truck-1',
            plate: 'ABC123',
            type: TruckType.flatbed,
            capacity: TruckCapacity.car,
          ),
        ],
      );

      final round = Fleet.fromJson(fleet.toJson());

      expect(round, fleet);
    });

    test('FleetBalance round-trips through JSON, including members', () {
      const balance = FleetBalance(
        fleetId: 'fleet-1',
        owedBalance: 37500,
        members: [
          FleetMemberBalance(driverId: 'drv-1', name: 'Ana Torres', owedBalance: 15000),
          FleetMemberBalance(driverId: 'drv-2', owedBalance: 22500),
        ],
      );

      expect(FleetBalance.fromJson(balance.toJson()), balance);
    });

    test('DriverInvite round-trips through JSON', () {
      const invite = DriverInvite(
        inviteToken: 'invite-1',
        truckId: 'truck-2',
        phone: '+573001234567',
      );

      expect(DriverInvite.fromJson(invite.toJson()), invite);
    });
  });
}
