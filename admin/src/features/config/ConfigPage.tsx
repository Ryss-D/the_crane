import { useQuery, useMutation, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '../../api';
import type {
  CommissionConfig,
  ConfigAuditEntry,
  ConfigKey,
  ConfigResponse,
  DispatchConfig,
  PricingConfig,
  SettlementConfig,
  VehicleType,
} from '../../api/types';
import { CommissionModeSelect } from './CommissionModeSelect';
import { formatCOP, formatDateTime, formatPercent } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Badge, Button, Card, Modal } from '../../ui';

const VEHICLE_TYPES: VehicleType[] = ['moto', 'car', 'suv'];

function summarizeValue(value: unknown): string {
  if (value == null || typeof value !== 'object') return String(value);
  return JSON.stringify(value);
}

function HistoryList({
  history,
  configKey,
}: {
  history: ConfigAuditEntry[];
  configKey: ConfigKey;
}) {
  const entries = history.filter((h) => h.key === configKey).slice(0, 4);
  if (entries.length === 0) {
    return <p className="text-xs text-slate-500">{strings.config.noHistory}</p>;
  }
  return (
    <ul className="flex flex-col gap-1.5">
      {entries.map((entry) => (
        <li key={entry.id} className="text-xs text-slate-500">
          <span className="text-slate-400">{formatDateTime(entry.changed_at)}</span>{' '}
          {strings.config.changedBy} <span className="text-slate-300">{entry.changed_by}</span>
          <div className="truncate text-slate-600">
            {summarizeValue(entry.previous_value)} → {summarizeValue(entry.new_value)}
          </div>
        </li>
      ))}
    </ul>
  );
}

function PricingForm({
  initial,
  onSave,
  saving,
}: {
  initial: PricingConfig;
  onSave: (value: PricingConfig) => void;
  saving: boolean;
}) {
  const [value, setValue] = useState<PricingConfig>(initial);
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={(e) => {
        e.preventDefault();
        onSave(value);
      }}
    >
      {VEHICLE_TYPES.map((vt) => (
        <fieldset key={vt} className="rounded-md border border-slate-800 p-3">
          <legend className="px-1 text-xs font-semibold uppercase text-slate-400">
            {strings.vehicleTypes[vt]}
          </legend>
          <div className="grid grid-cols-3 gap-2">
            {(['base_fare', 'per_km', 'min_fare'] as const).map((field) => (
              <label key={field} className="flex flex-col gap-1 text-xs text-slate-400">
                {strings.config.fields[field]}
                <input
                  type="number"
                  min={0}
                  value={value[vt][field]}
                  onChange={(e) =>
                    setValue((v) => ({
                      ...v,
                      [vt]: { ...v[vt], [field]: Number(e.target.value) },
                    }))
                  }
                  className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
                />
              </label>
            ))}
          </div>
        </fieldset>
      ))}
      <Button type="submit" disabled={saving}>
        {strings.config.save}
      </Button>
    </form>
  );
}

function CommissionForm({
  initial,
  onSave,
  saving,
}: {
  initial: CommissionConfig;
  onSave: (value: CommissionConfig) => void;
  saving: boolean;
}) {
  const [value, setValue] = useState<CommissionConfig>(initial);
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={(e) => {
        e.preventDefault();
        onSave(value);
      }}
    >
      <CommissionModeSelect
        mode={value.mode}
        onChange={(mode) => setValue((v) => ({ ...v, mode }))}
      />
      <div className="grid grid-cols-3 gap-2">
        {VEHICLE_TYPES.map((vt) => (
          <label key={vt} className="flex flex-col gap-1 text-xs text-slate-400">
            {strings.vehicleTypes[vt]} — {strings.config.fields.rate}
            {value.mode === 'percent' ? (
              <input
                type="number"
                min={0}
                max={100}
                step={0.5}
                value={Math.round(value.rate[vt] * 1000) / 10}
                onChange={(e) =>
                  setValue((v) => ({
                    ...v,
                    rate: { ...v.rate, [vt]: Number(e.target.value) / 100 },
                  }))
                }
                className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
              />
            ) : (
              <input
                type="number"
                min={0}
                value={value.rate[vt]}
                onChange={(e) =>
                  setValue((v) => ({
                    ...v,
                    rate: { ...v.rate, [vt]: Number(e.target.value) },
                  }))
                }
                className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
              />
            )}
          </label>
        ))}
      </div>
      <Button type="submit" disabled={saving}>
        {strings.config.save}
      </Button>
    </form>
  );
}

function SettlementForm({
  initial,
  onSave,
  saving,
}: {
  initial: SettlementConfig;
  onSave: (value: SettlementConfig) => void;
  saving: boolean;
}) {
  const [value, setValue] = useState<SettlementConfig>(initial);
  const noCap = value.balance_cap === null;
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={(e) => {
        e.preventDefault();
        onSave(value);
      }}
    >
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        {strings.config.fields.balance_cap}
        <div className="flex items-center gap-2">
          <input
            type="number"
            min={0}
            disabled={noCap}
            value={value.balance_cap ?? ''}
            onChange={(e) => setValue((v) => ({ ...v, balance_cap: Number(e.target.value) }))}
            className="w-full rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 disabled:opacity-40 focus:border-amber-500 focus:outline-none"
          />
          <label className="flex shrink-0 items-center gap-1.5 text-xs text-slate-400">
            <input
              type="checkbox"
              checked={noCap}
              onChange={(e) =>
                setValue((v) => ({ ...v, balance_cap: e.target.checked ? null : 100000 }))
              }
            />
            {strings.config.noCap}
          </label>
        </div>
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        {strings.config.fields.settlement_period}
        <select
          value={value.settlement_period}
          onChange={(e) =>
            setValue((v) => ({
              ...v,
              settlement_period: e.target.value as SettlementConfig['settlement_period'],
            }))
          }
          className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
        >
          {(['weekly', 'biweekly', 'monthly'] as const).map((p) => (
            <option key={p} value={p}>
              {strings.config.settlementPeriods[p]}
            </option>
          ))}
        </select>
      </label>
      <Button type="submit" disabled={saving}>
        {strings.config.save}
      </Button>
    </form>
  );
}

function DispatchForm({
  initial,
  onSave,
  saving,
}: {
  initial: DispatchConfig;
  onSave: (value: DispatchConfig) => void;
  saving: boolean;
}) {
  const [value, setValue] = useState<DispatchConfig>(initial);
  const [stepsText, setStepsText] = useState(initial.radius_widening_steps_km.join(', '));
  return (
    <form
      className="flex flex-col gap-4"
      onSubmit={(e) => {
        e.preventDefault();
        const steps = stepsText
          .split(',')
          .map((s) => Number(s.trim()))
          .filter((n) => !Number.isNaN(n));
        onSave({ ...value, radius_widening_steps_km: steps });
      }}
    >
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        {strings.config.fields.offer_ttl_seconds}
        <input
          type="number"
          min={1}
          value={value.offer_ttl_seconds}
          onChange={(e) => setValue((v) => ({ ...v, offer_ttl_seconds: Number(e.target.value) }))}
          className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        {strings.config.fields.search_radius_km}
        <input
          type="number"
          min={1}
          value={value.search_radius_km}
          onChange={(e) => setValue((v) => ({ ...v, search_radius_km: Number(e.target.value) }))}
          className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
        />
      </label>
      <label className="flex flex-col gap-1 text-xs text-slate-400">
        {strings.config.fields.radius_widening_steps_km}
        <input
          type="text"
          value={stepsText}
          onChange={(e) => setStepsText(e.target.value)}
          placeholder="15, 25"
          className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
        />
      </label>
      <Button type="submit" disabled={saving}>
        {strings.config.save}
      </Button>
    </form>
  );
}

function PricingSummary({ pricing }: { pricing: PricingConfig }) {
  return (
    <dl className="grid grid-cols-3 gap-3 text-sm">
      {VEHICLE_TYPES.map((vt) => (
        <div key={vt}>
          <dt className="text-xs font-semibold uppercase text-slate-500">
            {strings.vehicleTypes[vt]}
          </dt>
          <dd className="text-slate-200">
            {formatCOP(pricing[vt].base_fare)} + {formatCOP(pricing[vt].per_km)}/km
          </dd>
          <dd className="text-xs text-slate-500">mín. {formatCOP(pricing[vt].min_fare)}</dd>
        </div>
      ))}
    </dl>
  );
}

function CommissionSummary({ commission }: { commission: CommissionConfig }) {
  return (
    <dl className="grid grid-cols-3 gap-3 text-sm">
      <div className="col-span-3 text-xs text-slate-500">
        {strings.config.commissionModes[commission.mode]}
      </div>
      {VEHICLE_TYPES.map((vt) => (
        <div key={vt}>
          <dt className="text-xs font-semibold uppercase text-slate-500">
            {strings.vehicleTypes[vt]}
          </dt>
          <dd className="text-slate-200">
            {commission.mode === 'percent'
              ? formatPercent(commission.rate[vt])
              : formatCOP(commission.rate[vt])}
          </dd>
        </div>
      ))}
    </dl>
  );
}

function SettlementSummary({ settlement }: { settlement: SettlementConfig }) {
  return (
    <dl className="text-sm">
      <div>
        <dt className="text-xs font-semibold uppercase text-slate-500">
          {strings.config.fields.balance_cap}
        </dt>
        <dd className="text-slate-200">
          {settlement.balance_cap === null
            ? strings.config.noCap
            : formatCOP(settlement.balance_cap)}
        </dd>
      </div>
      <div className="mt-2">
        <dt className="text-xs font-semibold uppercase text-slate-500">
          {strings.config.fields.settlement_period}
        </dt>
        <dd className="text-slate-200">
          {strings.config.settlementPeriods[settlement.settlement_period]}
        </dd>
      </div>
    </dl>
  );
}

function DispatchSummary({ dispatch }: { dispatch: DispatchConfig }) {
  return (
    <dl className="grid grid-cols-3 gap-3 text-sm">
      <div>
        <dt className="text-xs font-semibold uppercase text-slate-500">
          {strings.config.fields.offer_ttl_seconds}
        </dt>
        <dd className="text-slate-200">{dispatch.offer_ttl_seconds}s</dd>
      </div>
      <div>
        <dt className="text-xs font-semibold uppercase text-slate-500">
          {strings.config.fields.search_radius_km}
        </dt>
        <dd className="text-slate-200">{dispatch.search_radius_km} km</dd>
      </div>
      <div>
        <dt className="text-xs font-semibold uppercase text-slate-500">
          {strings.config.fields.radius_widening_steps_km}
        </dt>
        <dd className="text-slate-200">{dispatch.radius_widening_steps_km.join(', ') || '—'}</dd>
      </div>
    </dl>
  );
}

type ConfigUpdateVariables =
  | { key: 'pricing'; value: PricingConfig }
  | { key: 'commission'; value: CommissionConfig }
  | { key: 'settlement'; value: SettlementConfig }
  | { key: 'dispatch'; value: DispatchConfig };

function updateConfigKey(vars: ConfigUpdateVariables): Promise<ConfigResponse> {
  switch (vars.key) {
    case 'pricing':
      return api.updateConfig('pricing', vars.value);
    case 'commission':
      return api.updateConfig('commission', vars.value);
    case 'settlement':
      return api.updateConfig('settlement', vars.value);
    case 'dispatch':
      return api.updateConfig('dispatch', vars.value);
  }
}

export function ConfigPage() {
  const queryClient = useQueryClient();
  const [editingKey, setEditingKey] = useState<ConfigKey | null>(null);

  const { data, isLoading } = useQuery({ queryKey: ['config'], queryFn: () => api.getConfig() });

  const mutation = useMutation({
    mutationFn: updateConfigKey,
    onSuccess: (response: ConfigResponse) => {
      queryClient.setQueryData(['config'], response);
      setEditingKey(null);
    },
  });

  if (isLoading || !data) {
    return <p className="text-sm text-slate-400">Cargando…</p>;
  }

  const { config, history } = data;

  return (
    <div className="flex flex-col gap-6">
      <div>
        <h1 className="text-xl font-bold text-slate-100">{strings.config.title}</h1>
        <p className="text-sm text-slate-400">{strings.config.subtitle}</p>
      </div>

      <div className="grid grid-cols-1 gap-4 lg:grid-cols-2">
        <Card>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-slate-200">{strings.config.keys.pricing}</h2>
            <Button variant="secondary" onClick={() => setEditingKey('pricing')}>
              {strings.config.edit}
            </Button>
          </div>
          <PricingSummary pricing={config.pricing} />
          <div className="mt-3 border-t border-slate-800 pt-2">
            <p className="mb-1 text-xs font-semibold text-slate-400">{strings.config.history}</p>
            <HistoryList history={history} configKey="pricing" />
          </div>
        </Card>

        <Card>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-slate-200">
              {strings.config.keys.commission}
            </h2>
            <Button variant="secondary" onClick={() => setEditingKey('commission')}>
              {strings.config.edit}
            </Button>
          </div>
          <CommissionSummary commission={config.commission} />
          <div className="mt-3 border-t border-slate-800 pt-2">
            <p className="mb-1 text-xs font-semibold text-slate-400">{strings.config.history}</p>
            <HistoryList history={history} configKey="commission" />
          </div>
        </Card>

        <Card>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-slate-200">
              {strings.config.keys.settlement}
            </h2>
            <Button variant="secondary" onClick={() => setEditingKey('settlement')}>
              {strings.config.edit}
            </Button>
          </div>
          <SettlementSummary settlement={config.settlement} />
          {config.settlement.balance_cap !== null && (
            <div className="mt-2">
              <Badge tone="info">{strings.config.fields.balance_cap}</Badge>
            </div>
          )}
          <div className="mt-3 border-t border-slate-800 pt-2">
            <p className="mb-1 text-xs font-semibold text-slate-400">{strings.config.history}</p>
            <HistoryList history={history} configKey="settlement" />
          </div>
        </Card>

        <Card>
          <div className="mb-3 flex items-center justify-between">
            <h2 className="text-sm font-semibold text-slate-200">{strings.config.keys.dispatch}</h2>
            <Button variant="secondary" onClick={() => setEditingKey('dispatch')}>
              {strings.config.edit}
            </Button>
          </div>
          <DispatchSummary dispatch={config.dispatch} />
          <div className="mt-3 border-t border-slate-800 pt-2">
            <p className="mb-1 text-xs font-semibold text-slate-400">{strings.config.history}</p>
            <HistoryList history={history} configKey="dispatch" />
          </div>
        </Card>
      </div>

      {mutation.isError && (
        <p role="alert" className="text-sm text-rose-400">
          {strings.config.saveError}
        </p>
      )}

      {editingKey === 'pricing' && (
        <Modal title={strings.config.keys.pricing} onClose={() => setEditingKey(null)}>
          <PricingForm
            initial={config.pricing}
            saving={mutation.isPending}
            onSave={(value) => mutation.mutate({ key: 'pricing', value })}
          />
        </Modal>
      )}
      {editingKey === 'commission' && (
        <Modal title={strings.config.keys.commission} onClose={() => setEditingKey(null)}>
          <CommissionForm
            initial={config.commission}
            saving={mutation.isPending}
            onSave={(value) => mutation.mutate({ key: 'commission', value })}
          />
        </Modal>
      )}
      {editingKey === 'settlement' && (
        <Modal title={strings.config.keys.settlement} onClose={() => setEditingKey(null)}>
          <SettlementForm
            initial={config.settlement}
            saving={mutation.isPending}
            onSave={(value) => mutation.mutate({ key: 'settlement', value })}
          />
        </Modal>
      )}
      {editingKey === 'dispatch' && (
        <Modal title={strings.config.keys.dispatch} onClose={() => setEditingKey(null)}>
          <DispatchForm
            initial={config.dispatch}
            saving={mutation.isPending}
            onSave={(value) => mutation.mutate({ key: 'dispatch', value })}
          />
        </Modal>
      )}
    </div>
  );
}
