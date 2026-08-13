import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, HttpApi } from './client';
import type { CreateJobRequest, QuoteRequest } from './types';

/** Builds a minimal fetch Response stand-in — only the bits HttpApi reads. */
function fakeResponse(body: unknown, { ok = true, status = 200 } = {}): Response {
  return {
    ok,
    status,
    json: () => Promise.resolve(body),
  } as unknown as Response;
}

describe('HttpApi', () => {
  const baseUrl = 'https://api.example.test';
  let fetchMock: ReturnType<typeof vi.fn>;
  let getToken: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal('fetch', fetchMock);
    getToken = vi.fn().mockResolvedValue('the-id-token');
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  function lastCall() {
    const [url, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    return { url, init };
  }

  describe('quote (auth: true by default)', () => {
    it('POSTs the request body, attaches the bearer token, and returns the parsed quote', async () => {
      const quote = { quote_id: 'q1', price: 50000, eta_minutes: 12, distance_km: 4.2 };
      fetchMock.mockResolvedValueOnce(fakeResponse(quote));
      const api = new HttpApi(baseUrl, getToken);

      const req: QuoteRequest = {
        vehicle_type: 'car',
        pickup: { lat: 6.2, lng: -75.6 },
        dropoff: { lat: 6.21, lng: -75.61 },
      };
      const result = await api.quote(req);

      expect(result).toEqual(quote);
      expect(getToken).toHaveBeenCalledTimes(1);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/jobs/quote`);
      expect(init.method).toBe('POST');
      expect(init.headers).toMatchObject({
        'Content-Type': 'application/json',
        Authorization: 'Bearer the-id-token',
      });
      expect(init.body).toBe(JSON.stringify(req));
    });

    it('omits the Authorization header when getToken resolves null', async () => {
      getToken.mockResolvedValue(null);
      fetchMock.mockResolvedValueOnce(
        fakeResponse({ quote_id: 'q1', price: 1, eta_minutes: 1, distance_km: 1 }),
      );
      const api = new HttpApi(baseUrl, getToken);

      await api.quote({
        vehicle_type: 'moto',
        pickup: { lat: 0, lng: 0 },
        dropoff: { lat: 1, lng: 1 },
      });

      const { init } = lastCall();
      expect(init.headers).not.toHaveProperty('Authorization');
    });
  });

  describe('createJob', () => {
    it('POSTs to /v1/jobs and returns the created job', async () => {
      const job = {
        id: 'j1',
        status: 'requested',
        vehicle_type: 'car',
        pickup_address: 'A',
        dropoff_address: 'B',
        quoted_price: 1000,
        final_price: null,
        distance_km: 1,
        driver: null,
        share_token: 'tok',
        created_at: '2026-01-01T00:00:00Z',
      };
      fetchMock.mockResolvedValueOnce(fakeResponse(job));
      const api = new HttpApi(baseUrl, getToken);

      const req: CreateJobRequest = {
        quote_id: 'q1',
        vehicle_type: 'car',
        pickup: { lat: 1, lng: 2, address: 'A' },
        dropoff: { lat: 3, lng: 4, address: 'B' },
      };
      const result = await api.createJob(req);

      expect(result).toEqual(job);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/jobs`);
      expect(init.method).toBe('POST');
      expect(init.body).toBe(JSON.stringify(req));
    });
  });

  describe('getJob', () => {
    it('GETs /v1/jobs/{id} with a null body and no body serialization', async () => {
      const job = { id: 'j1', status: 'assigned' };
      fetchMock.mockResolvedValueOnce(fakeResponse(job));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getJob('j1');

      expect(result).toEqual(job);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/jobs/j1`);
      expect(init.method).toBe('GET');
      expect(init.body).toBeNull();
    });

    it('percent-encodes ids with special characters', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}));
      const api = new HttpApi(baseUrl, getToken);

      await api.getJob('a/b c');

      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/jobs/${encodeURIComponent('a/b c')}`);
    });
  });

  describe('confirmDelivery', () => {
    it('POSTs to the confirm-delivery endpoint with no body', async () => {
      const job = { id: 'j1', status: 'completed' };
      fetchMock.mockResolvedValueOnce(fakeResponse(job));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.confirmDelivery('j1');

      expect(result).toEqual(job);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/jobs/j1/confirm-delivery`);
      expect(init.method).toBe('POST');
      expect(init.body).toBeNull();
    });
  });

  describe('submitRating', () => {
    it('POSTs stars and comment and resolves void', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.submitRating('j1', 5, 'great driver');

      expect(result).toBeUndefined();
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/jobs/j1/rating`);
      expect(init.body).toBe(JSON.stringify({ stars: 5, comment: 'great driver' }));
    });

    it('drops the comment field entirely when omitted (JSON.stringify semantics)', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}));
      const api = new HttpApi(baseUrl, getToken);

      await api.submitRating('j1', 4);

      const { init } = lastCall();
      expect(init.body).toBe(JSON.stringify({ stars: 4, comment: undefined }));
      expect(init.body).toBe('{"stars":4}');
    });
  });

  describe('getTrack (public, unauthenticated)', () => {
    it('GETs /v1/track/{token} without calling getToken or attaching Authorization', async () => {
      const track = {
        status: 'in_transit',
        pickup: { lat: 6.2, lng: -75.6 },
        dropoff: { lat: 6.21, lng: -75.61 },
        driver: null,
        driver_location: null,
      };
      fetchMock.mockResolvedValueOnce(fakeResponse(track));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getTrack('share-tok');

      expect(result).toEqual(track);
      expect(getToken).not.toHaveBeenCalled();
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/track/share-tok`);
      expect(init.method).toBe('GET');
      expect(init.headers).not.toHaveProperty('Authorization');
    });
  });

  describe('syncAuth', () => {
    it('POSTs the optional name/phone body and returns the profile', async () => {
      const profile = {
        id: 'u1',
        firebase_uid: 'fb1',
        role: 'customer',
        name: 'Sebastian',
        phone: '+573001234567',
        email: null,
        fcm_token: null,
        created_at: '2026-01-01T00:00:00Z',
      };
      fetchMock.mockResolvedValueOnce(fakeResponse(profile));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.syncAuth({ name: 'Sebastian', phone: '+573001234567' });

      expect(result).toEqual(profile);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/auth/sync`);
      expect(init.method).toBe('POST');
      expect(init.body).toBe(JSON.stringify({ name: 'Sebastian', phone: '+573001234567' }));
      expect(init.headers).toMatchObject({ Authorization: 'Bearer the-id-token' });
    });

    it('works with no body at all', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}));
      const api = new HttpApi(baseUrl, getToken);

      await api.syncAuth();

      const { init } = lastCall();
      expect(init.body).toBeNull();
    });
  });

  describe('non-2xx responses', () => {
    it('rejects with an ApiError carrying the status and a descriptive message (GET)', async () => {
      fetchMock.mockResolvedValue(fakeResponse({ detail: 'not found' }, { ok: false, status: 404 }));
      const api = new HttpApi(baseUrl, getToken);

      await expect(api.getJob('missing')).rejects.toBeInstanceOf(ApiError);
      await expect(api.getJob('missing')).rejects.toMatchObject({
        name: 'ApiError',
        status: 404,
        message: 'GET /v1/jobs/missing failed with 404',
      });
    });

    it('rejects with an ApiError on a failed POST', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}, { ok: false, status: 500 }));
      const api = new HttpApi(baseUrl, getToken);

      const req: QuoteRequest = {
        vehicle_type: 'suv',
        pickup: { lat: 0, lng: 0 },
        dropoff: { lat: 1, lng: 1 },
      };
      await expect(api.quote(req)).rejects.toMatchObject({
        status: 500,
        message: 'POST /v1/jobs/quote failed with 500',
      });
    });

    it('does not attempt to parse the body of a non-2xx response as the return value', async () => {
      // json() would blow up on invalid JSON; ApiError construction must not touch it.
      const res = {
        ok: false,
        status: 400,
        json: () => Promise.reject(new Error('should not be called')),
      } as unknown as Response;
      fetchMock.mockResolvedValueOnce(res);
      const api = new HttpApi(baseUrl, getToken);

      await expect(api.getJob('x')).rejects.toBeInstanceOf(ApiError);
    });
  });
});
