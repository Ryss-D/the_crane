import { APIProvider, Map, Marker } from '@vis.gl/react-google-maps';
import type { LatLng } from '../../api/types';

/** Medellín city center — same anchor `fakeGeocode` (src/api/geocode.ts) uses,
 * so the default view matches where addresses fall back to when ungeocoded. */
const MEDELLIN: LatLng = { lat: 6.2442, lng: -75.5812 };

export interface RequestMapProps {
  pickup: LatLng | null;
  dropoff: LatLng | null;
  onPickupDrag: (coords: LatLng) => void;
  onDropoffDrag: (coords: LatLng) => void;
}

/**
 * CUS-1/WEB-2: pickup ("A")/dropoff ("B") pins, draggable to fine-tune a
 * Places-selected or GPS-derived point. Plain legacy `Marker`, not
 * `AdvancedMarker` — the latter requires a Map ID configured in Cloud
 * Console (Maps Management), which doesn't exist yet; revisit once one
 * does, `AdvancedMarker` is Google's recommended marker going forward.
 *
 * Renders nothing (not even the container) when `VITE_GOOGLE_MAPS_API_KEY`
 * is unset — a misconfigured env shouldn't crash the request flow, just
 * silently drop the map (the address text fields still work standalone).
 */
export function RequestMap({ pickup, dropoff, onPickupDrag, onDropoffDrag }: RequestMapProps) {
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;
  if (!apiKey) return null;

  const center = pickup ?? dropoff ?? MEDELLIN;

  return (
    <div data-testid="request-map" className="h-40 w-full overflow-hidden rounded-2xl">
      <APIProvider apiKey={apiKey}>
        <Map
          defaultCenter={center}
          defaultZoom={pickup || dropoff ? 14 : 12}
          gestureHandling="greedy"
          disableDefaultUI
          style={{ width: '100%', height: '100%' }}
        >
          {pickup && (
            <Marker
              position={pickup}
              draggable
              label="A"
              title="Recogida"
              onDragEnd={(e) => {
                const pos = e.latLng;
                if (pos) onPickupDrag({ lat: pos.lat(), lng: pos.lng() });
              }}
            />
          )}
          {dropoff && (
            <Marker
              position={dropoff}
              draggable
              label="B"
              title="Destino"
              onDragEnd={(e) => {
                const pos = e.latLng;
                if (pos) onDropoffDrag({ lat: pos.lat(), lng: pos.lng() });
              }}
            />
          )}
        </Map>
      </APIProvider>
    </div>
  );
}
