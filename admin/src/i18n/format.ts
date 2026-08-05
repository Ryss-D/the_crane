/** COP has no cents in practice — always whole pesos. Mirrors web-client's utility (not imported cross-package). */
const copFormatter = new Intl.NumberFormat('es-CO', {
  style: 'currency',
  currency: 'COP',
  maximumFractionDigits: 0,
});

export function formatCOP(amount: number): string {
  return copFormatter.format(amount);
}

const dateTimeFormatter = new Intl.DateTimeFormat('es-CO', {
  dateStyle: 'medium',
  timeStyle: 'short',
});

export function formatDateTime(iso: string): string {
  return dateTimeFormatter.format(new Date(iso));
}

const percentFormatter = new Intl.NumberFormat('es-CO', {
  style: 'percent',
  maximumFractionDigits: 1,
});

export function formatPercent(fraction: number): string {
  return percentFormatter.format(fraction);
}
