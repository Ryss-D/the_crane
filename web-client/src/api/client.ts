import type {
  CreateJobRequest,
  Job,
  PaymentMethod,
  Quote,
  QuoteRequest,
  TrackInfo,
  UserProfile,
} from './types';

/**
 * The seam every UI component talks through. Two implementations:
 * - MockApi (src/api/mock.ts) — seeded in-memory data, default in dev.
 * - HttpApi (below) — real fetch calls against the FastAPI backend.
 */
export interface CraneApi {
  quote(req: QuoteRequest): Promise<Quote>;
  createJob(req: CreateJobRequest): Promise<Job>;
  getJob(id: string): Promise<Job>;
  /** POST /v1/jobs/{id}/confirm-delivery (CUS-5/LED-1, PAY-4) — customer
   * confirms delivery; only valid from `delivered`, moves the job to
   * `completed`. Omitting `paymentMethod` (or passing `'cash'`) is the
   * original cash-only path, sent with no request body at all. A non-cash
   * method 422s if `payments.digital_fares_enabled` is off server-side —
   * there's no way to know that ahead of time from this client. */
  confirmDelivery(id: string, paymentMethod?: PaymentMethod): Promise<Job>;
  /** POST /v1/jobs/{id}/rating (RAT-1) — rate the other side of a completed
   * job; `to_user_id` is inferred server-side, never sent. */
  submitRating(jobId: string, stars: number, comment?: string): Promise<void>;
  /** Public share-track endpoint — no auth. */
  getTrack(token: string): Promise<TrackInfo>;
  /** POST /v1/auth/sync (AUTH-2) — idempotent create-or-fetch of the backend
   * `users` row for the signed-in Firebase account; `name`/`phone` fall back
   * to token claims server-side when omitted. Called once per sign-in by
   * AuthProvider (src/auth/AuthProvider.tsx) — without it, every other
   * authenticated call 404s on a fresh account (get_current_user has no row
   * to resolve until this has run at least once). */
  syncAuth(body?: { name?: string; phone?: string }): Promise<UserProfile>;
  /** PATCH /v1/me — profile completion (mirrors the Flutter app's AUTH-3
   * `CompleteProfileScreen`/`AuthCubit.completeProfile`): a fresh phone-OTP
   * account has no `name` until this is called once. Only provided fields
   * are updated server-side. */
  updateMe(body: { name?: string; email?: string }): Promise<UserProfile>;
  /** GET /v1/places/geocode?lat=&lng= (CUS-1/CUS-4/WEB-2 follow-up) — a
   * human-readable address for a raw coordinate (a GPS fix or a dragged
   * map pin), proxying Google's classic Geocoding API (see the backend's
   * `app/services/places.py`) since a raw REST call from the browser can't
   * use this client's web-restricted Maps key the way the JS SDK can.
   * Returns null — never throws — if the backend has no server-side Google
   * Maps key configured yet, the caller isn't signed in yet (this endpoint
   * requires auth, same as the backend's autocomplete/details proxies), or
   * Google itself errors: callers fall back to the raw-coordinate text they
   * already show. */
  reverseGeocode(lat: number, lng: number): Promise<string | null>;
}

export class ApiError extends Error {
  constructor(
    public readonly status: number,
    message: string,
  ) {
    super(message);
    this.name = 'ApiError';
  }
}

type GetToken = () => Promise<string | null>;

export class HttpApi implements CraneApi {
  constructor(
    private readonly baseUrl: string,
    private readonly getToken: GetToken,
  ) {}

  private async request<T>(
    method: 'GET' | 'POST' | 'PATCH',
    path: string,
    opts: { body?: unknown; auth?: boolean } = {},
  ): Promise<T> {
    const { body, auth = true } = opts;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    if (auth) {
      const token = await this.getToken();
      if (token) headers['Authorization'] = `Bearer ${token}`;
    }
    const res = await fetch(`${this.baseUrl}${path}`, {
      method,
      headers,
      body: body === undefined ? null : JSON.stringify(body),
    });
    if (!res.ok) {
      throw new ApiError(res.status, `${method} ${path} failed with ${res.status}`);
    }
    return (await res.json()) as T;
  }

  quote(req: QuoteRequest): Promise<Quote> {
    return this.request('POST', '/v1/jobs/quote', { body: req });
  }

  createJob(req: CreateJobRequest): Promise<Job> {
    return this.request('POST', '/v1/jobs', { body: req });
  }

  getJob(id: string): Promise<Job> {
    return this.request('GET', `/v1/jobs/${encodeURIComponent(id)}`);
  }

  confirmDelivery(id: string, paymentMethod?: PaymentMethod): Promise<Job> {
    return this.request('POST', `/v1/jobs/${encodeURIComponent(id)}/confirm-delivery`, {
      body: paymentMethod ? { payment_method: paymentMethod } : undefined,
    });
  }

  async submitRating(jobId: string, stars: number, comment?: string): Promise<void> {
    await this.request('POST', `/v1/jobs/${encodeURIComponent(jobId)}/rating`, {
      body: { stars, comment },
    });
  }

  getTrack(token: string): Promise<TrackInfo> {
    return this.request('GET', `/v1/track/${encodeURIComponent(token)}`, { auth: false });
  }

  syncAuth(body?: { name?: string; phone?: string }): Promise<UserProfile> {
    return this.request('POST', '/v1/auth/sync', { body });
  }

  updateMe(body: { name?: string; email?: string }): Promise<UserProfile> {
    return this.request('PATCH', '/v1/me', { body });
  }

  reverseGeocode(lat: number, lng: number): Promise<string | null> {
    const params = new URLSearchParams({ lat: String(lat), lng: String(lng) });
    return this.request<{ address: string }>('GET', `/v1/places/geocode?${params}`)
      .then((res) => res.address)
      .catch(() => null);
  }
}
