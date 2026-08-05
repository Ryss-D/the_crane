import type { ReactNode } from 'react';

export type BadgeTone = 'neutral' | 'success' | 'warning' | 'danger' | 'info';

const tones: Record<BadgeTone, string> = {
  neutral: 'bg-slate-800 text-slate-200',
  success: 'bg-emerald-900 text-emerald-200',
  warning: 'bg-amber-900 text-amber-200',
  danger: 'bg-rose-900 text-rose-200',
  info: 'bg-sky-900 text-sky-200',
};

export function Badge({ tone = 'neutral', children }: { tone?: BadgeTone; children: ReactNode }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-semibold ${tones[tone]}`}
    >
      {children}
    </span>
  );
}
