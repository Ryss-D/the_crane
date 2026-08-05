import type { CreateJobRequest, Job, Quote, QuoteRequest, TrackInfo } from './types';

/**
 * The seam every UI component talks through. Two implementations:
 * - MockApi (src/api/mock.ts) — seeded in-memory data, default in dev.
 * - HttpApi (below) — real fetch calls against the FastAPI backend.
 */
export interface CraneApi {
  quote(req: QuoteRequest): Promise<Quote>;
  createJob(req: CreateJobRequest): Promise<Job>;
  getJob(id: string): Promise<Job>;
  /** Public share-track endpoint — no auth. */
  getTrack(token: string): Promise<TrackInfo>;
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
    method: 'GET' | 'POST',
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

  getTrack(token: string): Promise<TrackInfo> {
    return this.request('GET', `/v1/track/${encodeURIComponent(token)}`, { auth: false });
  }
}
