import type { CraneAdminApi } from './client';
import { ApiError } from './client';
import type {
  ConfigAuditEntry,
  ConfigKey,
  ConfigResponse,
  Driver,
  DriverFilters,
  DriverLedgerSummary,
  Job,
  JobDetail,
  JobFilters,
  JobOffer,
  LedgerEntry,
  LedgerEntryType,
  PlatformConfig,
  SettleRequest,
  SettleResponse,
  Truck,
  TruckCapacity,
} from './types';
import { authClient } from '../auth/singleton';

function hoursAgo(h: number): string {
  return new Date(Date.now() - h * 3600 * 1000).toISOString();
}
function daysAgo(d: number): string {
  return hoursAgo(d * 24);
}

function clone<T>(value: T): T {
  return typeof structuredClone === 'function'
    ? structuredClone(value)
    : (JSON.parse(JSON.stringify(value)) as T);
}

const DEFAULT_CONFIG: PlatformConfig = {
  pricing: {
    moto: { base_fare: 40000, per_km: 3500, min_fare: 50000 },
    car: { base_fare: 60000, per_km: 5000, min_fare: 80000 },
    suv: { base_fare: 70000, per_km: 5500, min_fare: 90000 },
  },
  commission: { mode: 'percent', rate: { moto: 0.15, car: 0.15, suv: 0.15 } },
  settlement: { balance_cap: 150000, settlement_period: 'weekly' },
  dispatch: { offer_ttl_seconds: 30, search_radius_km: 10, radius_widening_steps_km: [15, 25] },
};

/** One `Truck` per driver — matches AdminDriverRead's nested shape. */
function truck(id: string, plate: string, type: Truck['type'], capacity: TruckCapacity): Truck {
  return { id, plate, type, capacity, driver_id: id, fleet_id: null };
}

/** Seed drivers — ~8, spanning verification/status/blocked/balance states.
 * Matches AdminDriverRead exactly: user_id (not id), no blocked flag (status
 * IS 'blocked'), truck nested, owed_balance (not balance), no documents
 * array — just the two URL fields a driver submits at registration. */
function seedDrivers(): Driver[] {
  return [
    {
      user_id: 'drv_1',
      name: 'Carlos Restrepo',
      phone: '+57 300 111 2233',
      email: 'carlos.restrepo@example.com',
      status: 'available',
      verified: true,
      truck: truck('truck_1', 'TKX-482', 'flatbed', 'both'),
      rating_avg: 4.8,
      owed_balance: 45000,
      license_url: '#',
      truck_photo_url: '#',
    },
    {
      user_id: 'drv_2',
      name: 'Andrea Muñoz',
      phone: '+57 301 222 3344',
      email: 'andrea.munoz@example.com',
      status: 'on_job',
      verified: true,
      truck: truck('truck_2', 'WQP-119', 'standard', 'car'),
      rating_avg: 4.6,
      owed_balance: 82000,
      license_url: '#',
      truck_photo_url: '#',
    },
    {
      user_id: 'drv_3',
      name: 'Jorge Salazar',
      phone: '+57 302 333 4455',
      email: 'jorge.salazar@example.com',
      status: 'offline',
      verified: true,
      truck: truck('truck_3', 'MTX-733', 'moto_only', 'moto'),
      rating_avg: 4.4,
      owed_balance: 165000,
      license_url: '#',
      truck_photo_url: '#',
    },
    {
      user_id: 'drv_4',
      name: 'Luisa Fernanda Gómez',
      phone: '+57 303 444 5566',
      email: 'luisa.gomez@example.com',
      status: 'offline',
      verified: false,
      truck: truck('truck_4', 'PND-004', 'standard', 'car'),
      rating_avg: null,
      owed_balance: 0,
      license_url: '#',
      truck_photo_url: null,
    },
    {
      user_id: 'drv_5',
      name: 'Miguel Ángel Torres',
      phone: '+57 304 555 6677',
      email: 'miguel.torres@example.com',
      status: 'blocked',
      verified: true,
      truck: truck('truck_5', 'BKD-501', 'flatbed', 'both'),
      rating_avg: 4.1,
      owed_balance: 30000,
      license_url: '#',
      truck_photo_url: '#',
    },
    {
      user_id: 'drv_6',
      name: 'Paula Ramírez',
      phone: '+57 305 666 7788',
      email: 'paula.ramirez@example.com',
      status: 'offline',
      verified: false,
      truck: truck('truck_6', 'PND-006', 'moto_only', 'moto'),
      rating_avg: null,
      owed_balance: 0,
      license_url: null,
      truck_photo_url: null,
    },
    {
      user_id: 'drv_7',
      name: 'Esteban Cardona',
      phone: '+57 306 777 8899',
      email: 'esteban.cardona@example.com',
      status: 'available',
      verified: true,
      truck: truck('truck_7', 'NCV-220', 'moto_only', 'moto'),
      rating_avg: 4.9,
      owed_balance: 12000,
      license_url: '#',
      truck_photo_url: '#',
    },
    {
      user_id: 'drv_8',
      name: 'Natalia Zapata',
      phone: '+57 307 888 9900',
      email: 'natalia.zapata@example.com',
      status: 'on_job',
      verified: true,
      truck: truck('truck_8', 'SLR-884', 'standard', 'car'),
      rating_avg: 4.7,
      owed_balance: 95000,
      license_url: '#',
      truck_photo_url: '#',
    },
  ];
}

function offer(
  id: string,
  driverId: string,
  driverName: string,
  offeredHoursAgo: number,
  response: JobOffer['response'],
  respondedAfterMin?: number,
): JobOffer {
  const offered_at = hoursAgo(offeredHoursAgo);
  const responded_at =
    response === 'pending' ? null : hoursAgo(offeredHoursAgo - (respondedAfterMin ?? 5) / 60);
  return { id, driver_id: driverId, driver_name: driverName, offered_at, responded_at, response };
}

/** Seed jobs — ~15, spanning the full status set (docs/PLAN.md §2.3 + §2.4). */
function seedJobs(): JobDetail[] {
  const jobs: JobDetail[] = [
    {
      id: 'job_1',
      status: 'requested',
      customer_name: 'Daniela Ortiz',
      customer_phone: '+57 310 123 4567',
      driver_id: null,
      driver_name: null,
      vehicle_type: 'moto',
      pickup_address: 'Cra. 70 #45-12, Laureles, Medellín',
      dropoff_address: 'Taller Motos JC, Belén, Medellín',
      distance_km: 4.2,
      quoted_price: 40000 + 4.2 * 3500,
      final_price: null,
      requested_at: hoursAgo(0.2),
      assigned_at: null,
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [],
    },
    {
      id: 'job_2',
      status: 'matching',
      customer_name: 'Felipe Arango',
      customer_phone: '+57 311 234 5678',
      driver_id: null,
      driver_name: null,
      vehicle_type: 'car',
      pickup_address: 'Cl. 33 #70-15, Robledo, Medellín',
      dropoff_address: 'Autoservicio Norte, Bello',
      distance_km: 9.6,
      quoted_price: 60000 + 9.6 * 5000,
      final_price: null,
      requested_at: hoursAgo(0.3),
      assigned_at: null,
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [offer('off_2_1', 'drv_3', 'Jorge Salazar', 0.02, 'pending')],
    },
    {
      id: 'job_3',
      status: 'assigned',
      customer_name: 'Valentina Ríos',
      customer_phone: '+57 312 345 6789',
      driver_id: 'drv_3',
      driver_name: 'Jorge Salazar',
      vehicle_type: 'suv',
      pickup_address: 'Cra. 43A #5-15, El Poblado, Medellín',
      dropoff_address: 'Taller Camionetas Sur, Envigado',
      distance_km: 6.8,
      quoted_price: 70000 + 6.8 * 5500,
      final_price: null,
      requested_at: hoursAgo(1.1),
      assigned_at: hoursAgo(1.0),
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [
        offer('off_3_1', 'drv_1', 'Carlos Restrepo', 1.15, 'rejected'),
        offer('off_3_2', 'drv_3', 'Jorge Salazar', 1.08, 'accepted'),
      ],
    },
    {
      id: 'job_4',
      status: 'en_route_pickup',
      customer_name: 'Santiago Vélez',
      customer_phone: '+57 313 456 7890',
      driver_id: 'drv_1',
      driver_name: 'Carlos Restrepo',
      vehicle_type: 'moto',
      pickup_address: 'Cra. 65 #10-20, Belén, Medellín',
      dropoff_address: 'Motos Express, La América, Medellín',
      distance_km: 5.4,
      quoted_price: 40000 + 5.4 * 3500,
      final_price: null,
      requested_at: hoursAgo(1.6),
      assigned_at: hoursAgo(1.5),
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [offer('off_4_1', 'drv_1', 'Carlos Restrepo', 1.58, 'accepted')],
    },
    {
      id: 'job_5',
      status: 'arrived_pickup',
      customer_name: 'Mariana Correa',
      customer_phone: '+57 314 567 8901',
      driver_id: 'drv_8',
      driver_name: 'Natalia Zapata',
      vehicle_type: 'car',
      pickup_address: 'Cl. 9 #43F-15, El Poblado, Medellín',
      dropoff_address: 'Concesionario Sur, Sabaneta',
      distance_km: 7.1,
      quoted_price: 60000 + 7.1 * 5000,
      final_price: null,
      requested_at: hoursAgo(2.2),
      assigned_at: hoursAgo(2.1),
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [
        offer('off_5_1', 'drv_7', 'Esteban Cardona', 2.1, 'timeout'),
        offer('off_5_2', 'drv_8', 'Natalia Zapata', 1.97, 'accepted'),
      ],
    },
    {
      id: 'job_6',
      status: 'loading',
      customer_name: 'Juan Pablo Zea',
      customer_phone: '+57 315 678 9012',
      driver_id: 'drv_2',
      driver_name: 'Andrea Muñoz',
      vehicle_type: 'suv',
      pickup_address: 'Cra. 80 #33-10, Robledo, Medellín',
      dropoff_address: 'Taller Camionetas Norte, Bello',
      distance_km: 8.9,
      quoted_price: 70000 + 8.9 * 5500,
      final_price: null,
      requested_at: hoursAgo(2.3),
      assigned_at: hoursAgo(2.25),
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [offer('off_6_1', 'drv_2', 'Andrea Muñoz', 2.25, 'accepted')],
    },
    {
      id: 'job_7',
      status: 'in_transit',
      customer_name: 'Laura Gómez',
      customer_phone: '+57 316 789 0123',
      driver_id: 'drv_7',
      driver_name: 'Esteban Cardona',
      vehicle_type: 'moto',
      pickup_address: 'Cl. 44 #70-30, Laureles, Medellín',
      dropoff_address: 'Motos del Sur, Itagüí',
      distance_km: 6.2,
      quoted_price: 40000 + 6.2 * 3500,
      final_price: null,
      requested_at: hoursAgo(3.1),
      assigned_at: hoursAgo(2.97),
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [
        offer('off_7_1', 'drv_3', 'Jorge Salazar', 3.08, 'rejected'),
        offer('off_7_2', 'drv_7', 'Esteban Cardona', 2.97, 'accepted'),
      ],
    },
    {
      id: 'job_8',
      status: 'delivered',
      customer_name: 'Camilo Restrepo',
      customer_phone: '+57 317 890 1234',
      driver_id: 'drv_1',
      driver_name: 'Carlos Restrepo',
      vehicle_type: 'car',
      pickup_address: 'Cra. 48 #20-30, La Milagrosa, Medellín',
      dropoff_address: 'Taller Central, Centro, Medellín',
      distance_km: 4.9,
      quoted_price: 60000 + 4.9 * 5000,
      final_price: 60000 + 4.9 * 5000,
      requested_at: hoursAgo(4.1),
      assigned_at: hoursAgo(4.05),
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [offer('off_8_1', 'drv_1', 'Carlos Restrepo', 4.05, 'accepted')],
    },
    {
      id: 'job_9',
      status: 'completed',
      customer_name: 'Isabela Toro',
      customer_phone: '+57 318 901 2345',
      driver_id: 'drv_1',
      driver_name: 'Carlos Restrepo',
      vehicle_type: 'car',
      pickup_address: 'Cra. 43A #1-50, El Poblado, Medellín',
      dropoff_address: 'Taller Central, Centro, Medellín',
      distance_km: 8,
      quoted_price: 100000,
      final_price: 100000,
      requested_at: hoursAgo(5),
      assigned_at: hoursAgo(4.9),
      completed_at: hoursAgo(4.5),
      cancelled_at: null,
      cancel_reason: null,
      offers: [
        offer('off_9_1', 'drv_2', 'Andrea Muñoz', 4.98, 'rejected'),
        offer('off_9_2', 'drv_1', 'Carlos Restrepo', 4.9, 'accepted'),
      ],
    },
    {
      id: 'job_10',
      status: 'completed',
      customer_name: 'Julián Herrera',
      customer_phone: '+57 319 012 3456',
      driver_id: 'drv_7',
      driver_name: 'Esteban Cardona',
      vehicle_type: 'moto',
      pickup_address: 'Cl. 30 #65-20, Laureles, Medellín',
      dropoff_address: 'Motos Express, La América, Medellín',
      distance_km: 5,
      quoted_price: 57500,
      final_price: 57500,
      requested_at: hoursAgo(6),
      assigned_at: hoursAgo(5.95),
      completed_at: hoursAgo(5.5),
      cancelled_at: null,
      cancel_reason: null,
      offers: [offer('off_10_1', 'drv_7', 'Esteban Cardona', 5.95, 'accepted')],
    },
    {
      id: 'job_11',
      status: 'completed',
      customer_name: 'Sara Londoño',
      customer_phone: '+57 320 123 4567',
      driver_id: 'drv_8',
      driver_name: 'Natalia Zapata',
      vehicle_type: 'suv',
      pickup_address: 'Cra. 25 #10-40, Envigado',
      dropoff_address: 'Concesionario Sur, Sabaneta',
      distance_km: 12,
      quoted_price: 136000,
      final_price: 136000,
      requested_at: hoursAgo(30),
      assigned_at: hoursAgo(29.9),
      completed_at: hoursAgo(29),
      cancelled_at: null,
      cancel_reason: null,
      offers: [
        offer('off_11_1', 'drv_3', 'Jorge Salazar', 29.95, 'timeout'),
        offer('off_11_2', 'drv_8', 'Natalia Zapata', 29.83, 'accepted'),
      ],
    },
    {
      id: 'job_12',
      status: 'completed',
      customer_name: 'Tomás Uribe',
      customer_phone: '+57 321 234 5678',
      driver_id: 'drv_2',
      driver_name: 'Andrea Muñoz',
      vehicle_type: 'car',
      pickup_address: 'Cl. 10 #52-25, Guayabal, Medellín',
      dropoff_address: 'Autoservicio Sur, Itagüí',
      distance_km: 3,
      quoted_price: 75000,
      final_price: 75000,
      requested_at: hoursAgo(28),
      assigned_at: hoursAgo(27.9),
      completed_at: hoursAgo(27),
      cancelled_at: null,
      cancel_reason: null,
      offers: [offer('off_12_1', 'drv_2', 'Andrea Muñoz', 27.95, 'accepted')],
    },
    {
      id: 'job_13',
      status: 'cancelled',
      customer_name: 'Manuela Restrepo',
      customer_phone: '+57 322 345 6789',
      driver_id: 'drv_1',
      driver_name: 'Carlos Restrepo',
      vehicle_type: 'car',
      pickup_address: 'Cra. 43A #10-20, El Poblado, Medellín',
      dropoff_address: 'Taller Central, Centro, Medellín',
      distance_km: 5.5,
      quoted_price: 60000 + 5.5 * 5000,
      final_price: null,
      requested_at: hoursAgo(3.7),
      assigned_at: hoursAgo(3.65),
      completed_at: null,
      cancelled_at: hoursAgo(3.4),
      cancel_reason: 'Cliente canceló',
      offers: [offer('off_13_1', 'drv_1', 'Carlos Restrepo', 3.65, 'accepted')],
    },
    {
      id: 'job_14',
      status: 'cancelled',
      customer_name: 'Ricardo Peña',
      customer_phone: '+57 323 456 7890',
      driver_id: null,
      driver_name: null,
      vehicle_type: 'moto',
      pickup_address: 'Cra. 76 #34-10, Robledo, Medellín',
      dropoff_address: 'Motos del Norte, Bello',
      distance_km: 6,
      quoted_price: 40000 + 6 * 3500,
      final_price: null,
      requested_at: hoursAgo(26.3),
      assigned_at: null,
      completed_at: null,
      cancelled_at: hoursAgo(26),
      cancel_reason: 'Cliente canceló antes de asignar',
      offers: [
        offer('off_14_1', 'drv_3', 'Jorge Salazar', 26.2, 'timeout'),
        offer('off_14_2', 'drv_7', 'Esteban Cardona', 26.1, 'timeout'),
      ],
    },
    {
      id: 'job_15',
      status: 'no_drivers',
      customer_name: 'Gabriela Salazar',
      customer_phone: '+57 324 567 8901',
      driver_id: null,
      driver_name: null,
      vehicle_type: 'suv',
      pickup_address: 'Cl. 12 Sur #43-20, El Poblado, Medellín',
      dropoff_address: 'Taller Camionetas Sur, Envigado',
      distance_km: 7,
      quoted_price: 70000 + 7 * 5500,
      final_price: null,
      requested_at: hoursAgo(4.7),
      assigned_at: null,
      completed_at: null,
      cancelled_at: null,
      cancel_reason: null,
      offers: [
        offer('off_15_1', 'drv_1', 'Carlos Restrepo', 4.6, 'rejected'),
        offer('off_15_2', 'drv_2', 'Andrea Muñoz', 4.55, 'rejected'),
        offer('off_15_3', 'drv_3', 'Jorge Salazar', 4.5, 'timeout'),
      ],
    },
  ];
  return jobs;
}

let ledgerSeq = 0;
/**
 * `amount` means "commission accrued" for an `earning` row or "amount
 * settled" for `payout`/`adjustment` — matching how the real backend's
 * driver_owed_balance actually sums entries (app/services/ledger.py):
 * + earning.commission, − payout|adjustment.net. `gross`/`net` are derived
 * so an earning row looks like a real fare (commission ≈ 15% of gross).
 */
function ledgerEntry(
  driverId: string,
  entryType: LedgerEntryType,
  amount: number,
  createdDaysAgo: number,
  jobId: string | null = null,
  note: string | null = null,
): LedgerEntry {
  const isEarning = entryType === 'earning';
  const commission = isEarning ? amount : 0;
  const gross = isEarning ? Math.round(amount / 0.15) : amount;
  const net = isEarning ? gross - commission : amount;
  return {
    id: `ldg_${++ledgerSeq}`,
    driver_id: driverId,
    job_id: jobId,
    gross,
    commission,
    net,
    entry_type: entryType,
    note,
    created_at: daysAgo(createdDaysAgo),
  };
}

function seedLedgerEntries(): LedgerEntry[] {
  return [
    // drv_1 Carlos — target balance 45000
    ledgerEntry('drv_1', 'earning', 30000, 20, null, 'Comisiones período anterior'),
    ledgerEntry('drv_1', 'earning', 15000, 4.5 / 24, 'job_9'),
    ledgerEntry('drv_1', 'payout', 25000, 12, null, 'Pago Nequi parcial'),
    ledgerEntry('drv_1', 'earning', 25000, 6, null, 'Comisiones semana previa'),
    // drv_2 Andrea — target balance 82000
    ledgerEntry('drv_2', 'earning', 40000, 15, null, 'Comisiones período anterior'),
    ledgerEntry('drv_2', 'earning', 11250, 27 / 24, 'job_12'),
    ledgerEntry('drv_2', 'earning', 30750, 8, null, 'Comisiones semana previa'),
    // drv_3 Jorge — target balance 165000 (over the 150000 cap)
    ledgerEntry('drv_3', 'earning', 60000, 25, null, 'Comisiones período anterior'),
    ledgerEntry('drv_3', 'earning', 70000, 18, null, 'Comisiones período anterior'),
    ledgerEntry('drv_3', 'earning', 35000, 9, null, 'Comisiones semana previa'),
    // drv_5 Miguel (blocked) — target balance 30000
    ledgerEntry('drv_5', 'earning', 50000, 20, null, 'Comisiones período anterior'),
    ledgerEntry('drv_5', 'payout', 20000, 10, null, 'Liquidación semanal'),
    // drv_7 Esteban — target balance 12000
    ledgerEntry('drv_7', 'earning', 8625, 5.5 / 24, 'job_10'),
    ledgerEntry('drv_7', 'earning', 3375, 7, null, 'Comisiones semana previa'),
    // drv_8 Natalia — target balance 95000
    ledgerEntry('drv_8', 'earning', 50000, 14, null, 'Comisiones período anterior'),
    ledgerEntry('drv_8', 'earning', 20400, 29 / 24, 'job_11'),
    ledgerEntry('drv_8', 'earning', 24600, 5, null, 'Comisiones semana previa'),
  ];
}

function seedConfigHistory(config: PlatformConfig): ConfigAuditEntry[] {
  const admin = 'admin@thecrane.local';
  return [
    {
      id: 'cfg_h_1',
      key: 'commission',
      changed_by: admin,
      changed_at: daysAgo(10),
      previous_value: { mode: 'percent', rate: { moto: 0.12, car: 0.12, suv: 0.12 } },
      new_value: config.commission,
    },
    {
      id: 'cfg_h_2',
      key: 'dispatch',
      changed_by: admin,
      changed_at: daysAgo(20),
      previous_value: { ...config.dispatch, offer_ttl_seconds: 45 },
      new_value: config.dispatch,
    },
    {
      id: 'cfg_h_3',
      key: 'pricing',
      changed_by: admin,
      changed_at: daysAgo(30),
      previous_value: {
        ...config.pricing,
        car: { base_fare: 60000, per_km: 4500, min_fare: 80000 },
      },
      new_value: config.pricing,
    },
    {
      id: 'cfg_h_4',
      key: 'settlement',
      changed_by: admin,
      changed_at: daysAgo(35),
      previous_value: { balance_cap: null, settlement_period: 'weekly' },
      new_value: config.settlement,
    },
    {
      id: 'cfg_h_5',
      key: 'dispatch',
      changed_by: 'ops@thecrane.local',
      changed_at: daysAgo(40),
      previous_value: { ...config.dispatch, search_radius_km: 8 },
      new_value: { ...config.dispatch, search_radius_km: 10 },
    },
  ];
}

/**
 * In-memory fake of the `/v1/admin/*` router (ADM-2, built concurrently — see
 * src/api/client.ts header comment). Seeded with realistic drivers/jobs/ledger
 * data so every ADM-3..6 screen has something to show without a backend.
 */
export class MockApi implements CraneAdminApi {
  private config: PlatformConfig = clone(DEFAULT_CONFIG);
  private history: ConfigAuditEntry[] = seedConfigHistory(this.config);
  private readonly drivers = new Map<string, Driver>(seedDrivers().map((d) => [d.user_id, d]));
  private readonly jobs = new Map<string, JobDetail>(seedJobs().map((j) => [j.id, j]));
  private ledger: LedgerEntry[] = seedLedgerEntries();

  constructor(private readonly latencyMs: number = 350) {}

  private delay(): Promise<void> {
    if (this.latencyMs <= 0) return Promise.resolve();
    return new Promise((r) => setTimeout(r, this.latencyMs));
  }

  private currentAdminEmail(): string {
    return authClient.getCurrentUser()?.email ?? 'admin@thecrane.local';
  }

  private requireDriver(id: string): Driver {
    const driver = this.drivers.get(id);
    if (!driver) throw new ApiError(404, `driver ${id} not found`);
    return driver;
  }

  // -- Config ---------------------------------------------------------------

  async getConfig(): Promise<ConfigResponse> {
    await this.delay();
    return { config: clone(this.config), history: clone(this.history) };
  }

  async updateConfig<K extends ConfigKey>(
    key: K,
    value: PlatformConfig[K],
  ): Promise<ConfigResponse> {
    await this.delay();
    const previous = clone(this.config[key]);
    this.config = { ...this.config, [key]: clone(value) };
    const entry: ConfigAuditEntry = {
      id: `cfg_h_${this.history.length + 1}_${Date.now()}`,
      key,
      changed_by: this.currentAdminEmail(),
      changed_at: new Date().toISOString(),
      previous_value: previous,
      new_value: clone(value),
    };
    this.history = [entry, ...this.history];
    return { config: clone(this.config), history: clone(this.history) };
  }

  // -- Drivers ----------------------------------------------------------------

  async getDrivers(filters: DriverFilters = {}): Promise<Driver[]> {
    await this.delay();
    let list = [...this.drivers.values()];
    if (filters.verified !== undefined) list = list.filter((d) => d.verified === filters.verified);
    if (filters.status !== undefined) list = list.filter((d) => d.status === filters.status);
    return clone(list);
  }

  async verifyDriver(id: string): Promise<Driver> {
    await this.delay();
    const driver = this.requireDriver(id);
    const updated: Driver = { ...driver, verified: true };
    this.drivers.set(id, updated);
    return clone(updated);
  }

  async blockDriver(id: string): Promise<Driver> {
    await this.delay();
    const driver = this.requireDriver(id);
    const updated: Driver = { ...driver, status: 'blocked' };
    this.drivers.set(id, updated);
    return clone(updated);
  }

  async unblockDriver(id: string): Promise<Driver> {
    await this.delay();
    const driver = this.requireDriver(id);
    const updated: Driver = { ...driver, status: 'offline' };
    this.drivers.set(id, updated);
    return clone(updated);
  }

  // -- Jobs / operations ------------------------------------------------------

  async getJobs(filters: JobFilters = {}): Promise<Job[]> {
    await this.delay();
    let list = [...this.jobs.values()];
    if (filters.status !== undefined) list = list.filter((j) => j.status === filters.status);
    list = list.sort(
      (a, b) => new Date(b.requested_at).getTime() - new Date(a.requested_at).getTime(),
    );
    // The real list endpoint doesn't include the offer trail — only the
    // single-job detail endpoint (getJob) does.
    return clone(list.map(({ offers: _offers, ...job }) => job));
  }

  async getJob(id: string): Promise<JobDetail> {
    await this.delay();
    const job = this.jobs.get(id);
    if (!job) throw new ApiError(404, `job ${id} not found`);
    return clone(job);
  }

  async cancelJob(id: string, reason?: string): Promise<Job> {
    await this.delay();
    const job = this.jobs.get(id);
    if (!job) throw new ApiError(404, `job ${id} not found`);
    if (job.status === 'completed' || job.status === 'cancelled' || job.status === 'no_drivers') {
      throw new ApiError(409, `job ${id} is already terminal (${job.status})`);
    }
    const updated: JobDetail = {
      ...job,
      status: 'cancelled',
      cancelled_at: new Date().toISOString(),
      cancel_reason: reason ?? 'Cancelado por administrador',
    };
    this.jobs.set(id, updated);
    const { offers: _offers, ...jobOnly } = updated;
    return clone(jobOnly);
  }

  // -- Ledger / settlements ----------------------------------------------------

  /** Mirrors driver_owed_balance (app/services/ledger.py) exactly: earning
   * commissions accrue, payout/adjustment nets reduce. No denormalized
   * balance field on Driver — this is computed fresh, same as the backend. */
  private driverBalance(driverId: string): number {
    return this.ledger
      .filter((e) => e.driver_id === driverId)
      .reduce((sum, e) => sum + (e.entry_type === 'earning' ? e.commission : -e.net), 0);
  }

  async getLedger(): Promise<DriverLedgerSummary[]> {
    await this.delay();
    return clone(
      [...this.drivers.values()].map((d) => ({
        driver_id: d.user_id,
        name: d.name,
        owed_balance: this.driverBalance(d.user_id),
      })),
    );
  }

  async getLedgerEntries(driverId: string): Promise<LedgerEntry[]> {
    await this.delay();
    const entries = this.ledger
      .filter((e) => e.driver_id === driverId)
      .sort((a, b) => new Date(b.created_at).getTime() - new Date(a.created_at).getTime());
    return clone(entries);
  }

  async settleLedger(driverId: string, body: SettleRequest): Promise<SettleResponse> {
    await this.delay();
    this.requireDriver(driverId);
    const entry = ledgerEntry(
      driverId,
      'payout',
      Math.abs(body.amount),
      0,
      null,
      body.note ?? null,
    );
    this.ledger = [entry, ...this.ledger];
    return clone(entry);
  }
}
