import { useState } from 'react';
import type { FormEvent } from 'react';
import { useAuth } from '../../auth';
import { strings } from '../../i18n/strings';
import { Button, Card } from '../../ui';

/** Colombia default — the request flow (Places bias, currency) already
 * assumes es-CO, so a bare local number is treated as +57. Typing a leading
 * "+" opts out for anyone signing in from elsewhere. */
function toE164(input: string): string {
  const trimmed = input.trim();
  if (trimmed.startsWith('+')) return trimmed.replace(/[^\d+]/g, '');
  return `+57${trimmed.replace(/\D/g, '')}`;
}

/** Two-step phone sign-in: send OTP, then confirm it. Same Firebase
 * accounts as the mobile app (FakeAuth in dev: any phone + any code). */
export function PhoneSignIn() {
  const { sendCode, confirmCode } = useAuth();
  const [phone, setPhone] = useState('');
  const [code, setCode] = useState('');
  const [codeSent, setCodeSent] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState<string | null>(null);

  async function onSendCode(e: FormEvent) {
    e.preventDefault();
    if (!phone.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await sendCode(toE164(phone));
      setCodeSent(true);
    } catch {
      setError(strings.auth.sendError);
    } finally {
      setBusy(false);
    }
  }

  async function onConfirmCode(e: FormEvent) {
    e.preventDefault();
    if (!code.trim()) return;
    setBusy(true);
    setError(null);
    try {
      await confirmCode(code.trim());
    } catch {
      setError(strings.auth.confirmError);
    } finally {
      setBusy(false);
    }
  }

  function onChangeNumber() {
    setCodeSent(false);
    setCode('');
    setError(null);
  }

  if (codeSent) {
    return (
      <Card>
        <form onSubmit={onConfirmCode} className="flex flex-col gap-3">
          <h2 className="text-lg font-bold text-slate-100">{strings.auth.codeTitle}</h2>
          <p className="text-sm text-slate-400">{strings.auth.codeSentTo(toE164(phone))}</p>
          <label className="flex flex-col gap-1 text-sm text-slate-300">
            {strings.auth.codeLabel}
            <input
              type="text"
              inputMode="numeric"
              autoComplete="one-time-code"
              value={code}
              onChange={(e) => setCode(e.target.value)}
              placeholder={strings.auth.codePlaceholder}
              className="rounded-xl border border-slate-700 bg-slate-800 px-3 py-3 text-base text-slate-100 placeholder:text-slate-500 focus:border-amber-500 focus:outline-none"
            />
          </label>
          {error && (
            <p role="alert" className="text-sm text-rose-400">
              {error}
            </p>
          )}
          <Button type="submit" disabled={busy || !code.trim()}>
            {strings.auth.confirm}
          </Button>
          <button
            type="button"
            onClick={onChangeNumber}
            className="text-sm text-slate-400 hover:text-slate-200"
          >
            {strings.auth.changeNumber}
          </button>
        </form>
      </Card>
    );
  }

  return (
    <Card>
      <form onSubmit={onSendCode} className="flex flex-col gap-3">
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
        {error && (
          <p role="alert" className="text-sm text-rose-400">
            {error}
          </p>
        )}
        <Button type="submit" disabled={busy || !phone.trim()}>
          {strings.auth.submit}
        </Button>
        <p className="text-xs text-slate-500">{strings.auth.devNote}</p>
      </form>
    </Card>
  );
}
