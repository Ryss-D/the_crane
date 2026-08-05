import type { CraneApi } from './client';
import { HttpApi } from './client';
import { MockApi } from './mock';
import { authClient } from '../auth/singleton';

/**
 * Mock/real seam. Mocks are the DEFAULT (VITE_USE_MOCKS is treated as true
 * unless explicitly "false") because neither the backend contract nor the
 * Firebase project (FND-1) exist for this app yet.
 */
const useMocks = import.meta.env.VITE_USE_MOCKS !== 'false';

// Zero latency under vitest so tests stay fast and deterministic.
const mockLatencyMs = import.meta.env.MODE === 'test' ? 0 : 450;

export const api: CraneApi = useMocks
  ? new MockApi(mockLatencyMs)
  : new HttpApi(import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000', () =>
      authClient.getIdToken(),
    );

export * from './types';
export { ApiError } from './client';
export type { CraneApi } from './client';
