/**
 * Hand-written types mirroring the FastAPI backend contract.
 *
 * TODO(openapi): this file gets REPLACED by `npm run client:generate`
 * (openapi-typescript against the backend's /openapi.json) once the spec
 * stabilizes (WEB-1 acceptance). Keep field names snake_case to match the
 * backend JSON exactly so the swap is mechanical.
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
   * completion, which this web client doesn't build a gate for yet
   * (see the WEB-1 note in docs/tasks/10-web-client.md). */
  name: string | null;
  phone: string | null;
  email: string | null;
  fcm_token: string | null;
  created_at: string;
}
