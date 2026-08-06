import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { api } from '../../api';
import { fakeGeocode } from '../../api/geocode';
import type { LatLng, Quote, VehicleType } from '../../api/types';
import { useAuth } from '../../auth';
import { strings } from '../../i18n/strings';
import { useActiveJobStore } from '../../store/activeJob';
import { Button, Card } from '../../ui';
import { PhoneSignIn } from './PhoneSignIn';
import { QuoteCard } from './QuoteCard';
import { VehicleTypeSelector } from './VehicleTypeSelector';

export function RequestPage() {
  const { user } = useAuth();
  const navigate = useNavigate();
  const setActiveJob = useActiveJobStore((s) => s.setActiveJob);
  const activeJobId = useActiveJobStore((s) => s.jobId);

  const [pickup, setPickup] = useState('');
  const [dropoff, setDropoff] = useState('');
  // WEB-2: a real GPS fix from navigator.geolocation, when the customer used
  // "usar mi ubicación actual". Kept separate from the `pickup` text field so
  // a real coordinate (more accurate than a hash-derived fake point) can be
  // sent to quote()/createJob() while the field still shows something
  // readable — there's no reverse-geocoding available without a Maps key
  // (FND-6), so the field shows the raw coordinates, not a street address.
  // Cleared whenever the user edits the text by hand, since at that point
  // the coordinates no longer describe what's typed.
  const [pickupCoords, setPickupCoords] = useState<LatLng | null>(null);
  const [locating, setLocating] = useState(false);
  const [locationError, setLocationError] = useState(false);
  const [vehicleType, setVehicleType] = useState<VehicleType | null>(null);
  const [quote, setQuote] = useState<Quote | null>(null);

  function useCurrentLocation() {
    if (!('geolocation' in navigator)) {
      setLocationError(true);
      return;
    }
    setLocating(true);
    setLocationError(false);
    navigator.geolocation.getCurrentPosition(
      (position) => {
        const coords: LatLng = { lat: position.coords.latitude, lng: position.coords.longitude };
        setPickupCoords(coords);
        setPickup(strings.request.locationText(coords.lat, coords.lng));
        setQuote(null);
        setLocating(false);
      },
      () => {
        // Permission denied, timeout, or position unavailable — don't crash,
        // don't fill anything, just surface a brief message.
        setLocating(false);
        setLocationError(true);
      },
      { enableHighAccuracy: true, timeout: 10_000 },
    );
  }

  const quoteMutation = useMutation({
    mutationFn: () =>
      api.quote({
        vehicle_type: vehicleType as VehicleType,
        pickup: pickupCoords ?? fakeGeocode(pickup),
        dropoff: fakeGeocode(dropoff),
      }),
    onSuccess: setQuote,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      api.createJob({
        quote_id: (quote as Quote).quote_id,
        vehicle_type: vehicleType as VehicleType,
        pickup: { ...(pickupCoords ?? fakeGeocode(pickup)), address: pickup.trim() },
        dropoff: { ...fakeGeocode(dropoff), address: dropoff.trim() },
      }),
    onSuccess: (job) => {
      setActiveJob(job.id, job.status);
      navigate(`/jobs/${job.id}`);
    },
  });

  if (!user) return <PhoneSignIn />;

  const canQuote = pickup.trim().length > 0 && dropoff.trim().length > 0 && vehicleType !== null;

  const inputClass =
    'rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-base text-slate-100 placeholder:text-slate-500 focus:border-amber-500 focus:outline-none';

  return (
    <div className="flex flex-col gap-4">
      {activeJobId && (
        <Card className="flex items-center justify-between gap-2 border-amber-700/50">
          <span className="text-sm text-amber-200">{strings.request.activeJobBanner}</span>
          <Link to={`/jobs/${activeJobId}`} className="text-sm font-semibold text-amber-400">
            {strings.request.activeJobLink}
          </Link>
        </Card>
      )}

      {/* TODO(FND-6): replace with @vis.gl/react-google-maps map + Places
          Autocomplete + browser-geolocation pickup once the Maps key exists. */}
      <div
        aria-hidden
        className="flex h-40 items-center justify-center rounded-2xl border border-dashed border-slate-700 bg-slate-900 text-sm text-slate-500"
      >
        {strings.request.mapPlaceholder} — TODO(FND-6)
      </div>

      <Card className="flex flex-col gap-3">
        <h1 className="text-lg font-bold text-slate-100">{strings.request.title}</h1>
        <label className="flex flex-col gap-1 text-sm text-slate-300">
          {strings.request.pickupLabel}
          <div className="flex gap-2">
            <input
              value={pickup}
              onChange={(e) => {
                setPickup(e.target.value);
                setPickupCoords(null);
                setQuote(null);
              }}
              placeholder={strings.request.pickupPlaceholder}
              className={`${inputClass} flex-1`}
            />
            <button
              type="button"
              onClick={useCurrentLocation}
              disabled={locating}
              aria-label={strings.request.useCurrentLocation}
              title={strings.request.useCurrentLocation}
              className="flex shrink-0 items-center justify-center rounded-xl border border-slate-700 bg-slate-800 px-3 text-lg text-amber-400 transition-colors hover:bg-slate-700 disabled:cursor-not-allowed disabled:opacity-50"
            >
              <span aria-hidden>{locating ? '…' : '📍'}</span>
            </button>
          </div>
        </label>
        {locationError && (
          <p role="alert" className="text-sm text-rose-400">
            {strings.request.locationUnavailable}
          </p>
        )}
        <label className="flex flex-col gap-1 text-sm text-slate-300">
          {strings.request.dropoffLabel}
          <input
            value={dropoff}
            onChange={(e) => {
              setDropoff(e.target.value);
              setQuote(null);
            }}
            placeholder={strings.request.dropoffPlaceholder}
            className={inputClass}
          />
        </label>

        <div className="flex flex-col gap-1 text-sm text-slate-300">
          {strings.request.vehicleTypeLabel}
          <VehicleTypeSelector
            value={vehicleType}
            onChange={(v) => {
              setVehicleType(v);
              setQuote(null);
            }}
          />
        </div>

        <Button
          onClick={() => quoteMutation.mutate()}
          disabled={!canQuote || quoteMutation.isPending}
        >
          {quoteMutation.isPending ? strings.request.quoting : strings.request.getQuote}
        </Button>
        {quoteMutation.isError && (
          <p role="alert" className="text-sm text-rose-400">
            {strings.request.error}
          </p>
        )}
      </Card>

      {quote && (
        <QuoteCard
          quote={quote}
          onConfirm={() => createMutation.mutate()}
          confirming={createMutation.isPending}
        />
      )}
      {createMutation.isError && (
        <p role="alert" className="text-sm text-rose-400">
          {strings.request.createError}
        </p>
      )}
    </div>
  );
}
