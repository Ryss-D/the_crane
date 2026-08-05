import type {
  ConfigKey,
  ConfigResponse,
  Driver,
  DriverFilters,
  DriverLedgerSummary,
  JobDetail,
  JobFilters,
  LedgerEntry,
  PlatformConfig,
  SettleRequest,
  SettleResponse,
} from './types';

/**
 * The seam every UI component talks through. Two implementations:
 * - MockApi (src/api/mock.ts) — seeded in-memory data, default in dev.
 * - HttpApi (below) — real fetch calls against the FastAPI backend's
 *   /v1/admin/* router (ADM-2, built concurrently — endpoint shapes here
 *   follow docs/PLAN.md §2.6 but are not yet confirmed against the live API).
 */
export interface CraneAdminApi {
  getConfig(): Promise<ConfigResponse>;
  updateConfig<K extends ConfigKey>(key: K, value: PlatformConfig[K]): Promise<ConfigResponse>;

  getDrivers(filters?: DriverFilters): Promise<Driver[]>;
  verifyDriver(id: string): Promise<Driver>;
  blockDriver(id: string): Promise<Driver>;
  unblockDriver(id: string): Promise<Driver>;

  getJobs(filters?: JobFilters): Promise<JobDetail[]>;
  getJob(id: string): Promise<JobDetail>;
  cancelJob(id: string, reason?: string): Promise<JobDetail>;

  getLedger(): Promise<DriverLedgerSummary[]>;
  /**
   * NOTE: the documented contract only lists GET /v1/admin/ledger (balances).
   * Per-driver entry drill-down isn't spelled out — HttpApi assumes
   * ?driver_id= on the same endpoint until the real shape is confirmed.
   */
  getLedgerEntries(driverId: string): Promise<LedgerEntry[]>;
  settleLedger(driverId: string, body: SettleRequest): Promise<SettleResponse>;
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

export class HttpApi implements CraneAdminApi {
  constructor(
    private readonly baseUrl: string,
    private readonly getToken: GetToken,
  ) {}

  private async request<T>(
    method: 'GET' | 'POST' | 'PUT',
    path: string,
    opts: { body?: unknown; query?: Record<string, string | undefined> } = {},
  ): Promise<T> {
    const { body, query } = opts;
    const headers: Record<string, string> = { 'Content-Type': 'application/json' };
    const token = await this.getToken();
    if (token) headers['Authorization'] = `Bearer ${token}`;

    const qs = query
      ? Object.entries(query)
          .filter((e): e is [string, string] => e[1] !== undefined)
          .map(([k, v]) => `${encodeURIComponent(k)}=${encodeURIComponent(v)}`)
          .join('&')
      : '';

    const res = await fetch(`${this.baseUrl}${path}${qs ? `?${qs}` : ''}`, {
      method,
      headers,
      body: body === undefined ? null : JSON.stringify(body),
    });
    if (!res.ok) {
      throw new ApiError(res.status, `${method} ${path} failed with ${res.status}`);
    }
    return (await res.json()) as T;
  }

  getConfig(): Promise<ConfigResponse> {
    return this.request('GET', '/v1/admin/config');
  }

  updateConfig<K extends ConfigKey>(key: K, value: PlatformConfig[K]): Promise<ConfigResponse> {
    return this.request('PUT', `/v1/admin/config/${encodeURIComponent(key)}`, { body: value });
  }

  getDrivers(filters: DriverFilters = {}): Promise<Driver[]> {
    return this.request('GET', '/v1/admin/drivers', {
      query: {
        verified: filters.verified === undefined ? undefined : String(filters.verified),
        status: filters.status,
      },
    });
  }

  verifyDriver(id: string): Promise<Driver> {
    return this.request('POST', `/v1/admin/drivers/${encodeURIComponent(id)}/verify`);
  }

  blockDriver(id: string): Promise<Driver> {
    return this.request('POST', `/v1/admin/drivers/${encodeURIComponent(id)}/block`);
  }

  unblockDriver(id: string): Promise<Driver> {
    return this.request('POST', `/v1/admin/drivers/${encodeURIComponent(id)}/unblock`);
  }

  getJobs(filters: JobFilters = {}): Promise<JobDetail[]> {
    return this.request('GET', '/v1/admin/jobs', { query: { status: filters.status } });
  }

  getJob(id: string): Promise<JobDetail> {
    return this.request('GET', `/v1/admin/jobs/${encodeURIComponent(id)}`);
  }

  cancelJob(id: string, reason?: string): Promise<JobDetail> {
    return this.request('POST', `/v1/admin/jobs/${encodeURIComponent(id)}/cancel`, {
      body: { reason },
    });
  }

  getLedger(): Promise<DriverLedgerSummary[]> {
    return this.request('GET', '/v1/admin/ledger');
  }

  getLedgerEntries(driverId: string): Promise<LedgerEntry[]> {
    return this.request('GET', '/v1/admin/ledger', { query: { driver_id: driverId } });
  }

  settleLedger(driverId: string, body: SettleRequest): Promise<SettleResponse> {
    return this.request('POST', `/v1/admin/ledger/${encodeURIComponent(driverId)}/settle`, {
      body,
    });
  }
}
