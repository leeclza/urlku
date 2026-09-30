import { Link } from "react-router";

export function NotFoundPage() {
  return (
    <div className="mx-auto max-w-md px-4 py-24 text-center">
      <p className="font-mono text-6xl font-extrabold text-brand-600 dark:text-brand-400">404</p>
      <h1 className="mt-4 text-xl font-bold">Halaman tidak ditemukan</h1>
      <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">Sepertinya kamu nyasar. Yuk balik ke beranda.</p>
      <Link to="/" className="btn-primary mt-6">
        Ke beranda
      </Link>
    </div>
  );
}
