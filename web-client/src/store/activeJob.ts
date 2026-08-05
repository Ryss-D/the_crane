import { create } from 'zustand';
import type { JobStatus } from '../api/types';

/**
 * Tiny store for the customer's active job — survives route changes so the
 * request page can offer "volver a tu servicio activo". The socket layer
 * (src/ws) will also write lastStatus here once TRK-1 lands.
 */
interface ActiveJobState {
  jobId: string | null;
  lastStatus: JobStatus | null;
  setActiveJob: (jobId: string, status: JobStatus) => void;
  updateStatus: (status: JobStatus) => void;
  clear: () => void;
}

export const useActiveJobStore = create<ActiveJobState>((set) => ({
  jobId: null,
  lastStatus: null,
  setActiveJob: (jobId, status) => set({ jobId, lastStatus: status }),
  updateStatus: (status) => set({ lastStatus: status }),
  clear: () => set({ jobId: null, lastStatus: null }),
}));
