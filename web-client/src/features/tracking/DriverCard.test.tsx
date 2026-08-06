import { render, screen } from '@testing-library/react';
import { describe, expect, it } from 'vitest';
import type { Driver } from '../../api/types';
import { strings } from '../../i18n/strings';
import { DriverCard } from './DriverCard';

const baseDriver: Driver = {
  id: 'drv-1',
  name: 'Carlos Restrepo',
  phone: '+573001112233',
  truck_plate: 'TKX-482',
  truck_type: 'car',
  rating_avg: 4.8,
  photo_url: null,
};

describe('DriverCard call button', () => {
  it('renders a tel: link when the driver has a phone', () => {
    render(<DriverCard driver={baseDriver} />);
    const link = screen.getByRole('link', { name: strings.tracking.callDriver });
    expect(link).toHaveAttribute('href', 'tel:+573001112233');
  });

  it('renders no call link when the driver has no phone on file', () => {
    render(<DriverCard driver={{ ...baseDriver, phone: null }} />);
    expect(
      screen.queryByRole('link', { name: strings.tracking.callDriver }),
    ).not.toBeInTheDocument();
  });
});
