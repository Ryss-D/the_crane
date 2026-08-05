import { useState } from 'react';
import type { FormEvent } from 'react';
import { useAuth } from '../../auth';
import { strings } from '../../i18n/strings';
import { Button, Card } from '../../ui';

/**
 * Dev sign-in: any email/password logs you in as `role=admin` (FakeAuth).
 * TODO(FND-1): becomes the real Firebase email/password (or Google) sign-in,
 * with server-side role=admin enforcement on every /v1/admin/* request — the
 * client-side gate here is a UX convenience only (see src/auth/types.ts).
 */
export function LoginPage() {
  const { signInWithPassword } = useAuth();
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [busy, setBusy] = useState(false);

  async function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!email.trim() || !password) return;
    setBusy(true);
    try {
      await signInWithPassword(email.trim(), password);
    } finally {
      setBusy(false);
    }
  }

  return (
    <div className="flex min-h-dvh items-center justify-center bg-slate-950 px-4">
      <Card className="w-full max-w-sm">
        <form onSubmit={onSubmit} className="flex flex-col gap-3">
          <div>
            <h1 className="text-lg font-bold text-slate-100">{strings.appName}</h1>
            <p className="text-sm text-slate-400">{strings.panelName}</p>
          </div>
          <h2 className="text-base font-semibold text-slate-200">{strings.auth.title}</h2>
          <label className="flex flex-col gap-1 text-sm text-slate-300">
            {strings.auth.emailLabel}
            <input
              type="email"
              autoComplete="username"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder={strings.auth.emailPlaceholder}
              className="rounded-md border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-amber-500 focus:outline-none"
            />
          </label>
          <label className="flex flex-col gap-1 text-sm text-slate-300">
            {strings.auth.passwordLabel}
            <input
              type="password"
              autoComplete="current-password"
              value={password}
              onChange={(e) => setPassword(e.target.value)}
              placeholder={strings.auth.passwordPlaceholder}
              className="rounded-md border border-slate-700 bg-slate-800 px-3 py-2 text-sm text-slate-100 placeholder:text-slate-500 focus:border-amber-500 focus:outline-none"
            />
          </label>
          <Button type="submit" disabled={busy || !email.trim() || !password} className="w-full">
            {strings.auth.submit}
          </Button>
          <p className="text-xs text-slate-500">{strings.auth.devNote}</p>
        </form>
      </Card>
    </div>
  );
}
