import { describe, expect, it } from 'vitest';
import { ApiError } from './client';
import { MockApi } from './mock';

describe('MockApi.syncAuth (WEB-1 fix)', () => {
  it('creates a profile with a null name on the first call, matching a fresh Firebase phone sign-up', async () => {
    const mockApi = new MockApi(0);
    const profile = await mockApi.syncAuth({ phone: '+573001234567' });
    expect(profile.name).toBeNull();
    expect(profile.phone).toBe('+573001234567');
    expect(profile.role).toBe('customer');
  });

  it('is idempotent — a later call returns the same row regardless of the body', async () => {
    const mockApi = new MockApi(0);
    const first = await mockApi.syncAuth({ phone: '+573001234567' });
    const second = await mockApi.syncAuth({ name: 'Someone Else', phone: '+573009998888' });
    expect(second).toEqual(first);
  });

  it('works with no body at all, like a bootstrap resync', async () => {
    const mockApi = new MockApi(0);
    const profile = await mockApi.syncAuth();
    expect(profile.name).toBeNull();
    expect(profile.phone).toBeNull();
  });
});

describe('MockApi.confirmDelivery (PAY-4)', () => {
  it('completes a cash confirm (no payment method) regardless of the digital-fares flag', async () => {
    const mockApi = new MockApi(0);
    expect(mockApi.digitalFaresEnabled).toBe(false); // matches the backend's own default
    const job = await mockApi.confirmDelivery('demo-delivered');
    expect(job.status).toBe('completed');
    expect(job.async_payment_url).toBeNull();
  });

  it('rejects a non-cash method with a 422 ApiError when the flag is off', async () => {
    const mockApi = new MockApi(0);
    await expect(mockApi.confirmDelivery('demo-delivered', 'pse')).rejects.toMatchObject({
      name: 'ApiError',
      status: 422,
    });
    await expect(mockApi.confirmDelivery('demo-delivered', 'pse')).rejects.toBeInstanceOf(ApiError);
  });

  it('returns a realistic fake async_payment_url for PSE/card once the flag is on', async () => {
    const mockApi = new MockApi(0);
    mockApi.digitalFaresEnabled = true;

    const pse = await mockApi.confirmDelivery('demo-delivered', 'pse');
    expect(pse.status).toBe('completed');
    expect(pse.async_payment_url).toBe('https://checkout.wompi.co/fake/demo-delivered_pse');
  });

  it('returns no async_payment_url for Nequi even when the flag is on (no redirect step)', async () => {
    const mockApi = new MockApi(0);
    mockApi.digitalFaresEnabled = true;

    const nequi = await mockApi.confirmDelivery('demo-delivered', 'nequi');
    expect(nequi.status).toBe('completed');
    expect(nequi.async_payment_url).toBeNull();
  });

  it('never resurrects a stale async_payment_url on a later getJob() re-fetch', async () => {
    const mockApi = new MockApi(0);
    mockApi.digitalFaresEnabled = true;
    await mockApi.confirmDelivery('demo-delivered', 'card');

    const refetched = await mockApi.getJob('demo-delivered');
    expect(refetched.async_payment_url).toBeNull();
  });
});

describe('MockApi.reverseGeocode (CUS-1/CUS-4/WEB-2 follow-up)', () => {
  it('resolves to the nearest seeded fake landmark', async () => {
    const mockApi = new MockApi(0);
    // Right on top of the seeded El Poblado coordinate.
    const address = await mockApi.reverseGeocode(6.2088, -75.5679);
    expect(address).toBe('Cerca de El Poblado, Medellín, Antioquia');
  });

  it('picks a different nearest landmark for a different coordinate', async () => {
    const mockApi = new MockApi(0);
    // Closer to the seeded Bello coordinate than to any other seed.
    const address = await mockApi.reverseGeocode(6.31, -75.61);
    expect(address).toBe('Cerca de Bello, Antioquia');
  });

  it('never returns null — there is no "no key configured" state to simulate under mocks', async () => {
    const mockApi = new MockApi(0);
    const address = await mockApi.reverseGeocode(0, 0);
    expect(address).not.toBeNull();
  });
});
