import { useState } from 'react';
import type { FormEvent } from 'react';
import { useAuth } from '../../auth';
import { strings } from '../../i18n/strings';
import { Button, Card } from '../../ui';

/**
 * WEB-1 profile-completion gate: shown by RequestPage whenever the synced
 * backend profile has no `name` yet (Firebase phone-OTP alone gives the
 * backend nothing to go on). Mirrors the Flutter app's AUTH-3
 * `CompleteProfileScreen`/`AuthCubit.completeProfile` — same one-field,
 * one-button shape, not the same pixels (this is a mobile-first Tailwind
 * page, not a Material screen).
 */
export function CompleteProfileForm() {
  const { completeProfile } = useAuth();
  const [name, setName] = useState('');
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    const trimmed = name.trim();
    if (!trimmed) return;
    setBusy(true);
    setError(null);
    try {
      await completeProfile(trimmed);
      // No further action needed on success: AuthProvider's `profile` flips
      // to non-null `name`, RequestPage stops rendering this form on its
      // next render, same "state change unmounts this" pattern as the
      // Flutter screen's router redirect.
    } catch {
      setError(strings.completeProfile.saveError);
      setBusy(false);
    }
  }

  return (
    <Card>
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
        <h2 className="text-lg font-bold text-slate-100">{strings.completeProfile.title}</h2>
        <p className="text-sm text-slate-400">{strings.completeProfile.subtitle}</p>
        <label className="flex flex-col gap-1 text-sm text-slate-300">
          {strings.completeProfile.nameLabel}
          <input
            type="text"
            autoComplete="name"
            value={name}
            onChange={(e) => setName(e.target.value)}
            className="rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-base text-slate-100 placeholder:text-slate-500 focus:border-amber-500 focus:outline-none"
          />
        </label>
        {error && (
          <p role="alert" className="text-sm text-rose-400">
            {error}
          </p>
        )}
        <Button type="submit" disabled={busy || !name.trim()}>
          {strings.completeProfile.saveButton}
        </Button>
      </form>
    </Card>
  );
}
