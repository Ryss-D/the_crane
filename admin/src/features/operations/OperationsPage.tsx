import { useQuery } from '@tanstack/react-query';
import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { api } from '../../api';
import type { JobStatus } from '../../api/types';
import { formatCOP, formatDateTime } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Badge, Table, TBody, Td, Th, THead, Tr } from '../../ui';
import { JOB_STATUSES } from '../../api/types';
import { jobStatusTone } from './jobStatusTone';

type StatusFilter = 'all' | JobStatus;

export function OperationsPage() {
  const navigate = useNavigate();
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');

  const filters = statusFilter === 'all' ? {} : { status: statusFilter };
  const { data: jobs, isLoading } = useQuery({
    queryKey: ['jobs', filters],
    queryFn: () => api.getJobs(filters),
  });

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-bold text-slate-100">{strings.operations.title}</h1>

      <label className="flex items-center gap-2 text-sm text-slate-300">
        {strings.operations.filterStatus}
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as StatusFilter)}
          className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
        >
          <option value="all">{strings.operations.all}</option>
          {JOB_STATUSES.map((s) => (
            <option key={s} value={s}>
              {strings.jobStatuses[s]}
            </option>
          ))}
        </select>
      </label>

      {isLoading || !jobs ? (
        <p className="text-sm text-slate-400">Cargando…</p>
      ) : jobs.length === 0 ? (
        <p className="text-sm text-slate-500">{strings.operations.noJobs}</p>
      ) : (
        <Table>
          <THead>
            <Tr>
              <Th>{strings.operations.columns.id}</Th>
              <Th>{strings.operations.columns.customer}</Th>
              <Th>{strings.operations.columns.driver}</Th>
              <Th>{strings.operations.columns.status}</Th>
              <Th>{strings.operations.columns.vehicleType}</Th>
              <Th>{strings.operations.columns.price}</Th>
              <Th>{strings.operations.columns.requestedAt}</Th>
            </Tr>
          </THead>
          <TBody>
            {jobs.map((job) => (
              <Tr key={job.id} onClick={() => navigate(`/operations/${job.id}`)}>
                <Td className="font-mono text-xs">{job.id}</Td>
                <Td>{job.customer_name}</Td>
                <Td>{job.driver_name ?? '—'}</Td>
                <Td>
                  <Badge tone={jobStatusTone[job.status]}>{strings.jobStatuses[job.status]}</Badge>
                </Td>
                <Td>{strings.vehicleTypes[job.vehicle_type]}</Td>
                <Td>{formatCOP(job.final_price ?? job.quoted_price)}</Td>
                <Td className="text-xs text-slate-400">{formatDateTime(job.requested_at)}</Td>
              </Tr>
            ))}
          </TBody>
        </Table>
      )}
    </div>
  );
}
