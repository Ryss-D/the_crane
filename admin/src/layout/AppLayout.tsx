import { NavLink, Outlet } from 'react-router-dom';
import { useAuth } from '../auth';
import { strings } from '../i18n/strings';

const navItems = [
  { to: '/', label: strings.nav.dashboard, end: true },
  { to: '/config', label: strings.nav.config, end: false },
  { to: '/drivers', label: strings.nav.drivers, end: false },
  { to: '/operations', label: strings.nav.operations, end: false },
  { to: '/ledger', label: strings.nav.ledger, end: false },
  { to: '/fleets', label: strings.nav.fleets, end: false },
] as const;

function Sidebar() {
  return (
    <aside className="flex w-56 shrink-0 flex-col gap-1 border-r border-slate-800 bg-slate-950 p-3">
      <div className="mb-4 px-2">
        <p className="text-base font-black tracking-tight text-amber-400">{strings.appName}</p>
        <p className="text-xs text-slate-500">{strings.panelName}</p>
      </div>
      <nav className="flex flex-col gap-0.5">
        {navItems.map((item) => (
          <NavLink
            key={item.to}
            to={item.to}
            end={item.end}
            className={({ isActive }) =>
              `rounded-md px-3 py-2 text-sm font-medium transition-colors ${
                isActive
                  ? 'bg-amber-500/10 text-amber-400'
                  : 'text-slate-400 hover:bg-slate-900 hover:text-slate-200'
              }`
            }
          >
            {item.label}
          </NavLink>
        ))}
      </nav>
    </aside>
  );
}

function Topbar() {
  const { user, signOut } = useAuth();
  return (
    <header className="flex h-14 shrink-0 items-center justify-between border-b border-slate-800 bg-slate-950/80 px-4 backdrop-blur">
      <div />
      <div className="flex items-center gap-3">
        {user && <span className="text-sm text-slate-400">{user.email}</span>}
        <button
          type="button"
          onClick={() => void signOut()}
          className="text-xs font-semibold text-slate-400 hover:text-slate-200"
        >
          {strings.auth.signOut}
        </button>
      </div>
    </header>
  );
}

export function AppLayout() {
  return (
    <div className="flex min-h-dvh bg-slate-950 text-slate-100">
      <Sidebar />
      <div className="flex min-w-0 flex-1 flex-col">
        <Topbar />
        <main className="min-w-0 flex-1 overflow-x-auto p-6">
          <Outlet />
        </main>
      </div>
    </div>
  );
}
