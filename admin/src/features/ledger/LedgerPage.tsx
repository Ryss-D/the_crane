import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { api } from '../../api';
import type { DriverLedgerSummary, LedgerEntry } from '../../api/types';
import { formatCOP, formatDateTime } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Badge, Button, Card, Modal, Table, TBody, Td, Th, THead, Tr } from '../../ui';

const entryTone = {
  earning: 'warning',
  payout: 'success',
  adjustment: 'info',
} as const;

/** Earning rows accrue by their commission; payout/adjustment rows reduce
 * the balance by their net — mirrors driver_owed_balance exactly (see
 * mock.ts's driverBalance for the same formula against seed data). */
function entryAmount(e: LedgerEntry): number {
  return e.entry_type === 'earning' ? e.commission : -e.net;
}

function SettleModal({ driver, onClose }: { driver: DriverLedgerSummary; onClose: () => void }) {
  const queryClient = useQueryClient();
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');

  const mutation = useMutation({
    mutationFn: () =>
      api.settleLedger(driver.driver_id, {
        amount: Number(amount),
        ...(note.trim() && { note: note.trim() }),
      }),
    // The settle response is just the created entry (no fresh balance) —
    // refetch both queries rather than guess at the new numbers client-side.
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['ledger'] });
      void queryClient.invalidateQueries({ queryKey: ['ledgerEntries', driver.driver_id] });
      onClose();
    },
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!amount || Number(amount) <= 0) return;
    mutation.mutate();
  }

  return (
    <Modal title={`${strings.ledger.settleTitle} — ${driver.name}`} onClose={onClose}>
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
        <p className="text-xs text-slate-500">
          {strings.ledger.columns.balance}: {formatCOP(driver.owed_balance)}
        </p>
        <label className="flex flex-col gap-1 text-xs text-slate-400">
          {strings.ledger.amountLabel}
          <input
            type="number"
            min={1}
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
          />
        </label>
        <label className="flex flex-col gap-1 text-xs text-slate-400">
          {strings.ledger.noteLabel}
          <input
            type="text"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
          />
        </label>
        {mutation.isError && (
          <p role="alert" className="text-sm text-rose-400">
            {strings.ledger.settleError}
          </p>
        )}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose}>
            {strings.ledger.cancel}
          </Button>
          <Button type="submit" disabled={mutation.isPending || !amount || Number(amount) <= 0}>
            {strings.ledger.confirm}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

function DriverEntries({ driverId }: { driverId: string }) {
  const { data: entries, isLoading } = useQuery({
    queryKey: ['ledgerEntries', driverId],
    queryFn: () => api.getLedgerEntries(driverId),
  });

  if (isLoading || !entries) return <p className="text-sm text-slate-400">Cargando…</p>;
  if (entries.length === 0)
    return <p className="text-sm text-slate-500">{strings.ledger.noEntries}</p>;

  return (
    <Table>
      <THead>
        <Tr>
          <Th>Tipo</Th>
          <Th>Monto</Th>
          <Th>Nota</Th>
          <Th>Fecha</Th>
        </Tr>
      </THead>
      <TBody>
        {entries.map((e: LedgerEntry) => {
          const amount = entryAmount(e);
          return (
            <Tr key={e.id}>
              <Td>
                <Badge tone={entryTone[e.entry_type]}>
                  {strings.ledger.entryTypes[e.entry_type]}
                </Badge>
              </Td>
              <Td className={amount < 0 ? 'text-emerald-400' : 'text-slate-200'}>
                {formatCOP(amount)}
              </Td>
              <Td className="text-slate-400">{e.note ?? '—'}</Td>
              <Td className="text-xs text-slate-400">{formatDateTime(e.created_at)}</Td>
            </Tr>
          );
        })}
      </TBody>
    </Table>
  );
}

export function LedgerPage() {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [settlingDriver, setSettlingDriver] = useState<DriverLedgerSummary | null>(null);

  const { data: ledger, isLoading } = useQuery({
    queryKey: ['ledger'],
    queryFn: () => api.getLedger(),
  });
  // balance_cap is a single global value (platform_config.settlement), not
  // per-row — read it from the same config query ConfigPage uses instead of
  // expecting the backend to duplicate it onto every ledger row.
  const { data: configData } = useQuery({ queryKey: ['config'], queryFn: () => api.getConfig() });
  const balanceCap = configData?.config.settlement.balance_cap ?? null;

  const sorted = [...(ledger ?? [])].sort((a, b) => b.owed_balance - a.owed_balance);
  const selected = sorted.find((row) => row.driver_id === selectedId) ?? null;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-bold text-slate-100">{strings.ledger.title}</h1>

      {isLoading || !ledger ? (
        <p className="text-sm text-slate-400">Cargando…</p>
      ) : (
        <Table>
          <THead>
            <Tr>
              <Th>{strings.ledger.columns.driver}</Th>
              <Th>{strings.ledger.columns.balance}</Th>
              <Th>{strings.ledger.columns.actions}</Th>
            </Tr>
          </THead>
          <TBody>
            {sorted.map((row) => {
              const capped = balanceCap !== null && row.owed_balance >= balanceCap;
              return (
                <Tr
                  key={row.driver_id}
                  onClick={() => setSelectedId(row.driver_id === selectedId ? null : row.driver_id)}
                  className={row.driver_id === selectedId ? 'bg-slate-900/60' : ''}
                >
                  <Td>{row.name}</Td>
                  <Td>
                    <span className="font-semibold">{formatCOP(row.owed_balance)}</span>
                    {capped && (
                      <span className="ml-2">
                        <Badge tone="danger">{strings.ledger.capped}</Badge>
                      </span>
                    )}
                  </Td>
                  <Td>
                    <Button
                      variant="secondary"
                      onClick={(e) => {
                        e.stopPropagation();
                        setSettlingDriver(row);
                      }}
                    >
                      {strings.ledger.settle}
                    </Button>
                  </Td>
                </Tr>
              );
            })}
          </TBody>
        </Table>
      )}

      {selected && (
        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-200">
            {strings.ledger.entriesTitle} — {selected.name}
          </h2>
          <DriverEntries driverId={selected.driver_id} />
        </Card>
      )}

      {settlingDriver && (
        <SettleModal driver={settlingDriver} onClose={() => setSettlingDriver(null)} />
      )}
    </div>
  );
}
