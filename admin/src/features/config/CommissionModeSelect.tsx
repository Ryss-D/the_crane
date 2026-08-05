import type { CommissionMode } from '../../api/types';
import { strings } from '../../i18n/strings';

export function CommissionModeSelect({
  mode,
  onChange,
}: {
  mode: CommissionMode;
  onChange: (mode: CommissionMode) => void;
}) {
  return (
    <label className="flex flex-col gap-1 text-xs text-slate-400">
      {strings.config.fields.mode}
      <select
        value={mode}
        onChange={(e) => onChange(e.target.value as CommissionMode)}
        className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
      >
        <option value="percent">{strings.config.commissionModes.percent}</option>
        <option value="flat">{strings.config.commissionModes.flat}</option>
      </select>
    </label>
  );
}
