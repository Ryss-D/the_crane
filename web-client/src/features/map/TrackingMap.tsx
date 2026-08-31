import { APIProvider, Map, Marker } from '@vis.gl/react-google-maps';
import type { LatLng } from '../../api/types';

export interface TrackingMapProps {
  pickup: LatLng;
  dropoff: LatLng;
  /** Null until the backend has a live fix for this job (driver not yet
   * assigned, or a `driver_location` event/poll hasn't arrived yet). */
  driverLocation: LatLng | null;
}

/**
 * CUS-4/WEB-3/WEB-4: read-only map for the authenticated tracking page and
 * the public share-track page alike — same three possible pins (pickup,
 * dropoff, driver), no interaction. No route polyline: unlike the Flutter
 * app's DRV-3 (which calls the Directions API for real turn-by-turn nav),
 * nothing in this task asked for one here and the backend doesn't compute
 * a route for either page's data — this only plots the points it's given.
 *
 * Renders nothing when `VITE_GOOGLE_MAPS_API_KEY` is unset, same fallback
 * as `RequestMap`.
 */
export function TrackingMap({ pickup, dropoff, driverLocation }: TrackingMapProps) {
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;
  if (!apiKey) return null;

  return (
    <div data-testid="tracking-map" className="h-40 w-full overflow-hidden rounded-2xl">
      <APIProvider apiKey={apiKey}>
        <Map
          defaultCenter={driverLocation ?? pickup}
          defaultZoom={13}
          gestureHandling="greedy"
          disableDefaultUI
          style={{ width: '100%', height: '100%' }}
        >
          <Marker position={pickup} label="A" title="Recogida" />
          <Marker position={dropoff} label="B" title="Destino" />
          {driverLocation && (
            <Marker
              position={driverLocation}
              title="Grúa"
              icon={{
                path: 'M -6,-6 6,-6 6,6 -6,6 z',
                fillColor: '#f59e0b',
                fillOpacity: 1,
                strokeColor: '#78350f',
                strokeWeight: 1,
              }}
            />
          )}
        </Map>
      </APIProvider>
    </div>
  );
}
