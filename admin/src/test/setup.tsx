import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import type { ReactNode } from 'react';
import { afterEach, vi } from 'vitest';
import { authClient } from '../auth/singleton';

// ADM-5 follow-up: `@vis.gl/react-google-maps` loads the real Google Maps
// JavaScript API via a live `<script>` tag pointing at Google's servers —
// jsdom has no network and no WebGL, so the real library can't run in
// tests at all. Mocked wholesale here (once, globally), mirroring
// `web-client/src/test/setup.tsx`'s identical mock for the same reason:
// `APIProvider`/`Map` just render their children in a plain div (no script
// injected, no `google` global touched), `Marker` renders a `<button>`
// exposing its `position`/`title` as `data-*` attributes (a button, not a
// div, so `onClick` is actually testable via a normal click/keyboard
// interaction) so a test can assert which pins are present, where, and
// that clicking one fires its handler.
vi.mock('@vis.gl/react-google-maps', () => ({
  APIProvider: ({ children }: { children?: ReactNode }) => children,
  Map: ({ children }: { children?: ReactNode }) => children,
  Marker: (props: {
    position?: { lat: number; lng: number };
    title?: string;
    onClick?: () => void;
  }) => {
    const { position, title, onClick } = props;
    return (
      <button
        type="button"
        data-testid="map-marker"
        data-marker-title={title}
        data-marker-lat={position?.lat}
        data-marker-lng={position?.lng}
        onClick={onClick}
      />
    );
  },
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

afterEach(async () => {
  cleanup();
  window.localStorage.clear();
  // The auth singleton keeps the fake session in memory — reset between tests.
  await authClient.signOut();
});
