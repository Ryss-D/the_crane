import { useQuery } from '@tanstack/react-query';
import { api } from '../../api';
import type { Job } from '../../api/types';
import { formatCOP, formatDateTime } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Card } from '../../ui';

const DAY_MS = 24 * 60 * 60 * 1000;

function isWithinLastDay(iso: string): boolean {
  return Date.now() - new Date(iso).getTime() < DAY_MS;
}

interface ActivityEvent {
  id: string;
  at: string;
  text: string;
}

function buildActivityFeed(jobs: Job[]): ActivityEvent[] {
  const events: ActivityEvent[] = [];
  for (const job of jobs) {
    events.push({
      id: `${job.id}-requested`,
      at: job.requested_at,
      text: `${job.customer_name} solicitó una grúa (${strings.vehicleTypes[job.vehicle_type]})`,
    });
    if (job.assigned_at) {
      events.push({
        id: `${job.id}-assigned`,
        at: job.assigned_at,
        text: `${job.driver_name ?? 'Conductor'} asignado al servicio ${job.id}`,
      });
    }
    if (job.completed_at) {
      events.push({
        id: `${job.id}-completed`,
        at: job.completed_at,
        text: `Servicio ${job.id} completado (${formatCOP(job.final_price ?? job.quoted_price)})`,
      });
    }
    if (job.cancelled_at) {
      events.push({
        id: `${job.id}-cancelled`,
        at: job.cancelled_at,
        text: `Servicio ${job.id} cancelado${job.cancel_reason ? ` — ${job.cancel_reason}` : ''}`,
      });
    }
  }
  return events.sort((a, b) => new Date(b.at).getTime() - new Date(a.at).getTime()).slice(0, 10);
}

function KpiCard({ label, value }: { label: string; value: string }) {
  return (
    <Card>
      <p className="text-xs font-medium uppercase tracking-wide text-slate-400">{label}</p>
      <p className="mt-2 text-2xl font-bold text-slate-100">{value}</p>
    </Card>
  );
}

export function DashboardPage() {
  const { data, isLoading } = useQuery({
    queryKey: ['dashboard'],
    queryFn: async () => {
      const [jobs, drivers, { config }] = await Promise.all([
        api.getJobs(),
        api.getDrivers(),
        api.getConfig(),
      ]);
      return { jobs, drivers, config };
    },
  });

  if (isLoading || !data) {
    return <p className="text-sm text-slate-400">Cargando…</p>;
  }

  const { jobs, drivers, config } = data;

  const tripsToday = jobs.filter((j) => isWithinLastDay(j.requested_at)).length;
  const activeTrucks = drivers.filter(
    (d) => d.status === 'available' || d.status === 'on_job',
  ).length;

  const assignmentDurationsMin = jobs
    .filter((j): j is typeof j & { assigned_at: string } => j.assigned_at !== null)
    .map((j) => (new Date(j.assigned_at).getTime() - new Date(j.requested_at).getTime()) / 60000);
  const avgAssignmentMin =
    assignmentDurationsMin.length > 0
      ? assignmentDurationsMin.reduce((a, b) => a + b, 0) / assignmentDurationsMin.length
      : 0;

  function commissionFor(job: Job): number {
    const price = job.final_price ?? job.quoted_price;
    return config.commission.mode === 'percent'
      ? Math.round(price * config.commission.rate[job.vehicle_type])
      : config.commission.rate[job.vehicle_type];
  }

  const dayCommission = jobs
    .filter((j) => j.status === 'completed' && j.completed_at && isWithinLastDay(j.completed_at))
    .reduce((sum, j) => sum + commissionFor(j), 0);

  const feed = buildActivityFeed(jobs);

  return (
    <div className="flex flex-col gap-6">
      <h1 className="text-xl font-bold text-slate-100">{strings.dashboard.title}</h1>

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-4">
        <KpiCard label={strings.dashboard.tripsToday} value={String(tripsToday)} />
        <KpiCard label={strings.dashboard.activeTrucks} value={String(activeTrucks)} />
        <KpiCard
          label={strings.dashboard.avgAssignmentTime}
          value={`${avgAssignmentMin.toFixed(1)} min`}
        />
        <KpiCard label={strings.dashboard.dayCommission} value={formatCOP(dayCommission)} />
      </div>

      <Card>
        <h2 className="mb-3 text-sm font-semibold text-slate-200">
          {strings.dashboard.recentActivity}
        </h2>
        {feed.length === 0 ? (
          <p className="text-sm text-slate-500">{strings.dashboard.noActivity}</p>
        ) : (
          <ul className="flex flex-col gap-2">
            {feed.map((event) => (
              <li key={event.id} className="flex items-baseline justify-between gap-4 text-sm">
                <span className="text-slate-200">{event.text}</span>
                <span className="shrink-0 text-xs text-slate-500">{formatDateTime(event.at)}</span>
              </li>
            ))}
          </ul>
        )}
      </Card>
    </div>
  );
}
