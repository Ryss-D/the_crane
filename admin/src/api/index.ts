import type { CraneAdminApi } from './client';
import { HttpApi } from './client';
import { MockApi } from './mock';
import { authClient } from '../auth/singleton';

/**
 * Mock/real seam — same pattern as web-client/src/api/index.ts. Mocks are the
 * DEFAULT (VITE_USE_MOCKS is treated as true unless explicitly "false")
 * because neither the real /v1/admin/* router (ADM-2) nor the Firebase
 * project (FND-1) are guaranteed to exist yet for every dev environment.
 */
const useMocks = import.meta.env.VITE_USE_MOCKS !== 'false';

// Zero latency under vitest so tests stay fast and deterministic.
const mockLatencyMs = import.meta.env.MODE === 'test' ? 0 : 350;

export const api: CraneAdminApi = useMocks
  ? new MockApi(mockLatencyMs)
  : new HttpApi(import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000', () =>
      authClient.getIdToken(),
    );

export * from './types';
export { ApiError } from './client';
export type { CraneAdminApi } from './client';
