import type {
  AdminFleetListItem,
  ConfigKey,
  ConfigResponse,
  Driver,
  DriverFilters,
  DriverLedgerSummary,
  FleetBalanceRead,
  FleetSettleRequest,
  FleetSettleResponse,
  Job,
  JobDetail,
  JobFilters,
  LedgerEntry,
  PlatformConfig,
  SettleRequest,
  SettleResponse,
} from './types';

/** Every GET list endpoint's real envelope shape (app/schemas/*.py's
 * *ListResponse models) — HttpApi unwraps `.items`, callers keep working
 * with plain arrays since nothing here needs total/limit/offset yet. */
interface Paginated<T> {
  items: T[];
  total: number;
  limit: number;
  offset: number;
}

/**
 * The seam every UI component talks through. Two implementations:
 * - MockApi (src/api/mock.ts) — seeded in-memory data, default in dev.
 * - HttpApi (below) — real fetch calls against the FastAPI backend's
 *   /v1/admin/* router. Shapes verified against the backend's actual
 *   OpenAPI schema (dumped from the running app), not assumed.
 */
export interface CraneAdminApi {
  getConfig(): Promise<ConfigResponse>;
  updateConfig<K extends ConfigKey>(key: K, value: PlatformConfig[K]): Promise<ConfigResponse>;

  getDrivers(filters?: DriverFilters): Promise<Driver[]>;
  verifyDriver(id: string): Promise<Driver>;
  blockDriver(id: string): Promise<Driver>;
  unblockDriver(id: string): Promise<Driver>;

  /** GET /v1/admin/jobs — list items have names but no offer trail (that's
   * the single-job detail endpoint below); typed as `Job[]`, not
   * `JobDetail[]`, so reading `.offers` on a row is a type error, not a
   * silent `undefined`. */
  getJobs(filters?: JobFilters): Promise<Job[]>;
  getJob(id: string): Promise<JobDetail>;
  /** Returns the plain job (no offer trail/names) — the admin cancel endpoint
   * doesn't re-send those; callers should invalidate ['job', id] to refetch
   * full detail rather than cache this directly. */
  cancelJob(id: string, reason?: string): Promise<Job>;

  getLedger(): Promise<DriverLedgerSummary[]>;
  getLedgerEntries(driverId: string): Promise<LedgerEntry[]>;
  settleLedger(driverId: string, body: SettleRequest): Promise<SettleResponse>;

  /** GET /v1/admin/fleets — a plain list, no pagination envelope (unlike
   * drivers/jobs/ledger): fleets are expected to stay few for MVP scale. */
  getFleets(): Promise<AdminFleetListItem[]>;
  getFleetBalance(fleetId: string): Promise<FleetBalanceRead>;
  settleFleet(fleetId: string, body: FleetSettleRequest): Promise<FleetSettleResponse>;
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

  async getDrivers(filters: DriverFilters = {}): Promise<Driver[]> {
    const page = await this.request<Paginated<Driver>>('GET', '/v1/admin/drivers', {
      query: {
        verified: filters.verified === undefined ? undefined : String(filters.verified),
        status: filters.status,
      },
    });
    return page.items;
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

  async getJobs(filters: JobFilters = {}): Promise<Job[]> {
    const page = await this.request<Paginated<Job>>('GET', '/v1/admin/jobs', {
      query: { status: filters.status },
    });
    return page.items;
  }

  getJob(id: string): Promise<JobDetail> {
    return this.request('GET', `/v1/admin/jobs/${encodeURIComponent(id)}`);
  }

  cancelJob(id: string, reason?: string): Promise<Job> {
    return this.request('POST', `/v1/admin/jobs/${encodeURIComponent(id)}/cancel`, {
      body: { reason },
    });
  }

  async getLedger(): Promise<DriverLedgerSummary[]> {
    const page = await this.request<Paginated<DriverLedgerSummary>>('GET', '/v1/admin/ledger');
    return page.items;
  }

  async getLedgerEntries(driverId: string): Promise<LedgerEntry[]> {
    const page = await this.request<Paginated<LedgerEntry>>(
      'GET',
      `/v1/admin/ledger/${encodeURIComponent(driverId)}/entries`,
    );
    return page.items;
  }

  settleLedger(driverId: string, body: SettleRequest): Promise<SettleResponse> {
    return this.request('POST', `/v1/admin/ledger/${encodeURIComponent(driverId)}/settle`, {
      body,
    });
  }

  getFleets(): Promise<AdminFleetListItem[]> {
    return this.request('GET', '/v1/admin/fleets');
  }

  getFleetBalance(fleetId: string): Promise<FleetBalanceRead> {
    return this.request('GET', `/v1/admin/fleets/${encodeURIComponent(fleetId)}/balance`);
  }

  settleFleet(fleetId: string, body: FleetSettleRequest): Promise<FleetSettleResponse> {
    return this.request('POST', `/v1/admin/fleets/${encodeURIComponent(fleetId)}/settle`, {
      body,
    });
  }
}
