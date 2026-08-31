import type { CreateJobRequest, Job, Quote, QuoteRequest, TrackInfo, UserProfile } from './types';

/**
 * The seam every UI component talks through. Two implementations:
 * - MockApi (src/api/mock.ts) — seeded in-memory data, default in dev.
 * - HttpApi (below) — real fetch calls against the FastAPI backend.
 */
export interface CraneApi {
  quote(req: QuoteRequest): Promise<Quote>;
  createJob(req: CreateJobRequest): Promise<Job>;
  getJob(id: string): Promise<Job>;
  /** POST /v1/jobs/{id}/confirm-delivery (CUS-5/LED-1) — customer confirms
   * cash payment; only valid from `delivered`, moves the job to `completed`. */
  confirmDelivery(id: string): Promise<Job>;
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

  confirmDelivery(id: string): Promise<Job> {
    return this.request('POST', `/v1/jobs/${encodeURIComponent(id)}/confirm-delivery`);
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
}
