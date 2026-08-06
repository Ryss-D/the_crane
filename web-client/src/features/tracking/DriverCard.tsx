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
      {/* Parity with the Flutter app's CUS-4 call-driver button
          (lib/features/customer/request/matching_screen.dart) — a plain
          `tel:` link needs no new dependency (that app uses url_launcher,
          this is the same scheme via native HTML). Hidden entirely when the
          backend hasn't given us a number (e.g. driver hasn't shared one). */}
      {driver.phone && (
        <a
          href={`tel:${driver.phone}`}
          aria-label={strings.tracking.callDriver}
          title={strings.tracking.callDriver}
          className="flex h-10 w-10 shrink-0 items-center justify-center rounded-full bg-amber-500 text-lg text-slate-950 transition-colors hover:bg-amber-400 active:bg-amber-600"
        >
          <span aria-hidden>📞</span>
        </a>
      )}
    </Card>
  );
}
