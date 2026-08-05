/** COP has no cents in practice — always whole pesos. */
const copFormatter = new Intl.NumberFormat('es-CO', {
  style: 'currency',
  currency: 'COP',
  maximumFractionDigits: 0,
});

export function formatCOP(amount: number): string {
  return copFormatter.format(amount);
}
