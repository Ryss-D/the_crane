import type { CraneApi } from './client';
import { ApiError } from './client';
import type {
  CreateJobRequest,
  Driver,
  Job,
  JobStatus,
  Quote,
  QuoteRequest,
  TrackInfo,
  VehicleType,
} from './types';

/** Seconds after creation at which a mock job reaches each status. */
const PROGRESSION: ReadonlyArray<readonly [JobStatus, number]> = [
  ['requested', 0],
  ['matching', 3],
  ['assigned', 10],
  ['en_route_pickup', 18],
  ['arrived_pickup', 40],
  ['loading', 50],
  ['in_transit', 60],
  ['delivered', 90],
  ['completed', 100],
];

const BASE_FARE: Record<VehicleType, number> = { moto: 35000, car: 60000, suv: 80000 };
const PER_KM: Record<VehicleType, number> = { moto: 2500, car: 4000, suv: 5000 };

const MOCK_DRIVER: Driver = {
  id: 'drv_1',
  name: 'Carlos Restrepo',
  rating: 4.8,
  plate: 'TKX-482',
  truck_description: 'Grúa plataforma — Chevrolet NPR blanca',
};

/** Deterministic tiny hash so the same addresses always quote the same trip. */
function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
  return h;
}

interface MockJobRecord {
  job: Job;
  createdAtMs: number;
  /** When set, the job never progresses (used for the seeded demo job). */
  frozenStatus?: JobStatus;
}

/**
 * In-memory fake of the backend. Seeded with a demo job so the tracking pages
 * can be opened directly:
 *   /jobs/demo  and  /t/demo-token
 * Jobs created through createJob() progress through the status machine on a
 * timer (see PROGRESSION) so polling visibly advances the timeline.
 */
export class MockApi implements CraneApi {
  private readonly jobs = new Map<string, MockJobRecord>();
  private readonly quotes = new Map<string, Quote>();
  private seq = 0;

  constructor(private readonly latencyMs: number = 450) {
    this.seedDemoJob();
  }

  private delay(): Promise<void> {
    if (this.latencyMs <= 0) return Promise.resolve();
    return new Promise((r) => setTimeout(r, this.latencyMs));
  }

  private seedDemoJob(): void {
    const job: Job = {
      id: 'demo',
      status: 'en_route_pickup',
      vehicle_type: 'car',
      pickup_address: 'Cra. 43A #1-50, El Poblado, Medellín',
      dropoff_address: 'Cl. 10 #52-25, Guayabal, Medellín',
      price: 92000,
      eta_minutes: 12,
      distance_km: 8,
      driver: MOCK_DRIVER,
      share_token: 'demo-token',
      created_at: new Date().toISOString(),
    };
    this.jobs.set(job.id, {
      job,
      createdAtMs: Date.now(),
      frozenStatus: 'en_route_pickup',
    });
  }

  private computeStatus(rec: MockJobRecord): JobStatus {
    if (rec.frozenStatus) return rec.frozenStatus;
    const elapsedS = (Date.now() - rec.createdAtMs) / 1000;
    let status: JobStatus = 'requested';
    for (const [s, at] of PROGRESSION) {
      if (elapsedS >= at) status = s;
    }
    return status;
  }

  private materialize(rec: MockJobRecord): Job {
    const status = this.computeStatus(rec);
    const assigned = PROGRESSION.findIndex(([s]) => s === status) >= 2; // assigned+
    return {
      ...rec.job,
      status,
      driver: assigned ? MOCK_DRIVER : null,
      eta_minutes: status === 'completed' || status === 'delivered' ? 0 : rec.job.eta_minutes,
    };
  }

  async quote(req: QuoteRequest): Promise<Quote> {
    await this.delay();
    const h = hash(`${req.pickup_address}|${req.dropoff_address}`);
    const distanceKm = Math.round((3 + (h % 120) / 10) * 10) / 10; // 3.0–14.9 km
    const price =
      Math.round((BASE_FARE[req.vehicle_type] + distanceKm * PER_KM[req.vehicle_type]) / 100) * 100;
    const quote: Quote = {
      quote_id: `q_${++this.seq}_${h.toString(16)}`,
      price,
      eta_minutes: 8 + (h % 10),
      distance_km: distanceKm,
    };
    this.quotes.set(quote.quote_id, quote);
    return quote;
  }

  async createJob(req: CreateJobRequest): Promise<Job> {
    await this.delay();
    const quote = this.quotes.get(req.quote_id);
    if (!quote) throw new ApiError(404, 'quote not found or expired');
    const id = `job_${++this.seq}`;
    const job: Job = {
      id,
      status: 'requested',
      vehicle_type: req.vehicle_type,
      pickup_address: req.pickup_address,
      dropoff_address: req.dropoff_address,
      price: quote.price,
      eta_minutes: quote.eta_minutes,
      distance_km: quote.distance_km,
      driver: null,
      share_token: `tok_${id}`,
      created_at: new Date().toISOString(),
    };
    this.jobs.set(id, { job, createdAtMs: Date.now() });
    return job;
  }

  async getJob(id: string): Promise<Job> {
    await this.delay();
    const rec = this.jobs.get(id);
    if (!rec) throw new ApiError(404, `job ${id} not found`);
    return this.materialize(rec);
  }

  async getTrack(token: string): Promise<TrackInfo> {
    await this.delay();
    const rec = [...this.jobs.values()].find((r) => r.job.share_token === token);
    if (!rec) throw new ApiError(404, 'invalid track token');
    const job = this.materialize(rec);
    return {
      status: job.status,
      vehicle_type: job.vehicle_type,
      eta_minutes: job.eta_minutes,
      driver_name: job.driver ? (job.driver.name.split(' ')[0] ?? null) : null,
      driver_position: job.driver ? { lat: 6.2088, lng: -75.5736 } : null,
      updated_at: new Date().toISOString(),
    };
  }
}
