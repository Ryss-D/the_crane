import '../models/place_prediction.dart';
import 'places_repository.dart';

/// A handful of real Medellín-area places with fixed coordinates, so
/// `Env.useFakeBackend` demos/tests get realistic-looking search results
/// without a real Places key. [autocomplete] does a simple
/// case-insensitive substring match against [description] -- good enough
/// for a fake, not meant to mimic Google's actual ranking.
class FakePlacesRepository implements PlacesRepository {
  FakePlacesRepository({this.delay = const Duration(milliseconds: 150)});

  final Duration delay;

  static final _places = <String, ({String description, PlaceDetails details})>{
    'place-poblado': (
      description: 'El Poblado, Medellín, Antioquia',
      details: const PlaceDetails(
        lat: 6.2088,
        lng: -75.5679,
        formattedAddress: 'El Poblado, Medellín, Antioquia',
      ),
    ),
    'place-laureles': (
      description: 'Laureles, Medellín, Antioquia',
      details: const PlaceDetails(
        lat: 6.2447,
        lng: -75.5916,
        formattedAddress: 'Laureles, Medellín, Antioquia',
      ),
    ),
    'place-envigado': (
      description: 'Envigado, Antioquia',
      details: const PlaceDetails(
        lat: 6.1701,
        lng: -75.5910,
        formattedAddress: 'Envigado, Antioquia',
      ),
    ),
    'place-bello': (
      description: 'Bello, Antioquia',
      details: const PlaceDetails(
        lat: 6.3373,
        lng: -75.5581,
        formattedAddress: 'Bello, Antioquia',
      ),
    ),
    'place-centro': (
      description: 'Centro, Medellín, Antioquia',
      details: const PlaceDetails(
        lat: 6.2518,
        lng: -75.5636,
        formattedAddress: 'Centro, Medellín, Antioquia',
      ),
    ),
  };

  @override
  Future<List<PlacePrediction>> autocomplete(String input) async {
    await Future<void>.delayed(delay);
    final query = input.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return _places.entries
        .where((e) => e.value.description.toLowerCase().contains(query))
        .map((e) => PlacePrediction(placeId: e.key, description: e.value.description))
        .toList(growable: false);
  }

  @override
  Future<PlaceDetails> placeDetails(String placeId) async {
    await Future<void>.delayed(delay);
    final place = _places[placeId];
    if (place == null) {
      throw ArgumentError('Unknown fake place id: $placeId');
    }
    return place.details;
  }
}
