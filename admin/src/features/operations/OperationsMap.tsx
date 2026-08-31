import { APIProvider, Map, Marker } from '@vis.gl/react-google-maps';
import type { Job } from '../../api/types';
import { strings } from '../../i18n/strings';

/** Medellín city center — same anchor the Flutter app and web-client use
 * for their own map defaults, so every surface centers consistently. */
const MEDELLIN = { lat: 6.2442, lng: -75.5812 };

export interface OperationsMapProps {
  jobs: Job[];
  onSelectJob: (jobId: string) => void;
}

/**
 * ADM-5 follow-up — a live jobs map: one pin per visible (post status-filter)
 * job, at its pickup point (a job's "location" for dispatch purposes is
 * where it originates, not its destination). Clicking a pin opens that
 * job's detail, same as clicking its row in the list below.
 *
 * Plain legacy `Marker`, not `AdvancedMarker` — the latter needs a Map ID
 * configured in Cloud Console (Maps Management), which doesn't exist yet;
 * mirrors the same choice `web-client`'s `RequestMap`/`TrackingMap` already
 * made for the same reason.
 *
 * No live driver position: unlike the customer-facing tracking pages (which
 * get `driver_location` over the job's own WebSocket channel), there is no
 * admin-facing endpoint or WS channel that exposes a driver's *current*
 * position across many jobs at once — `GET /v1/admin/jobs/{id}` only
 * returns historical `location_snapshots` (recorded at status transitions)
 * for one job's detail view, not a live feed for a list. Showing pickup
 * pins only is what the real data actually supports; a live fleet-position
 * overlay is a real, separate gap, not attempted here.
 *
 * Renders nothing when `VITE_GOOGLE_MAPS_API_KEY` is unset, same fallback
 * convention as web-client's map components.
 */
export function OperationsMap({ jobs, onSelectJob }: OperationsMapProps) {
  const apiKey = import.meta.env.VITE_GOOGLE_MAPS_API_KEY;
  if (!apiKey) return null;

  return (
    <div data-testid="operations-map" className="h-64 w-full overflow-hidden rounded-2xl">
      <APIProvider apiKey={apiKey}>
        <Map
          defaultCenter={MEDELLIN}
          defaultZoom={12}
          gestureHandling="greedy"
          disableDefaultUI
          style={{ width: '100%', height: '100%' }}
        >
          {jobs.map((job) => (
            <Marker
              key={job.id}
              position={{ lat: job.pickup_lat, lng: job.pickup_lng }}
              title={`${job.customer_name} · ${strings.jobStatuses[job.status]}`}
              onClick={() => onSelectJob(job.id)}
            />
          ))}
        </Map>
      </APIProvider>
    </div>
  );
}
