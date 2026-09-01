import type { PaymentStatus } from '../../api/types';
import type { BadgeTone } from '../../ui';

/** PAY-4 follow-up: `pending`/`processing` are the "payment still in flight"
 * states the admin most needs to notice — an amber badge, same tone a
 * mid-flight job status gets in jobStatusTone.ts — so they read as distinct
 * from a fully settled (`approved`) or genuinely dead (`declined`/`expired`)
 * payment. */
export const paymentStatusTone: Record<PaymentStatus, BadgeTone> = {
  pending: 'warning',
  processing: 'warning',
  approved: 'success',
  declined: 'danger',
  expired: 'danger',
  refunded: 'neutral',
};
