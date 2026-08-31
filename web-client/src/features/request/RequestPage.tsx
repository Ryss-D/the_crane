import { useEffect, useRef, useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { api } from '../../api';
import { fakeGeocode } from '../../api/geocode';
import type { LatLng, Quote, VehicleType } from '../../api/types';
import { useAuth } from '../../auth';
import { strings } from '../../i18n/strings';
import { useActiveJobStore } from '../../store/activeJob';
import { Button, Card } from '../../ui';
import { CompleteProfileForm } from './CompleteProfileForm';
import { PhoneSignIn } from './PhoneSignIn';
import { QuoteCard } from './QuoteCard';
import { RequestMap } from '../map/RequestMap';
import { usePlacesAutocomplete } from '../map/usePlacesAutocomplete';
import { VehicleTypeSelector } from './VehicleTypeSelector';

export function RequestPage() {
  const { user, profile } = useAuth();
  const navigate = useNavigate();
  const setActiveJob = useActiveJobStore((s) => s.setActiveJob);
  const activeJobId = useActiveJobStore((s) => s.jobId);

  const [pickup, setPickup] = useState('');
  const [dropoff, setDropoff] = useState('');
  // WEB-2: a real coordinate — from browser geolocation ("usar mi ubicación
  // actual"), a dragged map pin, or a selected Places suggestion — kept
  // separate from the text field so the *real* point (more accurate than a
  // hash-derived fake one) can be sent to quote()/createJob() while the
  // field shows something readable. Cleared whenever the user edits the
  // text field by hand, since at that point the coordinates no longer
  // describe what's typed; `fakeGeocode` is the fallback once that happens
  // (or if Places/the map are unavailable at all).
  const [pickupCoords, setPickupCoords] = useState<LatLng | null>(null);
  // FND-6 follow-up: dropoff gets the same treatment now that Places/the map
  // exist — previously always `fakeGeocode`, with no way to set a real point.
  const [dropoffCoords, setDropoffCoords] = useState<LatLng | null>(null);
  const [locating, setLocating] = useState(false);
  const [locationError, setLocationError] = useState(false);
  const [vehicleType, setVehicleType] = useState<VehicleType | null>(null);
  const [quote, setQuote] = useState<Quote | null>(null);
  // WEB-1 follow-up: quoting is public now (see backend's create_quote
  // docstring) -- the sign-in/profile gate no longer blocks the whole page,
  // it only appears once the customer tries to *confirm* a quote. Set when
  // Confirm is pressed without a usable identity yet; cleared either once
  // that identity completes (which auto-fires createMutation below) or the
  // quote itself goes stale, so a leftover gate doesn't reappear next time
  // a fresh quote is fetched.
  const [awaitingAuth, setAwaitingAuth] = useState(false);

  const pickupInputRef = useRef<HTMLInputElement>(null);
  const dropoffInputRef = useRef<HTMLInputElement>(null);
  // Reverse-geocoding follow-up (CUS-1/CUS-4/WEB-2): the coordinate object
  // most recently set for each field, kept outside React state so a
  // background reverseGeocode() resolution can tell (by reference equality)
  // whether it's still describing the current point — if the user has since
  // typed over the field, dragged again, or picked a new Places suggestion,
  // the ref no longer matches and the stale resolution is dropped instead
  // of clobbering whatever is showing by then.
  const pickupCoordsRef = useRef<LatLng | null>(null);
  const dropoffCoordsRef = useRef<LatLng | null>(null);

  function updatePickupCoords(coords: LatLng | null) {
    pickupCoordsRef.current = coords;
    setPickupCoords(coords);
  }

  function updateDropoffCoords(coords: LatLng | null) {
    dropoffCoordsRef.current = coords;
    setDropoffCoords(coords);
  }

  /**
   * Reverse-geocoding follow-up: shows [coords] as the raw `(lat, lng)` text
   * immediately — same behavior as before this change, and still exactly
   * what a GPS fix or a dragged pin shows today, since no server-side
   * Google Maps key exists yet in this environment — then upgrades to a
   * real address in the background if `reverseGeocode()` resolves one.
   * Never regresses: a null result (no key, not signed in yet, or any
   * other failure) just leaves the coordinate text standing.
   */
  function setPickupFromRawCoords(coords: LatLng) {
    updatePickupCoords(coords);
    setPickup(strings.request.locationText(coords.lat, coords.lng));
    setQuote(null);
    void api.reverseGeocode(coords.lat, coords.lng).then((address) => {
      if (address && pickupCoordsRef.current === coords) setPickup(address);
    });
  }

  /** Same as {@link setPickupFromRawCoords}, for dropoff. */
  function setDropoffFromRawCoords(coords: LatLng) {
    updateDropoffCoords(coords);
    setDropoff(strings.request.locationText(coords.lat, coords.lng));
    setQuote(null);
    void api.reverseGeocode(coords.lat, coords.lng).then((address) => {
      if (address && dropoffCoordsRef.current === coords) setDropoff(address);
    });
  }

  usePlacesAutocomplete(pickupInputRef, (coords, address) => {
    updatePickupCoords(coords);
    setPickup(address);
    setQuote(null);
  });
  usePlacesAutocomplete(dropoffInputRef, (coords, address) => {
    updateDropoffCoords(coords);
    setDropoff(address);
    setQuote(null);
  });

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
        setPickupFromRawCoords(coords);
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
        dropoff: dropoffCoords ?? fakeGeocode(dropoff),
      }),
    onSuccess: setQuote,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      api.createJob({
        quote_id: (quote as Quote).quote_id,
        vehicle_type: vehicleType as VehicleType,
        pickup: { ...(pickupCoords ?? fakeGeocode(pickup)), address: pickup.trim() },
        dropoff: { ...(dropoffCoords ?? fakeGeocode(dropoff)), address: dropoff.trim() },
      }),
    onSuccess: (job) => {
      setActiveJob(job.id, job.status);
      navigate(`/jobs/${job.id}`);
    },
  });

  useEffect(() => {
    if (!quote) {
      setAwaitingAuth(false);
      return;
    }
    if (awaitingAuth && user && profile?.name) {
      setAwaitingAuth(false);
      createMutation.mutate();
    }
    // createMutation is a fresh object every render (react-query doesn't
    // memoize it) -- depending on it here would re-fire this effect every
    // render and loop, since `.mutate()` triggers a pending-state render.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [quote, awaitingAuth, user, profile]);

  function onConfirm() {
    if (user && profile?.name) {
      createMutation.mutate();
    } else {
      // Not signed in, or signed in but `profile` hasn't synced/hasn't got a
      // name yet — same AUTH-3/WEB-1 profile-completion requirement as
      // before, just deferred to this moment instead of gating page load.
      setAwaitingAuth(true);
    }
  }

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

      {/* FND-6 follow-up: real map now, when the key is configured. Falls
          back to the same dashed placeholder box if it isn't — matches the
          non-fatal "silently drop the map" contract RequestMap documents. */}
      {import.meta.env.VITE_GOOGLE_MAPS_API_KEY ? (
        <RequestMap
          pickup={pickupCoords}
          dropoff={dropoffCoords}
          onPickupDrag={setPickupFromRawCoords}
          onDropoffDrag={setDropoffFromRawCoords}
        />
      ) : (
        <div
          aria-hidden
          className="flex h-40 items-center justify-center rounded-2xl border border-dashed border-slate-700 bg-slate-900 text-sm text-slate-500"
        >
          {strings.request.mapPlaceholder} — TODO(FND-6)
        </div>
      )}

      <Card className="flex flex-col gap-3">
        <h1 className="text-lg font-bold text-slate-100">{strings.request.title}</h1>
        <label className="flex flex-col gap-1 text-sm text-slate-300">
          {strings.request.pickupLabel}
          <div className="flex gap-2">
            <input
              ref={pickupInputRef}
              value={pickup}
              onChange={(e) => {
                setPickup(e.target.value);
                updatePickupCoords(null);
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
            ref={dropoffInputRef}
            value={dropoff}
            onChange={(e) => {
              setDropoff(e.target.value);
              updateDropoffCoords(null);
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
        <>
          <QuoteCard quote={quote} onConfirm={onConfirm} confirming={createMutation.isPending} />
          {/* WEB-1 follow-up: identity is only asked for at this point, not
              before -- see `awaitingAuth` above. */}
          {awaitingAuth && !user && <PhoneSignIn />}
          {awaitingAuth && user && profile && !profile.name && <CompleteProfileForm />}
        </>
      )}
      {createMutation.isError && (
        <p role="alert" className="text-sm text-rose-400">
          {strings.request.createError}
        </p>
      )}
    </div>
  );
}
