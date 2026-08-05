import type { ButtonHTMLAttributes } from 'react';

type Variant = 'primary' | 'secondary' | 'ghost' | 'danger';

const base =
  'inline-flex items-center justify-center gap-1.5 rounded-md px-3 py-1.5 text-sm font-semibold transition-colors disabled:cursor-not-allowed disabled:opacity-50';

const variants: Record<Variant, string> = {
  primary: 'bg-amber-500 text-slate-950 hover:bg-amber-400 active:bg-amber-600',
  secondary: 'bg-slate-800 text-slate-100 hover:bg-slate-700 active:bg-slate-900',
  ghost: 'bg-transparent text-slate-300 hover:bg-slate-800',
  danger: 'bg-rose-900 text-rose-100 hover:bg-rose-800 active:bg-rose-950',
};

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: Variant;
}

/** Desktop-dense: compact padding, intrinsic width (unlike web-client's full-width mobile buttons). */
export function Button({ variant = 'primary', className = '', ...rest }: ButtonProps) {
  return <button className={`${base} ${variants[variant]} ${className}`} {...rest} />;
}
