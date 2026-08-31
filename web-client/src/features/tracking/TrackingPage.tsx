import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../../api';
import { ApiError } from '../../api/client';
import type { Job, PaymentMethod } from '../../api/types';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { useActiveJobStore } from '../../store/activeJob';
import { Button, Card } from '../../ui';
import { POLL_INTERVAL_MS, useJobSocket } from '../../ws/useJobSocket';
import { TrackingMap } from '../map/TrackingMap';
import { RatingStub } from '../rating/RatingStub';
import { DriverCard } from './DriverCard';
import { StatusTimeline } from './StatusTimeline';

/** PAY-4: digital methods offered next to the pre-existing cash button —
 * `cash` keeps its own dedicated button, unchanged. */
const DIGITAL_PAYMENT_METHODS: readonly PaymentMethod[] = ['card', 'pse', 'nequi'];

export function TrackingPage() {
  const { id = '' } = useParams<'id'>();
  const updateStatus = useActiveJobStore((s) => s.updateStatus);
  const [copied, setCopied] = useState(false);
  const queryClient = useQueryClient();
  // PAY-4: the digital-payment picker is closed by default — cash stays the
  // one-click default path, the picker is an explicit opt-in next to it.
  const [showPaymentPicker, setShowPaymentPicker] = useState(false);
  const [selectedMethod, setSelectedMethod] = useState<PaymentMethod>('card');
  // Nequi has no redirect step — this is the only way the customer learns
  // to go check their Nequi app, so it has to survive the job leaving
  // `delivered` (the backend completes the job immediately either way).
  const [nequiPending, setNequiPending] = useState(false);

  // Live WS updates (job_event -> refetch, driver_location -> the map
  // marker below); polling stays the permanent fallback either way.
  const { driverLocation } = useJobSocket(id);

  const jobQuery = useQuery({
    queryKey: ['job', id],
    queryFn: () => api.getJob(id),
    refetchInterval: POLL_INTERVAL_MS,
    enabled: id.length > 0,
  });

  const confirmMutation = useMutation<Job, ApiError, PaymentMethod | undefined>({
    mutationFn: (paymentMethod) => api.confirmDelivery(id, paymentMethod),
    onSuccess: (updated, paymentMethod) => {
      queryClient.setQueryData(['job', id], updated);
      if (updated.async_payment_url) {
        // PSE/card: a real Wompi checkout was just started — send the
        // browser there. No SPA route to come back to here (mirrors the
        // Flutter app's plain redirect launch, just without url_launcher).
        window.location.href = updated.async_payment_url;
      } else if (paymentMethod === 'nequi') {
        setNequiPending(true);
      }
    },
  });

  const job = jobQuery.data;

  useEffect(() => {
    if (job) updateStatus(job.status);
  }, [job, updateStatus]);

  if (jobQuery.isPending) {
    return <p className="text-center text-sm text-slate-400">{strings.tracking.loading}</p>;
  }
  if (jobQuery.isError || !job) {
    return (
      <p role="alert" className="text-center text-sm text-rose-400">
        {strings.tracking.notFound}
      </p>
    );
  }

  async function share() {
    if (!job) return;
    const url = `${window.location.origin}/t/${job.share_token}`;
    try {
      await navigator.clipboard.writeText(url);
      setCopied(true);
      setTimeout(() => setCopied(false), 2000);
    } catch {
      // Clipboard unavailable — surface the URL instead.
      window.prompt(strings.tracking.shareLabel, url);
    }
  }

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-lg font-bold text-slate-100">{strings.tracking.title}</h1>

      {import.meta.env.VITE_GOOGLE_MAPS_API_KEY ? (
        <TrackingMap
          pickup={{ lat: job.pickup_lat, lng: job.pickup_lng }}
          dropoff={{ lat: job.dropoff_lat, lng: job.dropoff_lng }}
          driverLocation={driverLocation}
        />
      ) : (
        <div
          aria-hidden
          className="flex h-40 items-center justify-center rounded-2xl border border-dashed border-slate-700 bg-slate-900 text-sm text-slate-500"
        >
          {strings.request.mapPlaceholder} — TODO(FND-6)
        </div>
      )}

      <Card className="flex flex-col gap-2 text-sm text-slate-300">
        <p className="truncate">
          <span className="text-slate-500">A: </span>
          {job.pickup_address}
        </p>
        <p className="truncate">
          <span className="text-slate-500">B: </span>
          {job.dropoff_address}
        </p>
        <p>
          {strings.tracking.priceLabel}:{' '}
          <span className="font-bold text-amber-400">
            {formatCOP(job.final_price ?? job.quoted_price)}
          </span>
        </p>
        <button
          type="button"
          onClick={share}
          className="self-start text-sm font-semibold text-amber-400 hover:text-amber-300"
        >
          {copied ? strings.tracking.shareCopied : `${strings.tracking.shareLabel} →`}
        </button>
      </Card>

      {job.driver && <DriverCard driver={job.driver} />}

      <Card>
        <StatusTimeline status={job.status} />
        <p className="text-xs text-slate-600">{strings.tracking.pollNote}</p>
      </Card>

      {job.status === 'delivered' && (
        <Card className="flex flex-col gap-3 text-center">
          <h2 className="text-base font-bold text-slate-100">{strings.tracking.deliveredTitle}</h2>
          <p className="text-sm text-slate-300">
            {strings.tracking.priceLabel}:{' '}
            <span className="font-bold text-amber-400">
              {formatCOP(job.final_price ?? job.quoted_price)}
            </span>
          </p>
          <Button
            onClick={() => confirmMutation.mutate(undefined)}
            disabled={confirmMutation.isPending}
          >
            {confirmMutation.isPending ? strings.tracking.confirming : strings.tracking.confirmCash}
          </Button>

          {!showPaymentPicker && (
            <button
              type="button"
              onClick={() => setShowPaymentPicker(true)}
              className="text-sm font-semibold text-amber-400 hover:text-amber-300"
            >
              {strings.tracking.payDigitalToggle}
            </button>
          )}

          {showPaymentPicker && (
            <div className="flex flex-col gap-3 text-left">
              <div
                role="radiogroup"
                aria-label={strings.tracking.paymentMethodLabel}
                className="grid grid-cols-3 gap-2"
              >
                {DIGITAL_PAYMENT_METHODS.map((method) => {
                  const selected = selectedMethod === method;
                  return (
                    <button
                      key={method}
                      type="button"
                      role="radio"
                      aria-checked={selected}
                      onClick={() => setSelectedMethod(method)}
                      className={`rounded-xl border px-2 py-3 text-sm font-semibold transition-colors ${
                        selected
                          ? 'border-amber-500 bg-amber-500/10 text-amber-300'
                          : 'border-slate-700 bg-slate-800 text-slate-300 hover:border-slate-500'
                      }`}
                    >
                      {strings.paymentMethods[method]}
                    </button>
                  );
                })}
              </div>
              <Button
                variant="secondary"
                onClick={() => confirmMutation.mutate(selectedMethod)}
                disabled={confirmMutation.isPending}
              >
                {confirmMutation.isPending
                  ? strings.tracking.confirming
                  : strings.tracking.payDigitalSubmit}
              </Button>
            </div>
          )}

          {confirmMutation.isError && (
            <p role="alert" className="text-sm text-rose-400">
              {confirmMutation.error instanceof ApiError && confirmMutation.error.status === 422
                ? strings.tracking.digitalFaresUnavailable
                : strings.tracking.confirmError}
            </p>
          )}
        </Card>
      )}

      {nequiPending && (
        <Card className="text-center text-sm text-amber-200">{strings.tracking.nequiPending}</Card>
      )}

      {job.status === 'completed' && <RatingStub jobId={job.id} />}
    </div>
  );
}
