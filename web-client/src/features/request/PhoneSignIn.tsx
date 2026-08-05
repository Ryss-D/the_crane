import { useState } from 'react';
import type { FormEvent } from 'react';
import { useAuth } from '../../auth';
import { strings } from '../../i18n/strings';
import { Button, Card } from '../../ui';

/**
 * Dev sign-in: any phone number logs you in (FakeAuth).
 * TODO(FND-1): becomes the real phone-OTP flow (send code → confirm) with the
 * Firebase web SDK, same accounts as the mobile app.
 */
export function PhoneSignIn() {
  const { signInWithPhone } = useAuth();
  const [phone, setPhone] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!phone.trim()) return;
    setBusy(true);
    try {
      await signInWithPhone(phone.trim());
    } finally {
      setBusy(false);
    }
  }

  return (
    <Card>
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
        <h2 className="text-lg font-bold text-slate-100">{strings.auth.title}</h2>
        <label className="flex flex-col gap-1 text-sm text-slate-300">
          {strings.auth.phoneLabel}
          <input
            type="tel"
            inputMode="tel"
            autoComplete="tel"
            value={phone}
            onChange={(e) => setPhone(e.target.value)}
            placeholder={strings.auth.phonePlaceholder}
            className="rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-base text-slate-100 placeholder:text-slate-500 focus:border-amber-500 focus:outline-none"
          />
        </label>
        <Button type="submit" disabled={busy || !phone.trim()}>
          {strings.auth.submit}
        </Button>
        <p className="text-xs text-slate-500">{strings.auth.devNote}</p>
      </form>
    </Card>
  );
}
