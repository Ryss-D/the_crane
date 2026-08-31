import type { CraneApi } from './client';
import { ApiError } from './client';
import { hash } from './geocode';
import type {
  CreateJobRequest,
  Driver,
  Job,
  JobStatus,
  Quote,
  QuoteRequest,
  TrackInfo,
  UserProfile,
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
  phone: '+573001112233',
  truck_plate: 'TKX-482',
  truck_type: 'flatbed',
  rating_avg: 4.8,
  photo_url: null,
};

interface MockJobRecord {
  job: Job;
  createdAtMs: number;
  /** When set, the job never progresses past this (used for the seeded demo
   * jobs, and by confirmDelivery() to freeze a real job at `completed`). */
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
  /** Set on the first syncAuth() call, mirroring the backend's
   * create-or-fetch: subsequent calls return the same row regardless of the
   * body passed in (FakeAuth only ever has one signed-in identity at a
   * time). */
  private userProfile: UserProfile | null = null;

  constructor(private readonly latencyMs: number = 450) {
    this.seedDemoJob();
  }

  /**
   * Test-only: clears the synced profile so the next `syncAuth()` starts
   * fresh (a real `name: null` account) instead of returning whatever an
   * earlier test's `updateMe()` left behind. `MockApi` is a module-level
   * singleton (`src/api/index.ts`) shared by every test in a file — without
   * this, the WEB-1 profile-completion gate only shows once per file (the
   * first test to complete it "sticks" for every test after). Not part of
   * the `CraneApi` interface on purpose; called from `src/test/setup.tsx`
   * only, guarded by an `instanceof MockApi` check.
   */
  resetForTests(): void {
    this.userProfile = null;
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
      pickup_lat: 6.2088,
      pickup_lng: -75.5679,
      dropoff_lat: 6.2273,
      dropoff_lng: -75.5843,
      pickup_address: 'Cra. 43A #1-50, El Poblado, Medellín',
      dropoff_address: 'Cl. 10 #52-25, Guayabal, Medellín',
      quoted_price: 92000,
      final_price: null,
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

    // Second fixed demo job, frozen at `delivered` so the cash-confirmation
    // flow (WEB-3/CUS-5) is reachable without waiting on real elapsed time.
    const deliveredJob: Job = {
      ...job,
      id: 'demo-delivered',
      status: 'delivered',
      share_token: 'demo-delivered-token',
    };
    this.jobs.set(deliveredJob.id, {
      job: deliveredJob,
      createdAtMs: Date.now(),
      frozenStatus: 'delivered',
    });
  }

  private computeStatus(rec: MockJobRecord): JobStatus {
    if (rec.frozenStatus) return rec.frozenStatus;
    const elapsedS = (Date.now() - rec.createdAtMs) / 1000;
    let status: JobStatus = 'requested';
    for (const [s, at] of PROGRESSION) {
      if (elapsedS >= at) status = s;
    }
    // Time alone never reaches `completed` — only confirmDelivery() does
    // (mirrors the backend restricting completion to the customer).
    return status === 'completed' ? 'delivered' : status;
  }

  private materialize(rec: MockJobRecord): Job {
    const status = this.computeStatus(rec);
    const assigned = PROGRESSION.findIndex(([s]) => s === status) >= 2; // assigned+
    return {
      ...rec.job,
      status,
      driver: assigned ? MOCK_DRIVER : null,
      // Mirrors confirm_delivery: final_price settles to quoted_price on completion.
      final_price: status === 'completed' ? rec.job.quoted_price : rec.job.final_price,
    };
  }

  async quote(req: QuoteRequest): Promise<Quote> {
    await this.delay();
    const h = hash(`${req.pickup.lat},${req.pickup.lng}|${req.dropoff.lat},${req.dropoff.lng}`);
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
      pickup_lat: req.pickup.lat,
      pickup_lng: req.pickup.lng,
      dropoff_lat: req.dropoff.lat,
      dropoff_lng: req.dropoff.lng,
      pickup_address: req.pickup.address,
      dropoff_address: req.dropoff.address,
      quoted_price: quote.price,
      final_price: null,
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

  async confirmDelivery(id: string): Promise<Job> {
    await this.delay();
    const rec = this.jobs.get(id);
    if (!rec) throw new ApiError(404, `job ${id} not found`);
    if (this.computeStatus(rec) !== 'delivered') {
      throw new ApiError(409, 'Delivery can only be confirmed once the job is delivered');
    }
    rec.frozenStatus = 'completed';
    return this.materialize(rec);
  }

  async submitRating(jobId: string, _stars: number, _comment?: string): Promise<void> {
    await this.delay();
    if (!this.jobs.has(jobId)) throw new ApiError(404, `job ${jobId} not found`);
    // Nothing further to simulate — RatingStub already shows its own
    // "thanks" state client-side once this resolves.
  }

  async getTrack(token: string): Promise<TrackInfo> {
    await this.delay();
    const rec = [...this.jobs.values()].find((r) => r.job.share_token === token);
    if (!rec) throw new ApiError(404, 'invalid track token');
    const job = this.materialize(rec);
    return {
      status: job.status,
      pickup: { lat: job.pickup_lat, lng: job.pickup_lng },
      dropoff: { lat: job.dropoff_lat, lng: job.dropoff_lng },
      driver: job.driver
        ? {
            first_name: job.driver.name?.split(' ')[0] ?? null,
            truck_plate: job.driver.truck_plate,
          }
        : null,
      driver_location: job.driver ? { lat: 6.2088, lng: -75.5736 } : null,
    };
  }

  async syncAuth(body?: { name?: string; phone?: string }): Promise<UserProfile> {
    await this.delay();
    if (!this.userProfile) {
      // Mirrors the real backend: a fresh Firebase phone-OTP sign-up has no
      // name until profile completion (AUTH-3) — FakeAuth never has one
      // either, so `name` stays null here just like the real path.
      this.userProfile = {
        id: 'usr_fake',
        firebase_uid: 'fake-uid',
        role: 'customer',
        name: body?.name ?? null,
        phone: body?.phone ?? null,
        email: null,
        fcm_token: null,
        created_at: new Date().toISOString(),
      };
    }
    return this.userProfile;
  }

  async updateMe(body: { name?: string; email?: string }): Promise<UserProfile> {
    await this.delay();
    if (!this.userProfile) throw new ApiError(404, 'no synced profile to update');
    this.userProfile = {
      ...this.userProfile,
      ...(body.name !== undefined ? { name: body.name } : {}),
      ...(body.email !== undefined ? { email: body.email } : {}),
    };
    return this.userProfile;
  }
}
