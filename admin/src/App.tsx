import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth';
import { LoginPage } from './features/auth/LoginPage';
import { ConfigPage } from './features/config/ConfigPage';
import { DashboardPage } from './features/dashboard/DashboardPage';
import { DriversPage } from './features/drivers/DriversPage';
import { FleetsPage } from './features/fleets/FleetsPage';
import { JobDetailPage } from './features/operations/JobDetailPage';
import { OperationsPage } from './features/operations/OperationsPage';
import { LedgerPage } from './features/ledger/LedgerPage';
import { AppLayout } from './layout/AppLayout';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: 1, refetchOnWindowFocus: false },
  },
});

export function AppRoutes() {
  const { user } = useAuth();
  if (!user) return <LoginPage />;

  return (
    <Routes>
      <Route element={<AppLayout />}>
        <Route path="/" element={<DashboardPage />} />
        <Route path="/config" element={<ConfigPage />} />
        <Route path="/drivers" element={<DriversPage />} />
        <Route path="/operations" element={<OperationsPage />} />
        <Route path="/operations/:id" element={<JobDetailPage />} />
        <Route path="/ledger" element={<LedgerPage />} />
        <Route path="/fleets" element={<FleetsPage />} />
      </Route>
    </Routes>
  );
}

export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>{children}</AuthProvider>
    </QueryClientProvider>
  );
}

export default function App() {
  return (
    <BrowserRouter future={{ v7_startTransition: true, v7_relativeSplatPath: true }}>
      <AppShell>
        <AppRoutes />
      </AppShell>
    </BrowserRouter>
  );
}
