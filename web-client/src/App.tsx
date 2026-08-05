import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { BrowserRouter, Link, Route, Routes } from 'react-router-dom';
import { AuthProvider, useAuth } from './auth';
import { RequestPage } from './features/request/RequestPage';
import { ShareTrackPage } from './features/tracking/ShareTrackPage';
import { TrackingPage } from './features/tracking/TrackingPage';
import { strings } from './i18n/strings';

const queryClient = new QueryClient({
  defaultOptions: {
    queries: { retry: 1, refetchOnWindowFocus: false },
  },
});

function Header() {
  const { user, signOut } = useAuth();
  return (
    <header className="border-b border-slate-800 bg-slate-950/80 backdrop-blur">
      <div className="mx-auto flex max-w-md items-center justify-between px-4 py-3">
        <Link to="/" className="flex items-baseline gap-2">
          <span className="text-lg font-black tracking-tight text-amber-400">
            {strings.appName}
          </span>
          <span className="hidden text-xs text-slate-500 sm:inline">{strings.tagline}</span>
        </Link>
        {user && (
          <button
            type="button"
            onClick={() => void signOut()}
            className="text-xs font-semibold text-slate-400 hover:text-slate-200"
          >
            {strings.auth.signOut}
          </button>
        )}
      </div>
    </header>
  );
}

export function AppRoutes() {
  return (
    <Routes>
      <Route path="/" element={<RequestPage />} />
      <Route path="/jobs/:id" element={<TrackingPage />} />
      {/* Public share-track — no auth (WEB-4 skeleton). */}
      <Route path="/t/:token" element={<ShareTrackPage />} />
    </Routes>
  );
}

export function AppShell({ children }: { children: React.ReactNode }) {
  return (
    <QueryClientProvider client={queryClient}>
      <AuthProvider>
        <div className="min-h-dvh bg-slate-950 text-slate-100">
          <Header />
          <main className="mx-auto max-w-md px-4 py-4">{children}</main>
        </div>
      </AuthProvider>
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
