import type { JobStatus } from '../api/types';
import { strings } from '../i18n/strings';

const tones: Record<JobStatus, string> = {
  requested: 'bg-slate-700 text-slate-100',
  matching: 'bg-sky-900 text-sky-200',
  assigned: 'bg-indigo-900 text-indigo-200',
  en_route_pickup: 'bg-amber-900 text-amber-200',
  arrived_pickup: 'bg-amber-800 text-amber-100',
  loading: 'bg-orange-900 text-orange-200',
  in_transit: 'bg-blue-900 text-blue-200',
  delivered: 'bg-emerald-900 text-emerald-200',
  completed: 'bg-emerald-800 text-emerald-100',
  cancelled: 'bg-rose-900 text-rose-200',
  no_drivers: 'bg-rose-950 text-rose-300',
};

export function StatusPill({ status }: { status: JobStatus }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-3 py-1 text-xs font-semibold ${tones[status]}`}
    >
      {strings.statuses[status]}
    </span>
  );
}
