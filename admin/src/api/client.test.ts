import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { ApiError, HttpApi } from './client';
import type { FleetSettleRequest, SettleRequest } from './types';

/** Builds a minimal fetch Response stand-in — only the bits HttpApi reads. */
function fakeResponse(body: unknown, { ok = true, status = 200 } = {}): Response {
  return {
    ok,
    status,
    json: () => Promise.resolve(body),
  } as unknown as Response;
}

describe('HttpApi', () => {
  const baseUrl = 'https://admin-api.example.test';
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

  describe('getConfig', () => {
    it('GETs /v1/admin/config, attaches the bearer token, and returns the parsed body', async () => {
      const config = { config: { pricing: {} }, history: [] };
      fetchMock.mockResolvedValueOnce(fakeResponse(config));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getConfig();

      expect(result).toEqual(config);
      expect(getToken).toHaveBeenCalledTimes(1);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/config`);
      expect(init.method).toBe('GET');
      expect(init.headers).toMatchObject({
        'Content-Type': 'application/json',
        Authorization: 'Bearer the-id-token',
      });
      expect(init.body).toBeNull();
    });

    it('omits the Authorization header when getToken resolves null', async () => {
      getToken.mockResolvedValue(null);
      fetchMock.mockResolvedValueOnce(fakeResponse({ config: {}, history: [] }));
      const api = new HttpApi(baseUrl, getToken);

      await api.getConfig();

      const { init } = lastCall();
      expect(init.headers).not.toHaveProperty('Authorization');
    });
  });

  describe('updateConfig', () => {
    it('PUTs the value to the key-scoped endpoint and returns the fresh config', async () => {
      const config = { config: { dispatch: {} }, history: [] };
      fetchMock.mockResolvedValueOnce(fakeResponse(config));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.updateConfig('dispatch', {
        offer_ttl_seconds: 30,
        search_radius_km: 5,
        radius_widening_steps_km: [5, 10],
      });

      expect(result).toEqual(config);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/config/dispatch`);
      expect(init.method).toBe('PUT');
      expect(init.body).toBe(
        JSON.stringify({
          offer_ttl_seconds: 30,
          search_radius_km: 5,
          radius_widening_steps_km: [5, 10],
        }),
      );
    });
  });

  describe('getDrivers', () => {
    it('GETs /v1/admin/drivers with no query params and unwraps items when filters are omitted', async () => {
      const drivers = [{ user_id: 'd1', name: 'A' }];
      fetchMock.mockResolvedValueOnce(fakeResponse({ items: drivers, total: 1, limit: 20, offset: 0 }));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getDrivers();

      expect(result).toEqual(drivers);
      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/drivers`);
    });

    it('serializes verified/status filters into the query string', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({ items: [], total: 0, limit: 20, offset: 0 }));
      const api = new HttpApi(baseUrl, getToken);

      await api.getDrivers({ verified: true, status: 'blocked' });

      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/drivers?verified=true&status=blocked`);
    });

    it('drops undefined filter values from the query string entirely', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({ items: [], total: 0, limit: 20, offset: 0 }));
      const api = new HttpApi(baseUrl, getToken);

      await api.getDrivers({ verified: false });

      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/drivers?verified=false`);
    });
  });

  describe('verifyDriver / blockDriver / unblockDriver', () => {
    it('POSTs to the verify endpoint with no body and returns the driver', async () => {
      const driver = { user_id: 'd1', verified: true };
      fetchMock.mockResolvedValueOnce(fakeResponse(driver));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.verifyDriver('d1');

      expect(result).toEqual(driver);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/drivers/d1/verify`);
      expect(init.method).toBe('POST');
      expect(init.body).toBeNull();
    });

    it('percent-encodes the driver id on block', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}));
      const api = new HttpApi(baseUrl, getToken);

      await api.blockDriver('a/b c');

      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/drivers/${encodeURIComponent('a/b c')}/block`);
    });

    it('unblockDriver POSTs to the unblock endpoint', async () => {
      const driver = { user_id: 'd1', status: 'available' };
      fetchMock.mockResolvedValueOnce(fakeResponse(driver));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.unblockDriver('d1');

      expect(result).toEqual(driver);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/drivers/d1/unblock`);
      expect(init.method).toBe('POST');
    });
  });

  describe('getJobs', () => {
    it('GETs /v1/admin/jobs and unwraps items', async () => {
      const jobs = [{ id: 'j1', status: 'requested' }];
      fetchMock.mockResolvedValueOnce(fakeResponse({ items: jobs, total: 1, limit: 20, offset: 0 }));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getJobs();

      expect(result).toEqual(jobs);
      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/jobs`);
    });

    it('serializes the status filter into the query string', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({ items: [], total: 0, limit: 20, offset: 0 }));
      const api = new HttpApi(baseUrl, getToken);

      await api.getJobs({ status: 'completed' });

      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/jobs?status=completed`);
    });
  });

  describe('getJob', () => {
    it('GETs /v1/admin/jobs/{id} and returns the full detail', async () => {
      const job = { id: 'j1', status: 'assigned', offers: [] };
      fetchMock.mockResolvedValueOnce(fakeResponse(job));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getJob('j1');

      expect(result).toEqual(job);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/jobs/j1`);
      expect(init.method).toBe('GET');
    });
  });

  describe('cancelJob', () => {
    it('POSTs the reason and returns the plain job', async () => {
      const job = { id: 'j1', status: 'cancelled' };
      fetchMock.mockResolvedValueOnce(fakeResponse(job));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.cancelJob('j1', 'customer request');

      expect(result).toEqual(job);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/jobs/j1/cancel`);
      expect(init.method).toBe('POST');
      expect(init.body).toBe(JSON.stringify({ reason: 'customer request' }));
    });

    it('drops the reason field entirely when omitted (JSON.stringify semantics)', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}));
      const api = new HttpApi(baseUrl, getToken);

      await api.cancelJob('j1');

      const { init } = lastCall();
      expect(init.body).toBe('{}');
    });
  });

  describe('getLedger', () => {
    it('GETs /v1/admin/ledger and unwraps items', async () => {
      const rows = [{ driver_id: 'd1', name: 'A', owed_balance: 1000 }];
      fetchMock.mockResolvedValueOnce(fakeResponse({ items: rows, total: 1, limit: 20, offset: 0 }));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getLedger();

      expect(result).toEqual(rows);
      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/ledger`);
    });
  });

  describe('getLedgerEntries', () => {
    it('GETs /v1/admin/ledger/{driverId}/entries and unwraps items', async () => {
      const entries = [{ id: 'e1', driver_id: 'd1', entry_type: 'earning' }];
      fetchMock.mockResolvedValueOnce(
        fakeResponse({ items: entries, total: 1, limit: 20, offset: 0 }),
      );
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getLedgerEntries('d1');

      expect(result).toEqual(entries);
      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/ledger/d1/entries`);
    });
  });

  describe('settleLedger', () => {
    it('POSTs the settle body and returns the created entry', async () => {
      const entry = { id: 'e1', driver_id: 'd1', entry_type: 'payout' };
      fetchMock.mockResolvedValueOnce(fakeResponse(entry));
      const api = new HttpApi(baseUrl, getToken);

      const body: SettleRequest = { amount: 5000, note: 'weekly payout' };
      const result = await api.settleLedger('d1', body);

      expect(result).toEqual(entry);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/ledger/d1/settle`);
      expect(init.method).toBe('POST');
      expect(init.body).toBe(JSON.stringify(body));
    });
  });

  describe('getFleets', () => {
    it('GETs /v1/admin/fleets and returns the plain list (no pagination envelope)', async () => {
      const fleets = [{ id: 'f1', name: 'Fleet A' }];
      fetchMock.mockResolvedValueOnce(fakeResponse(fleets));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getFleets();

      expect(result).toEqual(fleets);
      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/fleets`);
    });
  });

  describe('getFleetBalance', () => {
    it('GETs /v1/admin/fleets/{id}/balance', async () => {
      const balance = { fleet_id: 'f1', owed_balance: 2000, members: [] };
      fetchMock.mockResolvedValueOnce(fakeResponse(balance));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.getFleetBalance('f1');

      expect(result).toEqual(balance);
      const { url } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/fleets/f1/balance`);
    });
  });

  describe('settleFleet', () => {
    it('POSTs the settle body and returns the apportionment response', async () => {
      const response = { fleet_id: 'f1', total_amount: 3000, entries: [] };
      fetchMock.mockResolvedValueOnce(fakeResponse(response));
      const api = new HttpApi(baseUrl, getToken);

      const body: FleetSettleRequest = { amount: 3000, note: 'monthly' };
      const result = await api.settleFleet('f1', body);

      expect(result).toEqual(response);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/fleets/f1/settle`);
      expect(init.method).toBe('POST');
      expect(init.body).toBe(JSON.stringify(body));
    });
  });

  describe('assignDriverToTruck', () => {
    it('POSTs the driver_id body to the truck-scoped assign-driver endpoint', async () => {
      const truck = {
        id: 't1',
        plate: 'ABC-123',
        type: 'car',
        capacity: 'car',
        driver_id: 'drv_9',
        fleet_id: 'f1',
      };
      fetchMock.mockResolvedValueOnce(fakeResponse(truck));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.assignDriverToTruck('t1', 'drv_9');

      expect(result).toEqual(truck);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/trucks/t1/assign-driver`);
      expect(init.method).toBe('POST');
      expect(init.body).toBe(JSON.stringify({ driver_id: 'drv_9' }));
    });
  });

  describe('unassignDriverFromTruck', () => {
    it('DELETEs the truck-scoped assign-driver endpoint and returns the cleared truck', async () => {
      const truck = {
        id: 't1',
        plate: 'ABC-123',
        type: 'car',
        capacity: 'car',
        driver_id: null,
        fleet_id: 'f1',
      };
      fetchMock.mockResolvedValueOnce(fakeResponse(truck));
      const api = new HttpApi(baseUrl, getToken);

      const result = await api.unassignDriverFromTruck('t1');

      expect(result).toEqual(truck);
      const { url, init } = lastCall();
      expect(url).toBe(`${baseUrl}/v1/admin/trucks/t1/assign-driver`);
      expect(init.method).toBe('DELETE');
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
        message: 'GET /v1/admin/jobs/missing failed with 404',
      });
    });

    it('rejects with an ApiError on a failed POST', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}, { ok: false, status: 500 }));
      const api = new HttpApi(baseUrl, getToken);

      await expect(api.verifyDriver('d1')).rejects.toMatchObject({
        status: 500,
        message: 'POST /v1/admin/drivers/d1/verify failed with 500',
      });
    });

    it('rejects with an ApiError on a failed PUT', async () => {
      fetchMock.mockResolvedValueOnce(fakeResponse({}, { ok: false, status: 422 }));
      const api = new HttpApi(baseUrl, getToken);

      await expect(
        api.updateConfig('settlement', {
          balance_cap: null,
          settlement_period: 'weekly',
        }),
      ).rejects.toMatchObject({
        status: 422,
        message: 'PUT /v1/admin/config/settlement failed with 422',
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
