import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';
import { api } from '../../api';
import { TERMINAL_JOB_STATUSES } from '../../api/types';
import type { JobDetail } from '../../api/types';
import { formatCOP, formatDateTime } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Badge, Button, Card, Table, TBody, Td, Th, THead, Tr } from '../../ui';
import { jobStatusTone } from './jobStatusTone';
import { paymentStatusTone } from './paymentStatusTone';

const offerResponseTone = {
  pending: 'neutral',
  accepted: 'success',
  rejected: 'danger',
  timeout: 'warning',
} as const;

export function JobDetailPage() {
  const { id } = useParams<{ id: string }>();
  const navigate = useNavigate();
  const queryClient = useQueryClient();
  const [reason, setReason] = useState('');

  const { data: job, isLoading } = useQuery({
    queryKey: ['job', id],
    queryFn: () => api.getJob(id as string),
    enabled: Boolean(id),
  });

  const cancelMutation = useMutation({
    mutationFn: () => api.cancelJob(id as string, reason.trim() || undefined),
    onSuccess: (updated) => {
      // cancelJob's response is a plain Job — it has no `offers` field (only
      // getJob's JobDetail carries the trail). Merge onto the cached detail
      // instead of replacing it outright, or the offer trail below crashes.
      queryClient.setQueryData<JobDetail>(['job', id], (prev) =>
        prev ? { ...prev, ...updated } : prev,
      );
      void queryClient.invalidateQueries({ queryKey: ['jobs'] });
    },
  });

  if (isLoading || !job) {
    return <p className="text-sm text-slate-400">Cargando…</p>;
  }

  const isTerminal = TERMINAL_JOB_STATUSES.includes(job.status);

  return (
    <div className="flex flex-col gap-4">
      <div>
        <button
          type="button"
          onClick={() => navigate('/operations')}
          className="text-xs font-semibold text-amber-400 hover:text-amber-300"
        >
          ← {strings.operations.back}
        </button>
        <h1 className="mt-1 text-xl font-bold text-slate-100">
          {strings.operations.detailTitle} — <span className="font-mono text-base">{job.id}</span>
        </h1>
        <Badge tone={jobStatusTone[job.status]}>{strings.jobStatuses[job.status]}</Badge>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <dl className="grid grid-cols-2 gap-3 text-sm">
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.columns.customer}
              </dt>
              <dd className="text-slate-200">{job.customer_name}</dd>
              <dd className="text-xs text-slate-500">{job.customer_phone}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.columns.driver}
              </dt>
              <dd className="text-slate-200">{job.driver_name ?? '—'}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.pickup}
              </dt>
              <dd className="text-slate-200">{job.pickup_address}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.dropoff}
              </dt>
              <dd className="text-slate-200">{job.dropoff_address}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.distance}
              </dt>
              <dd className="text-slate-200">{job.distance_km.toLocaleString('es-CO')} km</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.columns.vehicleType}
              </dt>
              <dd className="text-slate-200">{strings.vehicleTypes[job.vehicle_type]}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.quotedPrice}
              </dt>
              <dd className="text-slate-200">{formatCOP(job.quoted_price)}</dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.finalPrice}
              </dt>
              <dd className="text-slate-200">
                {job.final_price !== null ? formatCOP(job.final_price) : '—'}
              </dd>
            </div>
            <div>
              <dt className="text-xs font-semibold uppercase text-slate-500">
                {strings.operations.paymentStatus}
              </dt>
              <dd>
                {job.payment_status !== null ? (
                  <Badge tone={paymentStatusTone[job.payment_status]}>
                    {strings.paymentStatuses[job.payment_status]}
                  </Badge>
                ) : (
                  <span className="text-slate-500">{strings.operations.noPayment}</span>
                )}
              </dd>
            </div>
          </dl>
          {job.cancel_reason && (
            <p className="mt-3 text-xs text-rose-400">Motivo de cancelación: {job.cancel_reason}</p>
          )}
        </Card>

        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-200">
            {strings.operations.offerTrail}
          </h2>
          {job.offers.length === 0 ? (
            <p className="text-sm text-slate-500">{strings.operations.noOffers}</p>
          ) : (
            <Table>
              <THead>
                <Tr>
                  <Th>{strings.operations.columns.driver}</Th>
                  <Th>Ofrecida</Th>
                  <Th>Respondida</Th>
                  <Th>Respuesta</Th>
                </Tr>
              </THead>
              <TBody>
                {job.offers.map((o) => (
                  <Tr key={o.id}>
                    <Td>{o.driver_name}</Td>
                    <Td className="text-xs text-slate-400">{formatDateTime(o.offered_at)}</Td>
                    <Td className="text-xs text-slate-400">
                      {o.responded_at ? formatDateTime(o.responded_at) : '—'}
                    </Td>
                    <Td>
                      <Badge tone={offerResponseTone[o.response]}>
                        {strings.offerResponses[o.response]}
                      </Badge>
                    </Td>
                  </Tr>
                ))}
              </TBody>
            </Table>
          )}
        </Card>
      </div>

      {!isTerminal && (
        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-200">{strings.operations.cancel}</h2>
          <div className="flex flex-col gap-3 sm:flex-row sm:items-end">
            <label className="flex flex-1 flex-col gap-1 text-xs text-slate-400">
              {strings.operations.cancelReasonLabel}
              <input
                type="text"
                value={reason}
                onChange={(e) => setReason(e.target.value)}
                className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
              />
            </label>
            <Button
              variant="danger"
              disabled={cancelMutation.isPending}
              onClick={() => cancelMutation.mutate()}
            >
              {strings.operations.cancelConfirm}
            </Button>
          </div>
          {cancelMutation.isError && (
            <p role="alert" className="mt-2 text-sm text-rose-400">
              {strings.operations.cancelError}
            </p>
          )}
        </Card>
      )}

      <Link to="/operations" className="text-xs font-semibold text-amber-400 hover:text-amber-300">
        ← {strings.operations.back}
      </Link>
    </div>
  );
}
