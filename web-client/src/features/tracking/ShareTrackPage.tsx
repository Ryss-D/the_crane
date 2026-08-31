import { useParams } from 'react-router-dom';
import { useQuery } from '@tanstack/react-query';
import { api } from '../../api';
import { strings } from '../../i18n/strings';
import { Card } from '../../ui';
import { POLL_INTERVAL_MS } from '../../ws/useJobSocket';
import { TrackingMap } from '../map/TrackingMap';
import { StatusTimeline } from './StatusTimeline';

/**
 * Public share-track page (/t/{token}) — read-only, token-scoped, NO auth.
 * Reuses the same timeline as the customer tracking page.
 */
export function ShareTrackPage() {
  const { token = '' } = useParams<'token'>();

  const trackQuery = useQuery({
    queryKey: ['track', token],
    queryFn: () => api.getTrack(token),
    refetchInterval: POLL_INTERVAL_MS,
    enabled: token.length > 0,
  });

  if (trackQuery.isPending) {
    return <p className="text-center text-sm text-slate-400">{strings.tracking.loading}</p>;
  }
  if (trackQuery.isError || !trackQuery.data) {
    return (
      <p role="alert" className="text-center text-sm text-rose-400">
        {strings.tracking.notFound}
      </p>
    );
  }

  const track = trackQuery.data;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-lg font-bold text-slate-100">{strings.tracking.publicTitle}</h1>
      <p className="text-xs text-slate-500">{strings.tracking.publicNote}</p>

      {import.meta.env.VITE_GOOGLE_MAPS_API_KEY ? (
        <TrackingMap
          pickup={track.pickup}
          dropoff={track.dropoff}
          driverLocation={track.driver_location}
        />
      ) : (
        <div
          aria-hidden
          className="flex h-40 items-center justify-center rounded-2xl border border-dashed border-slate-700 bg-slate-900 text-sm text-slate-500"
        >
          {strings.request.mapPlaceholder} — TODO(FND-6)
        </div>
      )}

      {track.driver && (
        <Card className="flex flex-col gap-2 text-sm text-slate-300">
          <p>
            {strings.tracking.driverTitle}:{' '}
            <span className="font-semibold">{track.driver.first_name}</span>
          </p>
          {track.driver.truck_plate && (
            <p>
              {strings.tracking.plateLabel}:{' '}
              <span className="font-semibold">{track.driver.truck_plate}</span>
            </p>
          )}
        </Card>
      )}

      <Card>
        <StatusTimeline status={track.status} />
        <p className="text-xs text-slate-600">{strings.tracking.pollNote}</p>
      </Card>
    </div>
  );
}
