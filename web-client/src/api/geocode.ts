import type { LatLng } from './types';

/** Medellín city center, anchor point for the fake geocoder below. */
const MEDELLIN: LatLng = { lat: 6.2442, lng: -75.5812 };

/** Deterministic tiny hash so the same address string always geocodes the
 * same point (and MockApi's quote pricing stays reproducible). */
export function hash(s: string): number {
  let h = 0;
  for (let i = 0; i < s.length; i++) h = (h * 31 + s.charCodeAt(i)) >>> 0;
  return h;
}

/**
 * Deterministic pseudo-geocoding: hashes the typed address into a point near
 * Medellín so a real (non-mock) quote/create call has the `{lat, lng}` the
 * backend requires, without real Maps/Places (FND-6) wired yet. Mirrors
 * `fakeGeocode` in the Flutter app (`lib/features/customer/request/request_bloc.dart`)
 * — same idea, not bit-identical output (different hash per language).
 */
export function fakeGeocode(address: string): LatLng {
  const h = hash(address.trim().toLowerCase());
  return {
    lat: MEDELLIN.lat + ((h % 1000) - 500) / 10000,
    lng: MEDELLIN.lng + (((Math.floor(h / 1000) % 1000) - 500) / 10000),
  };
}
