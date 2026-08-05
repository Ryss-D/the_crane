import { useState } from 'react';
import { Link, useNavigate } from 'react-router-dom';
import { useMutation } from '@tanstack/react-query';
import { api } from '../../api';
import type { Quote, VehicleType } from '../../api/types';
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
  const [vehicleType, setVehicleType] = useState<VehicleType | null>(null);
  const [quote, setQuote] = useState<Quote | null>(null);

  const quoteMutation = useMutation({
    mutationFn: () =>
      api.quote({
        vehicle_type: vehicleType as VehicleType,
        pickup_address: pickup.trim(),
        dropoff_address: dropoff.trim(),
      }),
    onSuccess: setQuote,
  });

  const createMutation = useMutation({
    mutationFn: () =>
      api.createJob({
        quote_id: (quote as Quote).quote_id,
        vehicle_type: vehicleType as VehicleType,
        pickup_address: pickup.trim(),
        dropoff_address: dropoff.trim(),
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
          <input
            value={pickup}
            onChange={(e) => {
              setPickup(e.target.value);
              setQuote(null);
            }}
            placeholder={strings.request.pickupPlaceholder}
            className={inputClass}
          />
        </label>
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
