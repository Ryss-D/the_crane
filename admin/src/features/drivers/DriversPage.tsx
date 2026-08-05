import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';
import { useState } from 'react';
import { api } from '../../api';
import type { Driver, DriverFilters, DriverStatus } from '../../api/types';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';
import { Badge, Button, Card, Modal, Table, TBody, Td, Th, THead, Tr } from '../../ui';

type VerifiedFilter = 'all' | 'verified' | 'unverified';
type StatusFilter = 'all' | DriverStatus;

const statusTone: Record<DriverStatus, 'neutral' | 'success' | 'info' | 'danger'> = {
  offline: 'neutral',
  available: 'success',
  on_job: 'info',
  blocked: 'danger',
};

export function DriversPage() {
  const queryClient = useQueryClient();
  const [verifiedFilter, setVerifiedFilter] = useState<VerifiedFilter>('all');
  const [statusFilter, setStatusFilter] = useState<StatusFilter>('all');
  const [docsDriver, setDocsDriver] = useState<Driver | null>(null);

  const filters: DriverFilters = {
    ...(verifiedFilter !== 'all' && { verified: verifiedFilter === 'verified' }),
    ...(statusFilter !== 'all' && { status: statusFilter }),
  };

  const { data: drivers, isLoading } = useQuery({
    queryKey: ['drivers', filters],
    queryFn: () => api.getDrivers(filters),
  });

  function updateDriverCache(updated: Driver) {
    queryClient.setQueriesData<Driver[]>({ queryKey: ['drivers'] }, (old) =>
      old ? old.map((d) => (d.user_id === updated.user_id ? updated : d)) : old,
    );
  }

  const verifyMutation = useMutation({
    mutationFn: (id: string) => api.verifyDriver(id),
    onSuccess: updateDriverCache,
  });
  const blockMutation = useMutation({
    mutationFn: (id: string) => api.blockDriver(id),
    onSuccess: updateDriverCache,
  });
  const unblockMutation = useMutation({
    mutationFn: (id: string) => api.unblockDriver(id),
    onSuccess: updateDriverCache,
  });

  const actionError = verifyMutation.isError || blockMutation.isError || unblockMutation.isError;
  const busyId = verifyMutation.isPending
    ? verifyMutation.variables
    : blockMutation.isPending
      ? blockMutation.variables
      : unblockMutation.isPending
        ? unblockMutation.variables
        : null;

  return (
    <div className="flex flex-col gap-4">
      <h1 className="text-xl font-bold text-slate-100">{strings.drivers.title}</h1>

      <div className="flex flex-wrap items-center gap-4">
        <label className="flex items-center gap-2 text-sm text-slate-300">
          {strings.drivers.filterVerified}
          <select
            value={verifiedFilter}
            onChange={(e) => setVerifiedFilter(e.target.value as VerifiedFilter)}
            className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
          >
            <option value="all">{strings.drivers.all}</option>
            <option value="verified">{strings.drivers.verified}</option>
            <option value="unverified">{strings.drivers.unverified}</option>
          </select>
        </label>
        <label className="flex items-center gap-2 text-sm text-slate-300">
          {strings.drivers.filterStatus}
          <select
            value={statusFilter}
            onChange={(e) => setStatusFilter(e.target.value as StatusFilter)}
            className="rounded-md border border-slate-700 bg-slate-800 px-2 py-1 text-sm text-slate-100 focus:border-amber-500 focus:outline-none"
          >
            <option value="all">{strings.drivers.all}</option>
            <option value="offline">{strings.driverStatuses.offline}</option>
            <option value="available">{strings.driverStatuses.available}</option>
            <option value="on_job">{strings.driverStatuses.on_job}</option>
          </select>
        </label>
      </div>

      {actionError && (
        <p role="alert" className="text-sm text-rose-400">
          {strings.drivers.actionError}
        </p>
      )}

      {isLoading || !drivers ? (
        <p className="text-sm text-slate-400">Cargando…</p>
      ) : drivers.length === 0 ? (
        <p className="text-sm text-slate-500">{strings.drivers.noDrivers}</p>
      ) : (
        <Table>
          <THead>
            <Tr>
              <Th>{strings.drivers.columns.name}</Th>
              <Th>{strings.drivers.columns.truck}</Th>
              <Th>{strings.drivers.columns.status}</Th>
              <Th>{strings.drivers.columns.verified}</Th>
              <Th>{strings.drivers.columns.balance}</Th>
              <Th>{strings.drivers.columns.rating}</Th>
              <Th>{strings.drivers.columns.actions}</Th>
            </Tr>
          </THead>
          <TBody>
            {drivers.map((driver) => (
              <Tr key={driver.user_id}>
                <Td>
                  <div className="font-medium text-slate-100">{driver.name}</div>
                  <div className="text-xs text-slate-500">{driver.phone}</div>
                </Td>
                <Td>
                  <div>{driver.truck?.plate ?? '—'}</div>
                  <div className="text-xs text-slate-500">{driver.truck?.type ?? '—'}</div>
                </Td>
                <Td>
                  <Badge tone={statusTone[driver.status]}>
                    {strings.driverStatuses[driver.status]}
                  </Badge>
                </Td>
                <Td>
                  {driver.verified ? (
                    <Badge tone="success">{strings.drivers.verified}</Badge>
                  ) : (
                    <div className="flex flex-col items-start gap-1">
                      <Badge tone="warning">{strings.drivers.unverified}</Badge>
                      <button
                        type="button"
                        onClick={() => setDocsDriver(driver)}
                        className="text-xs font-semibold text-amber-400 hover:text-amber-300"
                      >
                        {strings.drivers.documents}
                      </button>
                    </div>
                  )}
                </Td>
                <Td>{formatCOP(driver.owed_balance)}</Td>
                <Td>
                  {driver.rating_avg !== null && driver.rating_avg > 0
                    ? driver.rating_avg.toFixed(1)
                    : '—'}
                </Td>
                <Td>
                  <div className="flex flex-wrap gap-1.5">
                    {!driver.verified && (
                      <Button
                        variant="secondary"
                        disabled={busyId === driver.user_id}
                        onClick={() => verifyMutation.mutate(driver.user_id)}
                      >
                        {strings.drivers.verify}
                      </Button>
                    )}
                    {driver.status === 'blocked' ? (
                      <Button
                        variant="secondary"
                        disabled={busyId === driver.user_id}
                        onClick={() => unblockMutation.mutate(driver.user_id)}
                      >
                        {strings.drivers.unblock}
                      </Button>
                    ) : (
                      <Button
                        variant="danger"
                        disabled={busyId === driver.user_id}
                        onClick={() => blockMutation.mutate(driver.user_id)}
                      >
                        {strings.drivers.block}
                      </Button>
                    )}
                  </div>
                </Td>
              </Tr>
            ))}
          </TBody>
        </Table>
      )}

      {docsDriver && (
        <Modal
          title={`${strings.drivers.documents} — ${docsDriver.name}`}
          onClose={() => setDocsDriver(null)}
        >
          {docsDriver.license_url === null && docsDriver.truck_photo_url === null ? (
            <Card className="border-dashed">
              <p className="text-sm text-slate-400">{strings.drivers.documentsPlaceholder}</p>
            </Card>
          ) : (
            <ul className="flex flex-col gap-1.5 text-sm text-slate-300">
              {docsDriver.license_url !== null && (
                <li className="flex items-center justify-between">
                  <span>{strings.drivers.licenseDocument}</span>
                  <a
                    href={docsDriver.license_url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-amber-400 hover:text-amber-300"
                  >
                    {strings.drivers.viewDocument}
                  </a>
                </li>
              )}
              {docsDriver.truck_photo_url !== null && (
                <li className="flex items-center justify-between">
                  <span>{strings.drivers.truckPhotoDocument}</span>
                  <a
                    href={docsDriver.truck_photo_url}
                    target="_blank"
                    rel="noreferrer"
                    className="text-amber-400 hover:text-amber-300"
                  >
                    {strings.drivers.viewDocument}
                  </a>
                </li>
              )}
            </ul>
          )}
        </Modal>
      )}
    </div>
  );
}
