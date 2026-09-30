import { useMemo, useState } from "react";
import { Link as RouterLink } from "react-router";
import { useMutation, useQuery, useQueryClient } from "@tanstack/react-query";
import { api, ApiError, errorMessage } from "../services/api";
import { useSavedLinks } from "../hooks/useSavedLinks";
import { findSavedLink, removeSavedLink } from "../lib/storage";
import { formatNumber, prettyUrl } from "../lib/format";
import { CopyButton } from "../components/CopyButton";
import { StatusBadge } from "../components/StatusBadge";
import { ChartIcon, ExternalIcon, SpinnerIcon, TrashIcon } from "../components/Icons";
import type { Link } from "../types/link";

function StatCard({ label, value, tone = "default" }: { label: string; value: number; tone?: "default" | "success" | "muted" }) {
  const color =
    tone === "success" ? "text-emerald-600 dark:text-emerald-400" : tone === "muted" ? "text-slate-500 dark:text-slate-400" : "";
  return (
    <div className="card p-4 sm:p-5">
      <p className="text-xs font-medium text-slate-500 sm:text-sm dark:text-slate-400">{label}</p>
      <p className={`mt-1 text-2xl font-extrabold tracking-tight sm:text-3xl ${color}`}>{formatNumber(value)}</p>
    </div>
  );
}

function DeleteButton({ link }: { link: Link }) {
  const queryClient = useQueryClient();
  const [error, setError] = useState<string | null>(null);
  const mutation = useMutation({
    mutationFn: () => {
      const saved = findSavedLink(link.short_code);
      if (!saved) throw new ApiError("FORBIDDEN", "Link ini tidak dibuat di browser ini.", 403);
      return api.deleteLink(link.short_code, saved.manage_token);
    },
    onSuccess: () => {
      removeSavedLink(link.short_code);
      void queryClient.invalidateQueries({ queryKey: ["links"] });
    },
    onError: (e) => setError(errorMessage(e)),
  });

  return (
    <>
      <button
        type="button"
        className="btn-danger !px-3 !py-2"
        disabled={mutation.isPending}
        onClick={() => {
          if (window.confirm(`Hapus link /${link.short_code}? Link ini tidak akan bisa dibuka lagi.`)) mutation.mutate();
        }}
        aria-label={`Hapus /${link.short_code}`}
      >
        {mutation.isPending ? <SpinnerIcon /> : <TrashIcon />}
        <span className="hidden sm:inline">Hapus</span>
      </button>
      {error && (
        <span role="alert" className="basis-full text-xs text-red-600 dark:text-red-400">
          {error}
        </span>
      )}
    </>
  );
}

function LinkRow({ link }: { link: Link }) {
  return (
    <li className="flex flex-col gap-3 p-4 sm:grid sm:grid-cols-[minmax(0,1.1fr)_minmax(0,1.4fr)_4rem_7rem] sm:items-center sm:gap-4 sm:px-5">
      <div className="min-w-0">
        <a
          href={link.short_url}
          target="_blank"
          rel="noopener noreferrer"
          className="block truncate font-mono font-semibold text-brand-700 hover:underline dark:text-brand-300"
        >
          /{link.short_code}
        </a>
        <p className="truncate text-sm text-slate-500 sm:hidden dark:text-slate-400">{prettyUrl(link.original_url, 40)}</p>
      </div>
      <p className="hidden truncate text-sm text-slate-600 sm:block dark:text-slate-300" title={link.original_url}>
        {prettyUrl(link.original_url)}
      </p>
      <p className="text-sm font-semibold sm:text-right">
        <span className="sm:hidden text-slate-500 font-normal dark:text-slate-400">Klik: </span>
        {formatNumber(link.click_count)}
      </p>
      <div className="flex items-center justify-between gap-2 sm:justify-end">
        <StatusBadge status={link.status} />
      </div>
      <div className="flex flex-wrap gap-2 sm:col-span-4 sm:justify-end">
        <CopyButton text={link.short_url} variant="ghost" compact />
        <a href={link.short_url} target="_blank" rel="noopener noreferrer" className="btn-ghost !px-3 !py-2">
          <ExternalIcon /> <span className="hidden sm:inline">Buka</span>
        </a>
        <RouterLink to={`/dashboard/${encodeURIComponent(link.short_code)}`} className="btn-ghost !px-3 !py-2">
          <ChartIcon /> <span className="hidden sm:inline">Statistik</span>
        </RouterLink>
        <DeleteButton link={link} />
      </div>
    </li>
  );
}

export function DashboardPage() {
  const saved = useSavedLinks();
  const codes = useMemo(() => saved.map((s) => s.short_code), [saved]);

  const query = useQuery({
    queryKey: ["links", codes],
    queryFn: () => api.getLinks(codes),
    enabled: codes.length > 0,
  });

  const links = query.data ?? [];
  const totals = {
    links: links.length,
    clicks: links.reduce((s, l) => s + l.click_count, 0),
    active: links.filter((l) => l.status === "active").length,
    expired: links.filter((l) => l.status === "expired").length,
  };

  return (
    <div className="mx-auto max-w-5xl px-4 pb-16 pt-8 sm:px-6 sm:pt-12">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="text-2xl font-extrabold tracking-tight sm:text-3xl">Dashboard</h1>
          <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">Link yang kamu buat dari browser ini.</p>
        </div>
        <RouterLink to="/" className="btn-primary">
          + Link baru
        </RouterLink>
      </div>

      <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-4 sm:gap-4">
        <StatCard label="Total link" value={totals.links} />
        <StatCard label="Total klik" value={totals.clicks} />
        <StatCard label="Link aktif" value={totals.active} tone="success" />
        <StatCard label="Link kedaluwarsa" value={totals.expired} tone="muted" />
      </div>

      <section className="card mt-6 overflow-hidden">
        <div className="hidden border-b border-slate-100 px-5 py-3 text-xs font-semibold uppercase tracking-wide text-slate-500 sm:grid sm:grid-cols-[minmax(0,1.1fr)_minmax(0,1.4fr)_4rem_7rem] sm:gap-4 dark:border-night-line dark:text-slate-400">
          <span>Link pendek</span>
          <span>URL asli</span>
          <span className="text-right">Klik</span>
          <span className="text-right">Status</span>
        </div>

        {codes.length === 0 ? (
          <div className="px-6 py-14 text-center">
            <p className="text-4xl" aria-hidden="true">
              🔗
            </p>
            <p className="mt-3 font-semibold">Belum ada link</p>
            <p className="mt-1 text-sm text-slate-500 dark:text-slate-400">Link yang kamu pendekkan akan muncul di sini.</p>
            <RouterLink to="/" className="btn-primary mt-5">
              Pendekin link pertama
            </RouterLink>
          </div>
        ) : query.isPending ? (
          <div className="flex items-center justify-center gap-2 py-14 text-sm text-slate-500">
            <SpinnerIcon /> Memuat link...
          </div>
        ) : query.isError ? (
          <div role="alert" className="px-6 py-10 text-center text-sm text-red-600 dark:text-red-400">
            {errorMessage(query.error)}
            <div>
              <button type="button" onClick={() => void query.refetch()} className="btn-ghost mt-4">
                Coba lagi
              </button>
            </div>
          </div>
        ) : (
          <ul className="divide-y divide-slate-100 dark:divide-night-line">
            {links.map((l) => (
              <LinkRow key={l.short_code} link={l} />
            ))}
          </ul>
        )}
      </section>
    </div>
  );
}
