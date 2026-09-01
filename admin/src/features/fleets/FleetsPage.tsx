import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import type { FormEvent } from 'react';
import { api } from '../../api';
import type { AdminFleetListItem, FleetMemberBalance, FleetSettleResponse } from '../../api/types';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Button, Card, Modal, Table, TBody, Td, Th, THead, Tr } from '../../ui';

function SettleFleetModal({ fleet, onClose }: { fleet: AdminFleetListItem; onClose: () => void }) {
  const queryClient = useQueryClient();
  const [amount, setAmount] = useState('');
  const [note, setNote] = useState('');
  const [result, setResult] = useState<FleetSettleResponse | null>(null);

  // Reuses the ['fleetBalance', id] cache entry if the row was already
  // expanded — just for driver names in the confirmation breakdown below,
  // never blocks settling if it hasn't been fetched yet.
  const { data: balance } = useQuery({
    queryKey: ['fleetBalance', fleet.id],
    queryFn: () => api.getFleetBalance(fleet.id),
    enabled: result !== null,
  });
  const driverName = (driverId: string): string =>
    balance?.members.find((m) => m.driver_id === driverId)?.name ?? driverId;

  const mutation = useMutation({
    mutationFn: () =>
      api.settleFleet(fleet.id, {
        amount: Number(amount),
        ...(note.trim() && { note: note.trim() }),
      }),
    onSuccess: (response) => {
      setResult(response);
      // Refresh the list and this fleet's balance drill-down so both reflect
      // the settlement immediately — same pattern LedgerPage's settle uses.
      void queryClient.invalidateQueries({ queryKey: ['fleets'] });
      void queryClient.invalidateQueries({ queryKey: ['fleetBalance', fleet.id] });
    },
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!amount || Number(amount) <= 0) return;
    mutation.mutate();
  }

  if (result) {
    return (
      <Modal title={`${strings.fleets.settleResultTitle} — ${fleet.name}`} onClose={onClose}>
        <div className="flex flex-col gap-3">
          <p className="text-sm text-slate-300">
            {strings.fleets.settleResultTotal}:{' '}
            <span className="font-semibold text-slate-100">{formatCOP(result.total_amount)}</span>
          </p>
          <div>
            <p className="mb-1 text-xs font-semibold text-slate-400">
              {strings.fleets.settleResultBreakdown}
            </p>
            <Table>
              <THead>
                <Tr>
                  <Th>{strings.fleets.memberColumns.driver}</Th>
                  <Th>{strings.fleets.columns.balance}</Th>
                </Tr>
              </THead>
              <TBody>
                {result.entries.map((entry) => (
                  <Tr key={entry.ledger_entry_id}>
                    <Td>{driverName(entry.driver_id)}</Td>
                    <Td>{formatCOP(entry.amount)}</Td>
                  </Tr>
                ))}
              </TBody>
            </Table>
          </div>
          <div className="flex justify-end">
            <Button type="button" onClick={onClose}>
              {strings.fleets.close}
            </Button>
          </div>
        </div>
      </Modal>
    );
  }

  return (
    <Modal title={`${strings.fleets.settleTitle} — ${fleet.name}`} onClose={onClose}>
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
        <p className="text-xs text-slate-500">
          {strings.fleets.columns.balance}: {formatCOP(fleet.owed_balance)}
        </p>
        <label className="flex flex-col gap-1 text-xs text-slate-400">
          {strings.fleets.amountLabel}
          <input
            type="number"
            min={1}
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
          />
        </label>
        <label className="flex flex-col gap-1 text-xs text-slate-400">
          {strings.fleets.noteLabel}
          <input
            type="text"
            value={note}
            onChange={(e) => setNote(e.target.value)}
            className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
          />
        </label>
        {mutation.isError && (
          <p role="alert" className="text-sm text-rose-400">
            {strings.fleets.settleError}
          </p>
        )}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose}>
            {strings.fleets.cancel}
          </Button>
          <Button type="submit" disabled={mutation.isPending || !amount || Number(amount) <= 0}>
            {strings.fleets.confirm}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

/**
 * ADM-7 admin override (2026-08-31): reassign one truck to a different driver.
 * The eligible-drivers list reuses GET /v1/admin/drivers (DriversPage's own
 * `['drivers']` query, so the cache is shared) rather than a separate picker
 * endpoint — a plain dropdown was proportionate here since that data already
 * exists; a manual driver-id/phone text field was the documented fallback if
 * it hadn't. Every driver is listed (even ones who already have a different
 * truck) since overriding that is exactly what this control is for.
 */
function AssignDriverModal({
  fleetId,
  member,
  onClose,
}: {
  fleetId: string;
  member: FleetMemberBalance;
  onClose: () => void;
}) {
  const queryClient = useQueryClient();
  const [driverId, setDriverId] = useState('');

  const { data: drivers } = useQuery({ queryKey: ['drivers'], queryFn: () => api.getDrivers() });
  const eligible = (drivers ?? []).filter((d) => d.user_id !== member.driver_id);

  const mutation = useMutation({
    mutationFn: () => api.assignDriverToTruck(member.truck_id, driverId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['fleetBalance', fleetId] });
      void queryClient.invalidateQueries({ queryKey: ['fleets'] });
      void queryClient.invalidateQueries({ queryKey: ['drivers'] });
      onClose();
    },
  });

  function onSubmit(e: FormEvent) {
    e.preventDefault();
    if (!driverId) return;
    mutation.mutate();
  }

  return (
    <Modal
      title={`${strings.fleets.reassignTitle} — ${member.name ?? member.driver_id}`}
      onClose={onClose}
    >
      <form onSubmit={onSubmit} className="flex flex-col gap-3">
        <label className="flex flex-col gap-1 text-xs text-slate-400">
          {strings.fleets.driverLabel}
          <select
            value={driverId}
            onChange={(e) => setDriverId(e.target.value)}
            className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1.5 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
          >
            <option value="">{strings.fleets.selectDriver}</option>
            {eligible.map((d) => (
              <option key={d.user_id} value={d.user_id}>
                {d.name ?? d.user_id}
                {d.truck ? ` (${d.truck.plate})` : ''}
              </option>
            ))}
          </select>
        </label>
        {mutation.isError && (
          <p role="alert" className="text-sm text-rose-400">
            {strings.fleets.assignError}
          </p>
        )}
        <div className="flex justify-end gap-2">
          <Button type="button" variant="ghost" onClick={onClose}>
            {strings.fleets.cancel}
          </Button>
          <Button type="submit" disabled={mutation.isPending || !driverId}>
            {strings.fleets.confirm}
          </Button>
        </div>
      </form>
    </Modal>
  );
}

function FleetMembers({ fleetId }: { fleetId: string }) {
  const queryClient = useQueryClient();
  const [reassigning, setReassigning] = useState<FleetMemberBalance | null>(null);
  const { data: balance, isLoading } = useQuery({
    queryKey: ['fleetBalance', fleetId],
    queryFn: () => api.getFleetBalance(fleetId),
  });

  const unassignMutation = useMutation({
    mutationFn: (truckId: string) => api.unassignDriverFromTruck(truckId),
    onSuccess: () => {
      void queryClient.invalidateQueries({ queryKey: ['fleetBalance', fleetId] });
      void queryClient.invalidateQueries({ queryKey: ['fleets'] });
      void queryClient.invalidateQueries({ queryKey: ['drivers'] });
    },
  });

  if (isLoading || !balance) return <p className="text-sm text-slate-400">Cargando…</p>;
  if (balance.members.length === 0)
    return <p className="text-sm text-slate-500">{strings.fleets.noFleets}</p>;

  return (
    <>
      {unassignMutation.isError && (
        <p role="alert" className="mb-2 text-sm text-rose-400">
          {strings.fleets.unassignError}
        </p>
      )}
      <Table>
        <THead>
          <Tr>
            <Th>{strings.fleets.memberColumns.driver}</Th>
            <Th>{strings.fleets.memberColumns.balance}</Th>
            <Th>{strings.fleets.memberColumns.actions}</Th>
          </Tr>
        </THead>
        <TBody>
          {balance.members.map((member) => (
            <Tr key={member.driver_id}>
              <Td>{member.name ?? member.driver_id}</Td>
              <Td className="font-semibold">{formatCOP(member.owed_balance)}</Td>
              <Td>
                <div className="flex flex-wrap gap-1.5">
                  <Button variant="secondary" onClick={() => setReassigning(member)}>
                    {strings.fleets.reassign}
                  </Button>
                  <Button
                    variant="danger"
                    disabled={unassignMutation.isPending}
                    onClick={() => unassignMutation.mutate(member.truck_id)}
                  >
                    {strings.fleets.unassign}
                  </Button>
                </div>
              </Td>
            </Tr>
          ))}
        </TBody>
      </Table>

      {reassigning && (
        <AssignDriverModal
          fleetId={fleetId}
          member={reassigning}
          onClose={() => setReassigning(null)}
        />
      )}
    </>
  );
}

export function FleetsPage() {
  const [selectedId, setSelectedId] = useState<string | null>(null);
  const [settlingFleet, setSettlingFleet] = useState<AdminFleetListItem | null>(null);

  const { data: fleets, isLoading } = useQuery({
    queryKey: ['fleets'],
    queryFn: () => api.getFleets(),
  });

  const selected = (fleets ?? []).find((row) => row.id === selectedId) ?? null;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-bold text-slate-100">{strings.fleets.title}</h1>

      {isLoading || !fleets ? (
        <p className="text-sm text-slate-400">Cargando…</p>
      ) : fleets.length === 0 ? (
        <p className="text-sm text-slate-500">{strings.fleets.noFleets}</p>
      ) : (
        <Table>
          <THead>
            <Tr>
              <Th>{strings.fleets.columns.owner}</Th>
              <Th>{strings.fleets.columns.fleet}</Th>
              <Th>{strings.fleets.columns.trucks}</Th>
              <Th>{strings.fleets.columns.balance}</Th>
              <Th>{strings.fleets.columns.actions}</Th>
            </Tr>
          </THead>
          <TBody>
            {fleets.map((row) => (
              <Tr
                key={row.id}
                onClick={() => setSelectedId(row.id === selectedId ? null : row.id)}
                className={row.id === selectedId ? 'bg-slate-900/60' : ''}
              >
                <Td>{row.owner_name ?? '—'}</Td>
                <Td>{row.name}</Td>
                <Td>{row.truck_count}</Td>
                <Td className="font-semibold">{formatCOP(row.owed_balance)}</Td>
                <Td>
                  <Button
                    variant="secondary"
                    onClick={(e) => {
                      e.stopPropagation();
                      setSettlingFleet(row);
                    }}
                  >
                    {strings.fleets.settle}
                  </Button>
                </Td>
              </Tr>
            ))}
          </TBody>
        </Table>
      )}

      {selected && (
        <Card>
          <h2 className="mb-3 text-sm font-semibold text-slate-200">
            {strings.fleets.membersTitle} — {selected.name}
          </h2>
          <FleetMembers fleetId={selected.id} />
        </Card>
      )}

      {settlingFleet && (
        <SettleFleetModal fleet={settlingFleet} onClose={() => setSettlingFleet(null)} />
      )}
    </div>
  );
}
