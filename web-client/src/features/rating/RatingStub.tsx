import { useState } from 'react';
import { strings } from '../../i18n/strings';
import { Button, Card } from '../../ui';

/**
 * WEB-3 skeleton: local-only star rating shown when the job completes.
 * TODO(WEB-3): POST to the ratings endpoint once it exists in the spec.
 */
export function RatingStub() {
  const [stars, setStars] = useState(0);
  const [sent, setSent] = useState(false);

  if (sent) {
    return (
      <Card>
        <p className="text-center text-sm font-semibold text-emerald-300">
          {strings.rating.thanks}
        </p>
      </Card>
    );
  }

  return (
    <Card className="flex flex-col gap-3">
      <h2 className="text-sm font-semibold uppercase tracking-wide text-slate-400">
        {strings.rating.title}
      </h2>
      <div
        className="flex justify-center gap-2"
        role="radiogroup"
        aria-label={strings.rating.title}
      >
        {[1, 2, 3, 4, 5].map((n) => (
          <button
            key={n}
            type="button"
            role="radio"
            aria-checked={stars === n}
            aria-label={`${n}`}
            onClick={() => setStars(n)}
            className={`text-3xl transition-transform hover:scale-110 ${
              n <= stars ? 'text-amber-400' : 'text-slate-700'
            }`}
          >
            ★
          </button>
        ))}
      </div>
      <Button onClick={() => setSent(true)} disabled={stars === 0}>
        {strings.rating.submit}
      </Button>
    </Card>
  );
}
