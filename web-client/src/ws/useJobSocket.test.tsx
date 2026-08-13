import type { ReactNode } from 'react';
import { act, renderHook, waitFor } from '@testing-library/react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';

/**
 * `useJobSocket` is only real once `VITE_USE_MOCKS=false` *and* the vitest
 * `MODE=test` shortcut is off too (its `useMocks` const is
 * `VITE_USE_MOCKS !== 'false' || MODE === 'test'`) — so, like
 * `src/api/index.test.ts` does for the same env-derived-module-scope-const
 * shape, we stub both env vars and `vi.resetModules()` + dynamically import
 * the hook fresh per test.
 *
 * There's no fake-WebSocket harness in this codebase yet (per
 * docs/tasks/10-web-client.md's WEB-3 note), so this file builds a minimal
 * one scoped to this hook: a `WebSocket`-shaped class you can instantiate
 * (via `new WebSocket(...)`, stubbed onto `globalThis`) and drive by hand
 * through its `on*` handlers.
 */
class FakeWebSocket {
  static readonly CONNECTING = 0;
  static readonly OPEN = 1;
  static readonly CLOSING = 2;
  static readonly CLOSED = 3;

  /** Every instance constructed since the last `FakeWebSocket.reset()`. */
  static instances: FakeWebSocket[] = [];
  static reset(): void {
    FakeWebSocket.instances = [];
  }

  readyState = FakeWebSocket.CONNECTING;
  readonly sent: string[] = [];
  onopen: (() => void) | null = null;
  onmessage: ((event: MessageEvent<string>) => void) | null = null;
  onclose: (() => void) | null = null;
  onerror: (() => void) | null = null;

  constructor(readonly url: string) {
    FakeWebSocket.instances.push(this);
  }

  send(data: string): void {
    this.sent.push(data);
  }

  close(): void {
    this.readyState = FakeWebSocket.CLOSED;
  }

  /** Test helper: flips to OPEN and fires the handler, like a real socket. */
  triggerOpen(): void {
    this.readyState = FakeWebSocket.OPEN;
    this.onopen?.();
  }

  triggerMessage(data: unknown): void {
    this.onmessage?.({ data: JSON.stringify(data) } as MessageEvent<string>);
  }

  triggerClose(): void {
    this.readyState = FakeWebSocket.CLOSED;
    this.onclose?.();
  }

  triggerError(): void {
    this.onerror?.();
  }
}

const TEST_ID_TOKEN = 'test-id-token';

vi.mock('../auth/singleton', () => ({
  authClient: { getIdToken: vi.fn().mockResolvedValue(TEST_ID_TOKEN) },
}));

function wrapper(queryClient: QueryClient) {
  return function Wrapper({ children }: { children: ReactNode }) {
    return <QueryClientProvider client={queryClient}>{children}</QueryClientProvider>;
  };
}

describe('useJobSocket (WEB-3)', () => {
  let queryClient: QueryClient;

  beforeEach(() => {
    vi.stubEnv('VITE_USE_MOCKS', 'false');
    vi.stubEnv('MODE', 'development');
    vi.resetModules();
    FakeWebSocket.reset();
    vi.stubGlobal('WebSocket', FakeWebSocket);
    queryClient = new QueryClient();
  });

  afterEach(() => {
    vi.useRealTimers();
    vi.unstubAllEnvs();
    vi.unstubAllGlobals();
    vi.resetModules();
  });

  it('connects to /v1/ws with the auth token and subscribes to the job on open', async () => {
    const { useJobSocket } = await import('./useJobSocket');
    const { result } = renderHook(() => useJobSocket('job-1'), { wrapper: wrapper(queryClient) });

    await waitFor(() => expect(FakeWebSocket.instances).toHaveLength(1));
    const socket = FakeWebSocket.instances[0]!;
    expect(socket.url).toBe(`ws://localhost:8000/v1/ws?token=${TEST_ID_TOKEN}`);
    expect(result.current.connected).toBe(false);

    act(() => socket.triggerOpen());

    await waitFor(() => expect(result.current.connected).toBe(true));
    expect(socket.sent).toEqual([JSON.stringify({ type: 'subscribe', job_id: 'job-1' })]);
  });

  it('replies to a ping and invalidates the job query cache on a matching job_event', async () => {
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries');
    const { useJobSocket } = await import('./useJobSocket');
    renderHook(() => useJobSocket('job-1'), { wrapper: wrapper(queryClient) });

    await waitFor(() => expect(FakeWebSocket.instances).toHaveLength(1));
    const socket = FakeWebSocket.instances[0]!;
    act(() => socket.triggerOpen());

    act(() => socket.triggerMessage({ type: 'ping' }));
    expect(socket.sent).toContain(JSON.stringify({ type: 'pong' }));

    act(() => socket.triggerMessage({ type: 'job_event', job_id: 'job-1' }));
    expect(invalidateSpy).toHaveBeenCalledWith({ queryKey: ['job', 'job-1'] });
  });

  it('ignores a job_event for a different job id', async () => {
    const invalidateSpy = vi.spyOn(queryClient, 'invalidateQueries');
    const { useJobSocket } = await import('./useJobSocket');
    renderHook(() => useJobSocket('job-1'), { wrapper: wrapper(queryClient) });

    await waitFor(() => expect(FakeWebSocket.instances).toHaveLength(1));
    const socket = FakeWebSocket.instances[0]!;
    act(() => socket.triggerOpen());

    act(() => socket.triggerMessage({ type: 'job_event', job_id: 'some-other-job' }));

    expect(invalidateSpy).not.toHaveBeenCalled();
  });

  it('ignores an unparseable message instead of throwing', async () => {
    const { useJobSocket } = await import('./useJobSocket');
    renderHook(() => useJobSocket('job-1'), { wrapper: wrapper(queryClient) });

    await waitFor(() => expect(FakeWebSocket.instances).toHaveLength(1));
    const socket = FakeWebSocket.instances[0]!;
    act(() => socket.triggerOpen());

    expect(() => {
      act(() => socket.onmessage?.({ data: 'not json' } as MessageEvent<string>));
    }).not.toThrow();
  });

  it('attempts a reconnect after the socket closes', async () => {
    vi.useFakeTimers();
    const { useJobSocket } = await import('./useJobSocket');
    renderHook(() => useJobSocket('job-1'), { wrapper: wrapper(queryClient) });

    await vi.advanceTimersByTimeAsync(0);
    expect(FakeWebSocket.instances).toHaveLength(1);
    const first = FakeWebSocket.instances[0]!;
    act(() => first.triggerOpen());
    expect(first.readyState).toBe(FakeWebSocket.OPEN);

    act(() => first.triggerClose());

    // Reconnect is delayed, not immediate.
    expect(FakeWebSocket.instances).toHaveLength(1);

    await vi.advanceTimersByTimeAsync(2_000);

    expect(FakeWebSocket.instances).toHaveLength(2);
    expect(FakeWebSocket.instances[1]!.url).toBe(first.url);
  });

  it('attempts a reconnect after a socket error', async () => {
    vi.useFakeTimers();
    const { useJobSocket } = await import('./useJobSocket');
    renderHook(() => useJobSocket('job-1'), { wrapper: wrapper(queryClient) });

    await vi.advanceTimersByTimeAsync(0);
    expect(FakeWebSocket.instances).toHaveLength(1);
    const first = FakeWebSocket.instances[0]!;
    act(() => first.triggerOpen());

    act(() => first.triggerError());

    await vi.advanceTimersByTimeAsync(2_000);

    expect(FakeWebSocket.instances).toHaveLength(2);
  });

  it('sends an unsubscribe message and closes the socket on unmount', async () => {
    const { useJobSocket } = await import('./useJobSocket');
    const { result, unmount } = renderHook(() => useJobSocket('job-1'), {
      wrapper: wrapper(queryClient),
    });

    await waitFor(() => expect(FakeWebSocket.instances).toHaveLength(1));
    const socket = FakeWebSocket.instances[0]!;
    act(() => socket.triggerOpen());
    await waitFor(() => expect(result.current.connected).toBe(true));

    unmount();

    expect(socket.sent).toContain(JSON.stringify({ type: 'unsubscribe', job_id: 'job-1' }));
    expect(socket.readyState).toBe(FakeWebSocket.CLOSED);
  });

  it('does not reconnect after unmount even if a pending reconnect timer was scheduled', async () => {
    vi.useFakeTimers();
    const { useJobSocket } = await import('./useJobSocket');
    const { unmount } = renderHook(() => useJobSocket('job-1'), { wrapper: wrapper(queryClient) });

    await vi.advanceTimersByTimeAsync(0);
    const first = FakeWebSocket.instances[0]!;
    act(() => first.triggerOpen());
    act(() => first.triggerClose());

    unmount();

    await vi.advanceTimersByTimeAsync(5_000);

    // The scheduled reconnect timer was cleared by the unmount cleanup.
    expect(FakeWebSocket.instances).toHaveLength(1);
  });
});
