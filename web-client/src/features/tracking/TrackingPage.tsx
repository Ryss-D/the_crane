import { useEffect, useState } from 'react';
import { useParams } from 'react-router-dom';
import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { api } from '../../api';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { useActiveJobStore } from '../../store/activeJob';
import { Button, Card } from '../../ui';
import { POLL_INTERVAL_MS, useJobSocket } from '../../ws/useJobSocket';
import { RatingStub } from '../rating/RatingStub';
import { DriverCard } from './DriverCard';
import { StatusTimeline } from './StatusTimeline';

export function TrackingPage() {
  const { id = '' } = useParams<'id'>();
  const updateStatus = useActiveJobStore((s) => s.updateStatus);
  const [copied, setCopied] = useState(false);
  const queryClient = useQueryClient();

  // TODO(WEB-3/TRK-1): live WS updates; polling below is the permanent fallback.
  useJobSocket(id);

  const jobQuery = useQuery({
    queryKey: ['job', id],
    queryFn: () => api.getJob(id),
    refetchInterval: POLL_INTERVAL_MS,
    enabled: id.length > 0,
  });

  const confirmMutation = useMutation({
    mutationFn: () => api.confirmDelivery(id),
    onSuccess: (updated) => queryClient.setQueryData(['job', id], updated),
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

      {/* TODO(FND-6): live map with driver marker. */}
      <div
        aria-hidden
        className="flex h-40 items-center justify-center rounded-2xl border border-dashed border-slate-700 bg-slate-900 text-sm text-slate-500"
      >
        {strings.request.mapPlaceholder} — TODO(FND-6)
      </div>

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
          <Button onClick={() => confirmMutation.mutate()} disabled={confirmMutation.isPending}>
            {confirmMutation.isPending ? strings.tracking.confirming : strings.tracking.confirmCash}
          </Button>
          {confirmMutation.isError && (
            <p role="alert" className="text-sm text-rose-400">
              {strings.tracking.confirmError}
            </p>
          )}
        </Card>
      )}

      {job.status === 'completed' && <RatingStub />}
    </div>
  );
}
