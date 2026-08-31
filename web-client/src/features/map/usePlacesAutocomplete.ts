import { useEffect, useRef } from 'react';
import type { RefObject } from 'react';
import { useMapsLibrary } from '@vis.gl/react-google-maps';
import type { LatLng } from '../../api/types';

/** Valle de Aburrá bounding box — biases Autocomplete results toward the
 * launch market without hard-excluding the rest of the country (that's what
 * `componentRestrictions.country` below is for). */
const VALLE_DE_ABURRA_BOUNDS = { north: 6.45, south: 6.05, east: -75.4, west: -75.75 };

/**
 * Attaches Google Places Autocomplete to a plain `<input>` ref.
 *
 * `@vis.gl/react-google-maps` ships no ready-made Autocomplete component —
 * this is the documented pattern for using the vanilla `google.maps.places`
 * API alongside it (`useMapsLibrary('places')` loads the library, then the
 * legacy `places.Autocomplete` widget attaches itself to the DOM node
 * directly, same as it would with no React wrapper at all). Must be called
 * from a component rendered inside an `<APIProvider>`.
 *
 * `onPlaceSelected` is read via a ref rather than a hook dependency so the
 * `Autocomplete` instance is created once (when the library finishes
 * loading) and never torn down/recreated on every keystroke's re-render —
 * only the callback's *latest* closure needs to be current, not the
 * instance itself.
 */
export function usePlacesAutocomplete(
  inputRef: RefObject<HTMLInputElement | null>,
  onPlaceSelected: (coords: LatLng, address: string) => void,
): void {
  const places = useMapsLibrary('places');
  const onPlaceSelectedRef = useRef(onPlaceSelected);
  onPlaceSelectedRef.current = onPlaceSelected;

  useEffect(() => {
    if (!places || !inputRef.current) return;

    const autocomplete = new places.Autocomplete(inputRef.current, {
      componentRestrictions: { country: 'co' },
      fields: ['geometry', 'formatted_address', 'name'],
      bounds: VALLE_DE_ABURRA_BOUNDS,
    });

    const listener = autocomplete.addListener('place_changed', () => {
      const place = autocomplete.getPlace();
      const location = place.geometry?.location;
      // No geometry means the user pressed Enter/blurred without picking a
      // suggestion — nothing to report, the plain typed text stays as-is
      // and falls back to fakeGeocode same as before this hook existed.
      if (!location) return;
      onPlaceSelectedRef.current(
        { lat: location.lat(), lng: location.lng() },
        place.formatted_address ?? place.name ?? '',
      );
    });

    return () => listener.remove();
  }, [places, inputRef]);
}
