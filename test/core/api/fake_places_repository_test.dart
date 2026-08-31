import 'package:flutter_test/flutter_test.dart';
import 'package:the_crane/core/api/fake_places_repository.dart';

/// Reverse-geocoding follow-up (CUS-1/CUS-4/WEB-2): [FakePlacesRepository]
/// never had its own unit tests before this -- `autocomplete`/`placeDetails`
/// are only ever exercised indirectly through `PlacesAutocompleteField`
/// widget tests. `reverseGeocode` is new enough (and pure/self-contained
/// enough -- no widget needed) to warrant a direct test instead.
void main() {
  group('FakePlacesRepository.reverseGeocode', () {
    test('resolves to the nearest seeded fake place', () async {
      final repo = FakePlacesRepository(delay: Duration.zero);
      // Right on top of the seeded El Poblado coordinate.
      final address = await repo.reverseGeocode(6.2088, -75.5679);
      expect(address, 'Cerca de El Poblado, Medellín, Antioquia');
    });

    test('picks a different nearest place for a different coordinate',
        () async {
      final repo = FakePlacesRepository(delay: Duration.zero);
      // Closer to the seeded Bello coordinate than to any other seed.
      final address = await repo.reverseGeocode(6.31, -75.61);
      expect(address, 'Cerca de Bello, Antioquia');
    });

    test('never returns null -- there is no "no key configured" state to '
        'simulate under fakes', () async {
      final repo = FakePlacesRepository(delay: Duration.zero);
      final address = await repo.reverseGeocode(0, 0);
      expect(address, isNotNull);
    });
  });
}
