/**
 * Realtime seam — NOT implemented yet.
 *
 * TODO(WEB-3/TRK-1): connect a native WebSocket to the backend's /v1/ws,
 * subscribe to job events, push status/position updates into the TanStack
 * Query cache and the active-job Zustand store, and reconnect with backoff.
 * Until then the tracking pages rely on the polling fallback that will remain
 * in place forever anyway (plan: "socket kill switches to polling
 * transparently") — TanStack Query refetchInterval of POLL_INTERVAL_MS.
 */
export const POLL_INTERVAL_MS = 10_000;

export interface JobSocketState {
  /** Always false until the WS layer exists — pages poll instead. */
  connected: boolean;
}

export function useJobSocket(_jobId: string | null): JobSocketState {
  return { connected: false };
}
