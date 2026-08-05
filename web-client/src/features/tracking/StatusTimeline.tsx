import type { JobStatus } from '../../api/types';
import { TIMELINE_STATUSES } from '../../api/types';
import { strings } from '../../i18n/strings';
import { StatusPill } from '../../ui';

/**
 * Vertical timeline of the happy-path statuses; terminal failures
 * (cancelled / no_drivers) render as a banner instead of a step.
 */
export function StatusTimeline({ status }: { status: JobStatus }) {
  const failed = status === 'cancelled' || status === 'no_drivers';
  const currentIdx = TIMELINE_STATUSES.indexOf(status);

  return (
    <div className="flex flex-col gap-2">
      <div className="flex items-center justify-between">
        <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-400">
          {strings.tracking.timelineTitle}
        </h2>
        <StatusPill status={status} />
      </div>

      {failed && (
        <p
          role="alert"
          className="rounded-xl border border-rose-900 bg-rose-950/50 px-3 py-2 text-sm text-rose-300"
        >
          {strings.statuses[status]}
        </p>
      )}

      <ol className="flex flex-col">
        {TIMELINE_STATUSES.map((s, i) => {
          const done = !failed && currentIdx >= 0 && i < currentIdx;
          const current = !failed && i === currentIdx;
          const last = i === TIMELINE_STATUSES.length - 1;
          return (
            <li key={s} className="flex gap-3" aria-current={current ? 'step' : undefined}>
              <div className="flex flex-col items-center">
                <span
                  className={`mt-1 h-3 w-3 shrink-0 rounded-full border-2 ${
                    current
                      ? 'border-amber-400 bg-amber-400'
                      : done
                        ? 'border-emerald-500 bg-emerald-500'
                        : 'border-slate-600 bg-slate-900'
                  }`}
                />
                {!last && (
                  <span className={`w-0.5 flex-1 ${done ? 'bg-emerald-700' : 'bg-slate-800'}`} />
                )}
              </div>
              <span
                className={`pb-4 text-sm ${
                  current ? 'font-bold text-amber-300' : done ? 'text-slate-300' : 'text-slate-500'
                }`}
              >
                {strings.statuses[s]}
              </span>
            </li>
          );
        })}
      </ol>
    </div>
  );
}
