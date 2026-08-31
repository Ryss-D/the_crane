import '../models/lat_lng.dart';
import 'directions_repository.dart';

/// A straight line between the two points -- no real road geometry, just
/// enough for `Env.useFakeBackend` demos/tests to render *a* polyline.
class FakeDirectionsRepository implements DirectionsRepository {
  FakeDirectionsRepository({this.delay = const Duration(milliseconds: 100)});

  final Duration delay;

  @override
  Future<List<LatLng>> route({
    required LatLng origin,
    required LatLng destination,
  }) async {
    await Future<void>.delayed(delay);
    return [origin, destination];
  }
}
