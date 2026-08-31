import { useEffect, useRef, useState } from 'react';
import { useQueryClient } from '@tanstack/react-query';
import type { LatLng } from '../api/types';
import { authClient } from '../auth/singleton';

/**
 * Realtime seam for TRK-1/2/3: connects to the backend's authed `/v1/ws`,
 * subscribes to one job, and invalidates that job's TanStack Query cache
 * entry on every `job_event` push so `TrackingPage`'s existing `useQuery`
 * re-fetches immediately instead of waiting for its next poll.
 *
 * Polling (`POLL_INTERVAL_MS` below, via `refetchInterval` in the page) stays
 * in place regardless of `connected` — that's the permanent fallback per the
 * plan ("socket kill switches to polling transparently"), not something this
 * hook needs to orchestrate itself. Under mocks (`VITE_USE_MOCKS`, or the
 * vitest `MODE=test` env) there's no real backend to connect to, so this
 * intentionally no-ops and always reports `connected: false`.
 */
export const POLL_INTERVAL_MS = 10_000;

const RECONNECT_DELAY_MS = 2_000;

export interface JobSocketState {
  /** True once the socket is open and subscribed. Polling covers the gap
   * whenever this is false — nothing else needs to react to it. */
  connected: boolean;
  /** WEB-2/WEB-3: the most recent `driver_location` push for this job, if
   * any arrived yet. Backend's `JobRead` (`GET /v1/jobs/{id}`) has no
   * location field at all — unlike the public track endpoint's
   * `TrackResponse.driver_location` — so this WS event is the *only* way
   * the authenticated tracking page can show a live driver position. Reset
   * to null whenever `jobId` changes; stays at its last value across a
   * reconnect (a stale-but-recent position beats none while polling
   * catches up).
   */
  driverLocation: LatLng | null;
}

function wsBaseUrl(): string {
  const httpBase = import.meta.env.VITE_API_BASE_URL ?? 'http://localhost:8000';
  return httpBase.replace(/^http/, 'ws');
}

const useMocks = import.meta.env.VITE_USE_MOCKS !== 'false' || import.meta.env.MODE === 'test';

export function useJobSocket(jobId: string | null): JobSocketState {
  const [connected, setConnected] = useState(false);
  const [driverLocation, setDriverLocation] = useState<LatLng | null>(null);
  const queryClient = useQueryClient();
  // Avoids a stale-closure invalidate call after the hook re-runs for a new
  // jobId while a previous socket's async token fetch is still in flight.
  const jobIdRef = useRef(jobId);
  jobIdRef.current = jobId;

  useEffect(() => {
    // A fresh job (or leaving the page) has no position carried over from
    // whatever job this hook was previously watching.
    setDriverLocation(null);

    if (useMocks || !jobId) {
      setConnected(false);
      return;
    }

    let socket: WebSocket | null = null;
    let reconnectTimer: ReturnType<typeof setTimeout> | null = null;
    let cancelled = false;

    async function connect(): Promise<void> {
      const token = await authClient.getIdToken();
      if (cancelled || !token) return;

      socket = new WebSocket(`${wsBaseUrl()}/v1/ws?token=${encodeURIComponent(token)}`);

      socket.onopen = () => {
        if (cancelled) return;
        setConnected(true);
        socket?.send(JSON.stringify({ type: 'subscribe', job_id: jobIdRef.current }));
      };

      socket.onmessage = (event: MessageEvent<string>) => {
        let msg: { type?: string; job_id?: string; lat?: number; lng?: number };
        try {
          msg = JSON.parse(event.data);
        } catch {
          return;
        }
        if (msg.type === 'ping') {
          socket?.send(JSON.stringify({ type: 'pong' }));
        } else if (msg.type === 'job_event' && msg.job_id === jobIdRef.current) {
          void queryClient.invalidateQueries({ queryKey: ['job', jobIdRef.current] });
        } else if (
          msg.type === 'driver_location' &&
          msg.job_id === jobIdRef.current &&
          typeof msg.lat === 'number' &&
          typeof msg.lng === 'number'
        ) {
          // Backend's `DriverLocationEvent` (app/schemas/job.py) — pushed on
          // this same authed channel, not just the public track one.
          setDriverLocation({ lat: msg.lat, lng: msg.lng });
        }
      };

      const scheduleReconnect = () => {
        setConnected(false);
        if (!cancelled) reconnectTimer = setTimeout(connect, RECONNECT_DELAY_MS);
      };
      socket.onclose = scheduleReconnect;
      socket.onerror = scheduleReconnect;
    }

    void connect();

    return () => {
      cancelled = true;
      if (reconnectTimer) clearTimeout(reconnectTimer);
      if (socket && socket.readyState === WebSocket.OPEN) {
        socket.send(JSON.stringify({ type: 'unsubscribe', job_id: jobId }));
      }
      socket?.close();
    };
  }, [jobId, queryClient]);

  return { connected, driverLocation };
}
