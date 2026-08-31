/**
 * Hand-written types mirroring the FastAPI backend contract.
 *
 * TODO(openapi): this file is a candidate to be REPLACED by the generated
 * `src/api/generated.ts` (openapi-typescript against the backend's
 * /openapi.json snapshot, `npm run client:generate`/`client:check` — see
 * src/api/README.md). WEB-1 shipped the generator + a CI drift check but
 * deliberately did NOT do the full swap yet (bigger, riskier change than
 * fit alongside that session's other work — see the README for the full
 * rationale). Keep field names snake_case to match the backend JSON
 * exactly so the eventual swap stays mechanical.
 */

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

/** The "happy path" progression rendered by the status timeline. */
export const TIMELINE_STATUSES = JOB_STATUSES.filter(
  (s) => s !== 'cancelled' && s !== 'no_drivers',
) as readonly JobStatus[];

export const TERMINAL_STATUSES: readonly JobStatus[] = ['completed', 'cancelled', 'no_drivers'];

export const VEHICLE_TYPES = ['moto', 'car', 'suv'] as const;
export type VehicleType = (typeof VEHICLE_TYPES)[number];

/**
 * PAY-4: how a customer pays at `confirm-delivery`. Matches the backend's
 * `PaymentMethod` enum (`app/models/job.py`) except this client never offers
 * `wallet` — same subset the Flutter app's checkout dialog exposes, per that
 * task's UI (`docs/tasks/12-payments-wompi.md`). Omitting `payment_method`
 * entirely (or passing `'cash'`) is the pre-existing cash-only path.
 */
export const PAYMENT_METHODS = ['cash', 'nequi', 'pse', 'card'] as const;
export type PaymentMethod = (typeof PAYMENT_METHODS)[number];

export const TRUCK_TYPES = ['moto_only', 'car', 'flatbed'] as const;
export type TruckType = (typeof TRUCK_TYPES)[number];

export interface LatLng {
  lat: number;
  lng: number;
}

export interface QuoteRequest {
  vehicle_type: VehicleType;
  /** TODO(FND-6): filled from browser geolocation / Places once Maps is
   * wired — `fakeGeocode` (src/api/geocode.ts) stands in until then. */
  pickup: LatLng;
  dropoff: LatLng;
}

/** A point plus its human-readable address (job creation) — matches the
 * backend's `LocationIn` exactly. */
export interface LocationIn extends LatLng {
  address: string;
}

export interface Quote {
  quote_id: string;
  /** COP, integer pesos. */
  price: number;
  eta_minutes: number;
  distance_km: number;
}

export interface CreateJobRequest {
  quote_id: string;
  vehicle_type: VehicleType;
  pickup: LocationIn;
  dropoff: LocationIn;
  customer_vehicle_id?: string;
}

/** Matches the backend's `JobDriverInfo` (app/schemas/job.py) exactly —
 * also the same shape the Flutter app's `JobDriverSummary` uses. */
export interface Driver {
  id: string;
  name: string | null;
  phone: string | null;
  truck_plate: string;
  truck_type: TruckType;
  rating_avg: number | null;
  photo_url: string | null;
}

export interface Job {
  id: string;
  status: JobStatus;
  vehicle_type: VehicleType;
  /** FND-6 follow-up: the real `JobRead` (`backend/app/schemas/job.py`) has
   * always returned these — this hand-written type just never declared
   * them until the tracking map needed real pickup/dropoff pins. */
  pickup_lat: number;
  pickup_lng: number;
  dropoff_lat: number;
  dropoff_lng: number;
  pickup_address: string;
  dropoff_address: string;
  /** COP, integer pesos — the fare locked in from the quote at creation. */
  quoted_price: number;
  /** COP; null until `completed` (no surge in MVP, so it always settles == quoted_price). */
  final_price: number | null;
  distance_km: number;
  driver: Driver | null;
  /** Token for the public share-track page (/t/{token}). */
  share_token: string;
  created_at: string;
  /** PAY-4: non-null only on the exact `confirm-delivery` response that just
   * started a real Wompi checkout for PSE/card — never for cash, never for
   * Nequi (no redirect step there, the app just says "check your Nequi
   * app"), and never on a later re-fetch of the same job. Matches the
   * backend's `JobRead.async_payment_url` exactly (see PAY-4's note in
   * `docs/tasks/12-payments-wompi.md` about the transient
   * `job.pending_payment_url` attribute it's read from server-side). */
  async_payment_url: string | null;
}

/**
 * Public, token-scoped view (GET /v1/track/{token}) — matches the backend's
 * TrackResponse/TrackDriver schemas (app/schemas/job.py) exactly: no PII
 * beyond the driver's first name and truck plate, no ETA (the backend
 * doesn't compute one for this endpoint).
 */
export interface TrackDriverInfo {
  first_name: string | null;
  truck_plate: string | null;
}

export interface TrackInfo {
  status: JobStatus;
  pickup: LatLng;
  dropoff: LatLng;
  driver: TrackDriverInfo | null;
  driver_location: LatLng | null;
}

export const USER_ROLES = ['customer', 'driver', 'admin', 'fleet_owner'] as const;
export type UserRole = (typeof USER_ROLES)[number];

/**
 * Matches the backend's `UserRead` (app/schemas/user.py) exactly — the shape
 * returned by both `POST /v1/auth/sync` (AUTH-2) and `GET /v1/me`.
 */
export interface UserProfile {
  id: string;
  firebase_uid: string;
  role: UserRole;
  /** Firebase phone-OTP never provides a name — null until profile
   * completion (`AuthProvider`'s gate on `RequestPage`, mirroring the
   * Flutter app's `AuthPhase.needsProfile`/`CompleteProfileScreen`). */
  name: string | null;
  phone: string | null;
  email: string | null;
  fcm_token: string | null;
  created_at: string;
}
