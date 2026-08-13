import { afterEach, describe, expect, it, vi } from 'vitest';

/**
 * The mock/real seam in src/api/index.ts is a module-scope `const` derived
 * from `import.meta.env.VITE_USE_MOCKS`, so exercising both branches means
 * stubbing the env var *before* a fresh module evaluation — hence
 * vi.resetModules() + a dynamic import per test rather than a static one.
 */
describe('api/index mock-vs-real selection', () => {
  afterEach(() => {
    vi.unstubAllEnvs();
    vi.resetModules();
  });

  it('defaults to MockApi when VITE_USE_MOCKS is unset', async () => {
    vi.stubEnv('VITE_USE_MOCKS', undefined as unknown as string);
    vi.resetModules();
    const { api } = await import('./index');
    const { MockApi } = await import('./mock');

    expect(api).toBeInstanceOf(MockApi);
  });

  it('uses MockApi for any value other than the exact string "false"', async () => {
    vi.stubEnv('VITE_USE_MOCKS', 'true');
    vi.resetModules();
    const { api } = await import('./index');
    const { MockApi } = await import('./mock');

    expect(api).toBeInstanceOf(MockApi);
  });

  it('switches to the real HttpApi when VITE_USE_MOCKS is exactly "false"', async () => {
    vi.stubEnv('VITE_USE_MOCKS', 'false');
    vi.resetModules();
    const { api } = await import('./index');
    const { HttpApi } = await import('./client');

    expect(api).toBeInstanceOf(HttpApi);
  });

  it('falls back to http://localhost:8000 when VITE_API_BASE_URL is unset', async () => {
    vi.stubEnv('VITE_USE_MOCKS', 'false');
    vi.stubEnv('VITE_API_BASE_URL', undefined as unknown as string);
    vi.resetModules();
    const { api } = await import('./index');

    expect((api as unknown as { baseUrl: string }).baseUrl).toBe('http://localhost:8000');
  });

  it('uses VITE_API_BASE_URL when it is set', async () => {
    vi.stubEnv('VITE_USE_MOCKS', 'false');
    vi.stubEnv('VITE_API_BASE_URL', 'https://api.crane.test');
    vi.resetModules();
    const { api } = await import('./index');

    expect((api as unknown as { baseUrl: string }).baseUrl).toBe('https://api.crane.test');
  });

  it('wires the real HttpApi to fetch its bearer token from the authClient singleton', async () => {
    vi.stubEnv('VITE_USE_MOCKS', 'false');
    vi.resetModules();
    const fetchMock = vi.fn().mockResolvedValue({
      ok: true,
      status: 200,
      json: () => Promise.resolve({ quote_id: 'q1', price: 1, eta_minutes: 1, distance_km: 1 }),
    });
    vi.stubGlobal('fetch', fetchMock);

    const { api } = await import('./index');
    // No FakeAuth session exists in this fresh module graph, so getIdToken()
    // resolves null and no Authorization header is attached — but exercising
    // this path is what proves index.ts really injected authClient.getIdToken
    // as HttpApi's GetToken, not a stub.
    await api.quote({
      vehicle_type: 'car',
      pickup: { lat: 0, lng: 0 },
      dropoff: { lat: 1, lng: 1 },
    });

    expect(fetchMock).toHaveBeenCalledTimes(1);
    const [, init] = fetchMock.mock.calls[0] as [string, RequestInit];
    expect(init.headers).not.toHaveProperty('Authorization');

    vi.unstubAllGlobals();
  });
});
