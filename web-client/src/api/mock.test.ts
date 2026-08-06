import { describe, expect, it } from 'vitest';
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
