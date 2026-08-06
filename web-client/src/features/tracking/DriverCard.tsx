import type { Driver } from '../../api/types';
import { strings } from '../../i18n/strings';
import { Card } from '../../ui';

export function DriverCard({ driver }: { driver: Driver }) {
  return (
    <Card className="flex items-center gap-3" data-testid="driver-card">
      <div
        aria-hidden
        className="flex h-12 w-12 shrink-0 items-center justify-center rounded-full bg-slate-700 text-xl"
      >
        🚛
      </div>
      <div className="min-w-0 flex-1">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-400">
          {strings.tracking.driverTitle}
        </h2>
        <p className="truncate font-bold text-slate-100">{driver.name ?? '—'}</p>
        <p className="truncate text-sm text-slate-400">{strings.truckTypes[driver.truck_type]}</p>
        <p className="text-sm text-slate-400">
          {strings.tracking.plateLabel}:{' '}
          <span className="font-mono">{driver.truck_plate}</span>
          {driver.rating_avg != null && <> · ★ {driver.rating_avg.toLocaleString('es-CO')}</>}
        </p>
      </div>
    </Card>
  );
}
