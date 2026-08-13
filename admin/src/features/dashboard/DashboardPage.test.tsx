import { render, screen, within } from '@testing-library/react';
import { MemoryRouter } from 'react-router-dom';
import { describe, expect, it } from 'vitest';
import { AppShell, AppRoutes } from '../../App';
import { authClient } from '../../auth';
import { formatCOP } from '../../i18n/format';
import { strings } from '../../i18n/strings';

function renderDashboardPage() {
  return render(
    <MemoryRouter
      initialEntries={['/']}
      future={{ v7_startTransition: true, v7_relativeSplatPath: true }}
    >
      <AppShell>
        <AppRoutes />
      </AppShell>
    </MemoryRouter>,
  );
}

/** Reads a KpiCard's value: the label <p> and value <p> are siblings inside
 * the same Card, in that order (see DashboardPage.tsx's KpiCard). Compared
 * against raw (non-normalized) textContent, so the expected side must also
 * be the raw formatCOP(...) output — no getByText/NBSP normalization here. */
function kpiValue(label: string): string {
  const labelEl = screen.getByText(label);
  return labelEl.nextElementSibling?.textContent ?? '';
}

describe('DashboardPage (ADM-0)', () => {
  it('renders the seeded KPI totals', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    renderDashboardPage();

    await screen.findByText(strings.dashboard.title);

    // tripsToday: jobs requested within the last 24h. Of the 15 seeded jobs,
    // job_11 (30h), job_12 (28h) and job_14 (26.3h) fall outside that window.
    expect(kpiValue(strings.dashboard.tripsToday)).toBe('12');

    // activeTrucks: drivers with status available|on_job — drv_1, drv_2,
    // drv_7, drv_8 (drv_3/4/6 offline, drv_5 blocked).
    expect(kpiValue(strings.dashboard.activeTrucks)).toBe('4');

    // avgAssignmentTime: mean of (assigned_at - requested_at) across the 11
    // jobs that were ever assigned (job_14/job_15 never were) — 55.8min/11.
    expect(kpiValue(strings.dashboard.avgAssignmentTime)).toBe('5.1 min');

    // dayCommission: 15% commission on the two `completed` jobs whose
    // completed_at is within the last 24h — job_9 (100000*0.15=15000) and
    // job_10 (57500*0.15=8625); job_11/job_12 completed >24h ago don't count.
    expect(kpiValue(strings.dashboard.dayCommission)).toBe(formatCOP(23625));
  });

  it('lists the recent-activity feed newest-first', async () => {
    await authClient.signInWithPassword('admin@thecrane.local', 'anything');
    renderDashboardPage();

    const heading = await screen.findByText(strings.dashboard.recentActivity);
    const card = heading.closest('div') as HTMLElement;
    const items = within(card).getAllByRole('listitem');

    // Capped at the 10 most recent of the 32 seeded requested/assigned/
    // completed/cancelled events, ordered by timestamp descending.
    expect(items).toHaveLength(10);
    const texts = items.map((li) => li.textContent ?? '');

    expect(texts[0]).toContain('Daniela Ortiz solicitó una grúa (Moto)');
    expect(texts[1]).toContain('Felipe Arango solicitó una grúa (Carro)');
    expect(texts[2]).toContain('Jorge Salazar asignado al servicio job_3');
    expect(texts[3]).toContain('Valentina Ríos solicitó una grúa (Camioneta)');
    expect(texts[4]).toContain('Carlos Restrepo asignado al servicio job_4');
    expect(texts[5]).toContain('Santiago Vélez solicitó una grúa (Moto)');
    expect(texts[6]).toContain('Natalia Zapata asignado al servicio job_5');
    expect(texts[7]).toContain('Mariana Correa solicitó una grúa (Carro)');
    expect(texts[8]).toContain('Andrea Muñoz asignado al servicio job_6');
    expect(texts[9]).toContain('Juan Pablo Zea solicitó una grúa (Camioneta)');
  });
});
