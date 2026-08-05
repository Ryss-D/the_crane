import type { HTMLAttributes } from 'react';

export function Card({ className = '', ...rest }: HTMLAttributes<HTMLDivElement>) {
  return (
    <div
      className={`rounded-lg border border-slate-800 bg-slate-900 p-4 shadow-lg shadow-black/20 ${className}`}
      {...rest}
    />
  );
}
