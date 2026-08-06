import { useState } from 'react';
import { useMutation } from '@tanstack/react-query';
import { api } from '../../api';
import { strings } from '../../i18n/strings';
import { Button, Card } from '../../ui';

/** Star rating shown when the job completes — posts to the real RAT-1
 * endpoint (POST /v1/jobs/{id}/rating). */
export function RatingStub({ jobId }: { jobId: string }) {
  const [stars, setStars] = useState(0);
  const mutation = useMutation({
    mutationFn: () => api.submitRating(jobId, stars),
  });

  if (mutation.isSuccess) {
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
      <Button onClick={() => mutation.mutate()} disabled={stars === 0 || mutation.isPending}>
        {mutation.isPending ? strings.rating.submitting : strings.rating.submit}
      </Button>
      {mutation.isError && (
        <p role="alert" className="text-sm text-rose-400">
          {strings.rating.error}
        </p>
      )}
    </Card>
  );
}
