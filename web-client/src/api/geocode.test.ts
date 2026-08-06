import { describe, expect, it } from 'vitest';
import { fakeGeocode } from './geocode';

describe('fakeGeocode', () => {
  it('is deterministic for the same address', () => {
    expect(fakeGeocode('Cra. 43A #1-50, El Poblado')).toEqual(
      fakeGeocode('Cra. 43A #1-50, El Poblado'),
    );
  });

  it('is case/whitespace-insensitive, matching the Flutter app', () => {
    expect(fakeGeocode('  Cra. 43A #1-50  ')).toEqual(fakeGeocode('cra. 43a #1-50'));
  });

  it('stays near Medellín', () => {
    const { lat, lng } = fakeGeocode('Cl. 10 #52-25, Guayabal');
    expect(lat).toBeGreaterThan(6.1);
    expect(lat).toBeLessThan(6.3);
    expect(lng).toBeGreaterThan(-75.7);
    expect(lng).toBeLessThan(-75.5);
  });

  it('gives different addresses different points', () => {
    expect(fakeGeocode('A')).not.toEqual(fakeGeocode('B'));
  });
});
