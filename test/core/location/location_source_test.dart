import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:the_crane/core/location/location_source.dart';

/// Swaps geolocator's platform-interface singleton, same technique the
/// `geolocator` plugin itself expects platform implementations to use
/// (`GeolocatorPlatform.instance = ...`, guarded by `PlatformInterface`'s
/// token check) — lets [GeolocatorLocationSource]'s actual branching logic
/// run against controlled fixtures instead of a real device/simulator.
class _FakeGeolocatorPlatform extends GeolocatorPlatform {
  bool serviceEnabled = true;
  LocationPermission checkResult = LocationPermission.denied;
  LocationPermission requestResult = LocationPermission.whileInUse;
  int requestPermissionCalls = 0;

  Position? currentPosition;
  Stream<Position> positionStream = const Stream.empty();

  @override
  Future<bool> isLocationServiceEnabled() async => serviceEnabled;

  @override
  Future<LocationPermission> checkPermission() async => checkResult;

  @override
  Future<LocationPermission> requestPermission() async {
    requestPermissionCalls++;
    return requestResult;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async => currentPosition!;

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) =>
      positionStream;
}

Position _position({double lat = 6.24, double lng = -75.58}) => Position(
  latitude: lat,
  longitude: lng,
  timestamp: DateTime(2026, 1, 1),
  accuracy: 0,
  altitude: 0,
  altitudeAccuracy: 0,
  heading: 0,
  headingAccuracy: 0,
  speed: 0,
  speedAccuracy: 0,
);

void main() {
  late _FakeGeolocatorPlatform fakePlatform;
  late GeolocatorLocationSource source;

  setUp(() {
    fakePlatform = _FakeGeolocatorPlatform();
    GeolocatorPlatform.instance = fakePlatform;
    source = GeolocatorLocationSource();
  });

  group('requestPermission', () {
    test('false when location services are disabled, without asking for '
        'permission at all', () async {
      fakePlatform.serviceEnabled = false;

      final granted = await source.requestPermission();

      expect(granted, isFalse);
      expect(fakePlatform.requestPermissionCalls, 0);
    });

    test('prompts when permission was never decided, and returns true once '
        'the prompt grants whileInUse', () async {
      fakePlatform.checkResult = LocationPermission.denied;
      fakePlatform.requestResult = LocationPermission.whileInUse;

      final granted = await source.requestPermission();

      expect(granted, isTrue);
      expect(fakePlatform.requestPermissionCalls, 1);
    });

    test('false when the prompt is denied again', () async {
      fakePlatform.checkResult = LocationPermission.denied;
      fakePlatform.requestResult = LocationPermission.denied;

      final granted = await source.requestPermission();

      expect(granted, isFalse);
    });

    test('does not re-prompt when permission is already whileInUse', () async {
      fakePlatform.checkResult = LocationPermission.whileInUse;

      final granted = await source.requestPermission();

      expect(granted, isTrue);
      expect(fakePlatform.requestPermissionCalls, 0);
    });

    test('true when permission is already always', () async {
      fakePlatform.checkResult = LocationPermission.always;

      final granted = await source.requestPermission();

      expect(granted, isTrue);
    });

    test('false when already permanently denied (never re-prompts)', () async {
      fakePlatform.checkResult = LocationPermission.deniedForever;

      final granted = await source.requestPermission();

      expect(granted, isFalse);
      expect(fakePlatform.requestPermissionCalls, 0);
    });
  });

  test('getCurrentPosition maps the platform Position to LatLng', () async {
    fakePlatform.currentPosition = _position(lat: 6.2442, lng: -75.5812);

    final fix = await source.getCurrentPosition();

    expect(fix.lat, 6.2442);
    expect(fix.lng, -75.5812);
  });

  test('watchPosition maps every emitted Position to LatLng', () async {
    fakePlatform.positionStream = Stream.fromIterable([
      _position(lat: 1, lng: 2),
      _position(lat: 3, lng: 4),
    ]);

    final fixes = await source.watchPosition().toList();

    expect(fixes.map((f) => (f.lat, f.lng)), [(1.0, 2.0), (3.0, 4.0)]);
  });
}
