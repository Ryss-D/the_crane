import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';
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

afterEach(async () => {
  cleanup();
  window.localStorage.clear();
  // The auth singleton keeps the fake session in memory — reset between tests.
  await authClient.signOut();
});
