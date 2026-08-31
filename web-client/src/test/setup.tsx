import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach, vi } from 'vitest';
import { authClient } from '../auth/singleton';

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
});
