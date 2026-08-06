/**
 * Hand-written types mirroring the FastAPI backend's admin contract
 * (docs/PLAN.md §2.2 platform_config, §2.6 admin API surface).
 *
 * TODO(openapi): this file gets REPLACED by `npm run client:generate`
 * (openapi-typescript against the backend's /openapi.json) once the admin
 * router (ADM-2) lands and its spec stabilizes. Keep field names snake_case
 * to match the backend JSON exactly so the swap is mechanical. The admin
 * router is being built concurrently by another agent — treat exact response
 * envelopes (pagination, wrapper keys) as likely-but-not-guaranteed; the
 * shapes below are this app's best-effort mirror of docs/PLAN.md §2.6.
 */

export const VEHICLE_TYPES = ['moto', 'car', 'suv'] as const;
export type VehicleType = (typeof VEHICLE_TYPES)[number];

// ---------------------------------------------------------------------------
// Platform config (ADM-3) — docs/PLAN.md §2.2 `platform_config` + §2.5 pricing
// ---------------------------------------------------------------------------

export interface VehiclePricing {
  /** COP, integer pesos. */
  base_fare: number;
  /** COP per km, integer pesos. */
  per_km: number;
  /** COP, integer pesos — floor applied after base + per_km. */
  min_fare: number;
}

export type PricingConfig = Record<VehicleType, VehiclePricing>;

export type CommissionMode = 'percent' | 'flat';

export interface CommissionConfig {
  mode: CommissionMode;
  /** Per vehicle type. `percent` mode: 0–1 fraction. `flat` mode: COP pesos. */
  rate: Record<VehicleType, number>;
}

export type SettlementPeriod = 'weekly' | 'biweekly' | 'monthly';

export interface SettlementConfig {
  /** COP a driver can owe before new offers are blocked. null = never block. */
  balance_cap: number | null;
  settlement_period: SettlementPeriod;
}

export interface DispatchConfig {
  offer_ttl_seconds: number;
  search_radius_km: number;
  /** Radius (km) tried in order after the initial search comes up empty. */
  radius_widening_steps_km: number[];
}

export interface PlatformConfig {
  pricing: PricingConfig;
  commission: CommissionConfig;
  settlement: SettlementConfig;
  dispatch: DispatchConfig;
}

export const CONFIG_KEYS = ['pricing', 'commission', 'settlement', 'dispatch'] as const;
export type ConfigKey = (typeof CONFIG_KEYS)[number];

/** Per-key audit trail entry (docs/PLAN.md §2.2: "each change stores changed_by + previous value"). */
export interface ConfigAuditEntry {
  id: string;
  key: ConfigKey;
  changed_by: string;
  changed_at: string;
  previous_value: unknown;
  new_value: unknown;
}

export interface ConfigResponse {
  config: PlatformConfig;
  /** Newest first, all keys interleaved; UI filters per key. */
  history: ConfigAuditEntry[];
}

// ---------------------------------------------------------------------------
// Drivers (ADM-4)
// ---------------------------------------------------------------------------

export const DRIVER_STATUSES = ['offline', 'available', 'on_job', 'blocked'] as const;
export type DriverStatus = (typeof DRIVER_STATUSES)[number];

export const TRUCK_TYPES = ['moto_only', 'flatbed', 'car'] as const;
export type TruckType = (typeof TRUCK_TYPES)[number];

export const TRUCK_CAPACITIES = ['moto', 'car', 'both'] as const;
export type TruckCapacity = (typeof TRUCK_CAPACITIES)[number];

/** Matches the backend's TruckRead exactly (app/schemas/driver.py). */
export interface Truck {
  id: string;
  plate: string;
  type: TruckType;
  capacity: TruckCapacity;
  driver_id: string | null;
  fleet_id: string | null;
}

/**
 * Matches AdminDriverRead exactly (app/schemas/admin.py) — no `id`/`blocked`/
 * `created_at`/`documents` fields exist on the backend: the primary key is
 * `user_id`, "blocked" is `status === 'blocked'`, and there's no document
 * upload system yet — only the two URL fields a driver submits at
 * registration (AUTH-5), null until they do.
 */
export interface Driver {
  user_id: string;
  name: string | null;
  phone: string | null;
  email: string | null;
  status: DriverStatus;
  verified: boolean;
  rating_avg: number | null;
  truck: Truck | null;
  /** COP owed to the platform (commission accrual). Positive = owes platform. */
  owed_balance: number;
  license_url: string | null;
  truck_photo_url: string | null;
}

export interface DriverFilters {
  verified?: boolean;
  status?: DriverStatus;
}

// ---------------------------------------------------------------------------
// Jobs / operations (ADM-5)
// ---------------------------------------------------------------------------

export const JOB_STATUSES = [
  'requested',
  'matching',
  'assigned',
  'en_route_pickup',
  'arrived_pickup',
  'loading',
  'in_transit',
  'delivered',
  'completed',
  'cancelled',
  'no_drivers',
] as const;

export type JobStatus = (typeof JOB_STATUSES)[number];

export const TERMINAL_JOB_STATUSES: readonly JobStatus[] = ['completed', 'cancelled', 'no_drivers'];

export const OFFER_RESPONSES = ['pending', 'accepted', 'rejected', 'timeout'] as const;
export type OfferResponse = (typeof OFFER_RESPONSES)[number];

/** One row of the job_offers audit trail (docs/PLAN.md §2.2). */
export interface JobOffer {
  id: string;
  driver_id: string;
  driver_name: string | null;
  offered_at: string;
  responded_at: string | null;
  response: OfferResponse;
}

export interface Job {
  id: string;
  status: JobStatus;
  customer_name: string;
  customer_phone: string;
  driver_id: string | null;
  driver_name: string | null;
  vehicle_type: VehicleType;
  pickup_address: string;
  dropoff_address: string;
  distance_km: number;
  /** COP, integer pesos. */
  quoted_price: number;
  final_price: number | null;
  requested_at: string;
  assigned_at: string | null;
  completed_at: string | null;
  cancelled_at: string | null;
  cancel_reason: string | null;
}

/** GET /v1/admin/jobs/{id} — job plus its full offer trail. */
export interface JobDetail extends Job {
  offers: JobOffer[];
}

export interface JobFilters {
  status?: JobStatus;
}

// ---------------------------------------------------------------------------
// Ledger & settlements (ADM-6)
// ---------------------------------------------------------------------------

/** Matches DriverLedgerEntry's real enum exactly — "payout", not "settlement". */
export type LedgerEntryType = 'earning' | 'payout' | 'adjustment';

/**
 * Matches DriverLedgerEntryRead exactly (app/schemas/admin.py): gross/
 * commission/net, not a single signed `amount` — and the field is
 * `entry_type`, not `type`.
 */
export interface LedgerEntry {
  id: string;
  driver_id: string;
  job_id: string | null;
  gross: number;
  commission: number;
  net: number;
  entry_type: LedgerEntryType;
  note: string | null;
  created_at: string;
}

/**
 * One row of GET /v1/admin/ledger — matches AdminLedgerRead exactly.
 * No balance_cap here (that's a single global value from platform_config,
 * not per-driver) — LedgerPage reads it from the already-fetched config
 * instead of expecting the backend to duplicate it onto every row.
 */
export interface DriverLedgerSummary {
  driver_id: string;
  name: string | null;
  owed_balance: number;
}

export interface SettleRequest {
  /** COP amount being recorded as settled (reduces the balance). */
  amount: number;
  note?: string;
}

/** POST /v1/admin/ledger/{id}/settle returns the created entry directly —
 * no wrapper, no fresh balance (refetch ['ledger'] for that). */
export type SettleResponse = LedgerEntry;

// ---------------------------------------------------------------------------
// Fleets & owners (ADM-7) — matches app/schemas/fleet.py exactly
// ---------------------------------------------------------------------------

/** GET /v1/admin/fleets row — matches AdminFleetListItem exactly. Amounts are
 * COP, integer pesos, same convention as LedgerEntry/DriverLedgerSummary. */
export interface AdminFleetListItem {
  id: string;
  owner_user_id: string;
  owner_name: string | null;
  name: string;
  truck_count: number;
  owed_balance: number;
  created_at: string;
}

/** One member driver's contribution to a fleet's consolidated balance —
 * matches FleetMemberBalance exactly. */
export interface FleetMemberBalance {
  driver_id: string;
  name: string | null;
  owed_balance: number;
}

/** GET /v1/admin/fleets/{id}/balance — matches FleetBalanceRead exactly.
 * `owed_balance` is the consolidated total; always equals the sum of
 * `members[].owed_balance` (ADM-7 AC). */
export interface FleetBalanceRead {
  fleet_id: string;
  owed_balance: number;
  members: FleetMemberBalance[];
}

export interface FleetSettleRequest {
  /** COP amount being recorded as settled for the whole fleet, apportioned
   * across member drivers proportional to their current owed balance. */
  amount: number;
  note?: string;
}

/** One driver's apportioned share of a fleet settlement — matches
 * FleetSettlementEntry exactly. */
export interface FleetSettlementEntry {
  driver_id: string;
  ledger_entry_id: string;
  amount: number;
}

/** POST /v1/admin/fleets/{id}/settle response — matches FleetSettleResponse
 * exactly: the total plus the apportionment breakdown, shown as confirmation. */
export interface FleetSettleResponse {
  fleet_id: string;
  total_amount: number;
  entries: FleetSettlementEntry[];
}
