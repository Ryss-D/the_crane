import type { ReactNode, TdHTMLAttributes, ThHTMLAttributes } from 'react';

/** Desktop-dense table primitives — compact rows, sticky-ish header tone. */
export function Table({ children }: { children: ReactNode }) {
  return (
    <div className="overflow-x-auto rounded-lg border border-slate-800">
      <table className="w-full border-collapse text-left text-sm">{children}</table>
    </div>
  );
}

export function THead({ children }: { children: ReactNode }) {
  return (
    <thead className="bg-slate-900 text-xs uppercase tracking-wide text-slate-400">
      {children}
    </thead>
  );
}

export function TBody({ children }: { children: ReactNode }) {
  return <tbody className="divide-y divide-slate-800">{children}</tbody>;
}

export function Tr({
  children,
  onClick,
  className = '',
}: {
  children: ReactNode;
  onClick?: () => void;
  className?: string;
}) {
  return (
    <tr
      onClick={onClick}
      className={`${onClick ? 'cursor-pointer hover:bg-slate-900/60' : ''} ${className}`}
    >
      {children}
    </tr>
  );
}

export function Th({ children, className = '', ...rest }: ThHTMLAttributes<HTMLTableCellElement>) {
  return (
    <th className={`px-3 py-2 font-medium ${className}`} {...rest}>
      {children}
    </th>
  );
}

export function Td({ children, className = '', ...rest }: TdHTMLAttributes<HTMLTableCellElement>) {
  return (
    <td className={`px-3 py-2 text-slate-200 ${className}`} {...rest}>
      {children}
    </td>
  );
}
