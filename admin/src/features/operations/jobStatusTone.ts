import type { JobStatus } from '../../api/types';
import type { BadgeTone } from '../../ui';

export const jobStatusTone: Record<JobStatus, BadgeTone> = {
  requested: 'neutral',
  matching: 'info',
  assigned: 'info',
  en_route_pickup: 'warning',
  arrived_pickup: 'warning',
  loading: 'warning',
  in_transit: 'info',
  delivered: 'success',
  completed: 'success',
  cancelled: 'danger',
  no_drivers: 'danger',
};
