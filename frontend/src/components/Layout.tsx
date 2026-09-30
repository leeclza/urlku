import { Link, NavLink, Outlet } from "react-router";
import { useTheme } from "../hooks/useTheme";
import { Logo } from "./Logo";
import { MoonIcon, SunIcon } from "./Icons";

export function Layout() {
  const { theme, toggle } = useTheme();

  return (
    <div className="flex min-h-screen flex-col">
      <header className="sticky top-0 z-20 border-b border-transparent bg-slate-50/80 backdrop-blur supports-[backdrop-filter]:bg-slate-50/70 dark:bg-night/80">
        <div className="mx-auto flex h-16 max-w-5xl items-center justify-between px-4 sm:px-6">
          <Link to="/" aria-label="URLKU beranda" className="rounded-lg focus-visible:outline-none focus-visible:ring-4 focus-visible:ring-brand-500/25">
            <Logo />
          </Link>
          <nav className="flex items-center gap-1 sm:gap-2">
            <NavLink
              to="/dashboard"
              className={({ isActive }) =>
                `rounded-lg px-3 py-2 text-sm font-semibold transition ${
                  isActive
                    ? "text-brand-700 dark:text-brand-300"
                    : "text-slate-600 hover:text-ink dark:text-slate-300 dark:hover:text-white"
                }`
              }
            >
              Dashboard
            </NavLink>
            <button
              type="button"
              onClick={toggle}
              className="grid h-9 w-9 place-items-center rounded-lg text-slate-600 transition hover:bg-slate-200/60 dark:text-slate-300 dark:hover:bg-slate-800"
              aria-label={theme === "dark" ? "Ganti ke mode terang" : "Ganti ke mode gelap"}
              title={theme === "dark" ? "Mode terang" : "Mode gelap"}
            >
              {theme === "dark" ? <SunIcon /> : <MoonIcon />}
            </button>
          </nav>
        </div>
      </header>

      <main className="flex-1">
        <Outlet />
      </main>

      <footer className="border-t border-slate-200/70 py-6 text-center text-sm text-slate-500 dark:border-night-line dark:text-slate-400">
        Dibuat dengan ☕ di Indonesia · URLKU
      </footer>
    </div>
  );
}
