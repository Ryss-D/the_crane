import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import type { ReactNode } from 'react';
import { afterEach, vi } from 'vitest';
import { api } from '../api';
import { MockApi } from '../api/mock';
import { authClient } from '../auth/singleton';

// FND-6 follow-up: `@vis.gl/react-google-maps` loads the real Google Maps
// JavaScript API via a live `<script>` tag pointing at Google's servers —
// jsdom has no network and no WebGL, so the real library can't run in
// tests at all. Mocked wholesale here (once, globally) rather than per test
// file: `APIProvider`/`Map` just render their children in a plain div (no
// script injected, no `google` global touched), `Marker` renders a `<div>`
// exposing its `position`/`label`/`title` as `data-*` attributes so a test
// can assert which pins are present and where without needing real Google
// Maps objects, and `useMapsLibrary` returns `null` (matching the real
// hook's "library not loaded yet" state) so `usePlacesAutocomplete` no-ops
// safely — same "ask for it, don't crash if it's not there" contract every
// other optional integration in this app already follows.
vi.mock('@vis.gl/react-google-maps', () => ({
  APIProvider: ({ children }: { children?: ReactNode }) => children,
  Map: ({ children }: { children?: ReactNode }) => children,
  Marker: (props: {
    position?: { lat: number; lng: number };
    label?: string;
    title?: string;
  }) => {
    const { position, label, title } = props;
    return (
      <div
        data-testid="map-marker"
        data-marker-label={label}
        data-marker-title={title}
        data-marker-lat={position?.lat}
        data-marker-lng={position?.lng}
      />
    );
  },
  useMapsLibrary: () => null,
}));

// Node >= 22 defines an experimental `localStorage` global that shadows
// jsdom's and resolves to undefined unless --localstorage-file is passed.
// Replace it with a simple in-memory Storage for tests.
class MemoryStorage implements Storage {
  private map = new Map<string, string>();
  get length(): number {
    return this.map.size;
  }
  clear(): void {
    this.map.clear();
  }
  getItem(key: string): string | null {
    return this.map.get(key) ?? null;
  }
  key(index: number): string | null {
    return [...this.map.keys()][index] ?? null;
  }
  removeItem(key: string): void {
    this.map.delete(key);
  }
  setItem(key: string, value: string): void {
    this.map.set(key, String(value));
  }
}

Object.defineProperty(globalThis, 'localStorage', {
  value: new MemoryStorage(),
  configurable: true,
  writable: true,
});

// WEB-2: jsdom doesn't implement navigator.geolocation at all, so any test
// that touches "usar mi ubicación actual" (RequestPage.tsx) needs a stand-in.
// Exported so individual tests can drive success/failure via
// mockGeolocation.getCurrentPosition.mockImplementation(...).
export const mockGeolocation = {
  getCurrentPosition: vi.fn(),
  watchPosition: vi.fn(),
  clearWatch: vi.fn(),
};

Object.defineProperty(globalThis.navigator, 'geolocation', {
  value: mockGeolocation,
  configurable: true,
  writable: true,
});

afterEach(async () => {
  cleanup();
  window.localStorage.clear();
  mockGeolocation.getCurrentPosition.mockReset();
  // The auth singleton keeps the fake session in memory — reset between tests.
  await authClient.signOut();
  // WEB-1: `api` is a module-level singleton too — MockApi's synced profile
  // (name completion in particular) must not leak into the next test.
  if (api instanceof MockApi) api.resetForTests();
});
