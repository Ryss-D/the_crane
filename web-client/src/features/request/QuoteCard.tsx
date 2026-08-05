import type { Quote } from '../../api/types';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Button, Card } from '../../ui';

export function QuoteCard({
  quote,
  onConfirm,
  confirming,
}: {
  quote: Quote;
  onConfirm: () => void;
  confirming: boolean;
}) {
  return (
    <Card className="flex flex-col gap-3">
      <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-400">
        {strings.request.quoteTitle}
      </h2>
      <p className="text-3xl font-bold text-amber-400" data-testid="quote-price">
        {formatCOP(quote.price)}
      </p>
      <dl className="flex gap-6 text-sm text-slate-300">
        <div>
          <dt className="text-slate-500">{strings.request.etaLabel}</dt>
          <dd className="font-semibold">{strings.request.etaValue(quote.eta_minutes)}</dd>
        </div>
        <div>
          <dt className="text-slate-500">{strings.request.distanceLabel}</dt>
          <dd className="font-semibold">{strings.request.distanceValue(quote.distance_km)}</dd>
        </div>
      </dl>
      <Button onClick={onConfirm} disabled={confirming}>
        {confirming ? strings.request.confirming : strings.request.confirm}
      </Button>
    </Card>
  );
}
