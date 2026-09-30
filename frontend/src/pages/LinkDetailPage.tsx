import { Link as RouterLink, useParams } from "react-router";
import { useQuery } from "@tanstack/react-query";
import { api, ApiError, errorMessage } from "../services/api";
import { formatDateTime, formatNumber, relativeFromNow } from "../lib/format";
import { ClickChart } from "../components/ClickChart";
import { CopyButton } from "../components/CopyButton";
import { StatusBadge } from "../components/StatusBadge";
import { ArrowLeftIcon, ExternalIcon, SpinnerIcon } from "../components/Icons";
import type { CountBucket } from "../types/link";

const DEVICE_LABELS: Record<string, string> = {
  desktop: "Desktop",
  mobile: "Ponsel",
  tablet: "Tablet",
  bot: "Bot",
  lainnya: "Lainnya",
};

function Breakdown({ title, items, labels }: { title: string; items: CountBucket[]; labels?: Record<string, string> }) {
  const total = items.reduce((s, i) => s + i.clicks, 0);
  return (
    <div className="card p-5">
      <h2 className="font-bold">{title}</h2>
      {items.length === 0 ? (
        <p className="mt-3 text-sm text-slate-500 dark:text-slate-400">Belum ada data.</p>
      ) : (
        <ul className="mt-4 space-y-3">
          {items.map((i) => {
            const pct = total ? Math.round((i.clicks / total) * 100) : 0;
            return (
              <li key={i.name}>
                <div className="flex justify-between gap-3 text-sm">
                  <span className="truncate">{labels?.[i.name] ?? i.name}</span>
                  <span className="shrink-0 font-semibold">{formatNumber(i.clicks)}</span>
                </div>
                <div className="mt-1.5 h-1.5 overflow-hidden rounded-full bg-slate-100 dark:bg-slate-800">
                  <div className="h-full rounded-full bg-brand-500 dark:bg-brand-400" style={{ width: `${pct}%` }} />
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}

export function LinkDetailPage() {
  const { shortCode = "" } = useParams();
  const link = useQuery({ queryKey: ["link", shortCode], queryFn: () => api.getLink(shortCode) });
  const stats = useQuery({ queryKey: ["stats", shortCode], queryFn: () => api.getStats(shortCode), enabled: link.isSuccess });

  const back = (
    <RouterLink to="/dashboard" className="inline-flex items-center gap-1.5 text-sm font-semibold text-slate-600 hover:text-ink dark:text-slate-300 dark:hover:text-white">
      <ArrowLeftIcon /> Kembali ke dashboard
    </RouterLink>
  );

  if (link.isPending) {
    return (
      <div className="flex items-center justify-center gap-2 py-24 text-sm text-slate-500">
        <SpinnerIcon /> Memuat...
      </div>
    );
  }

  if (link.isError) {
    const notFound = link.error instanceof ApiError && link.error.status === 404;
    return (
      <div className="mx-auto max-w-xl px-4 py-16 text-center">
        <p className="text-4xl" aria-hidden="true">
          🔍
        </p>
        <h1 className="mt-3 text-xl font-bold">{notFound ? "Link tidak ditemukan" : "Gagal memuat link"}</h1>
        <p className="mt-2 text-sm text-slate-500 dark:text-slate-400">
          {notFound ? "Link ini mungkin sudah dihapus." : errorMessage(link.error)}
        </p>
        <div className="mt-6">{back}</div>
      </div>
    );
  }

  const l = link.data;
  return (
    <div className="mx-auto max-w-4xl px-4 pb-16 pt-8 sm:px-6 sm:pt-12">
      {back}

      <section className="card mt-5 p-5 sm:p-6">
        <div className="flex flex-wrap items-center gap-3">
          <h1 className="break-all font-mono text-2xl font-bold text-brand-700 sm:text-3xl dark:text-brand-300">
            {l.short_url.replace(/^https?:\/\//, "")}
          </h1>
          <StatusBadge status={l.status} />
        </div>
        <p className="mt-2 break-all text-sm text-slate-600 dark:text-slate-300">
          →{" "}
          <a href={l.original_url} target="_blank" rel="noopener noreferrer" className="hover:underline">
            {l.original_url}
          </a>
        </p>
        <div className="mt-4 flex flex-wrap gap-2">
          <CopyButton text={l.short_url} />
          <a href={l.short_url} target="_blank" rel="noopener noreferrer" className="btn-ghost">
            <ExternalIcon /> Buka
          </a>
        </div>

        <dl className="mt-6 grid grid-cols-2 gap-4 border-t border-slate-100 pt-5 text-sm sm:grid-cols-4 dark:border-night-line">
          <div>
            <dt className="text-slate-500 dark:text-slate-400">Total klik</dt>
            <dd className="mt-0.5 text-2xl font-extrabold">{formatNumber(l.click_count)}</dd>
          </div>
          <div>
            <dt className="text-slate-500 dark:text-slate-400">Dibuat</dt>
            <dd className="mt-0.5 font-medium">{formatDateTime(l.created_at)}</dd>
          </div>
          <div>
            <dt className="text-slate-500 dark:text-slate-400">Kedaluwarsa</dt>
            <dd className="mt-0.5 font-medium">{l.expires_at ? formatDateTime(l.expires_at) : "Tidak pernah"}</dd>
          </div>
          <div>
            <dt className="text-slate-500 dark:text-slate-400">Klik terakhir</dt>
            <dd className="mt-0.5 font-medium">{l.last_clicked_at ? relativeFromNow(l.last_clicked_at) : "Belum ada"}</dd>
          </div>
        </dl>
      </section>

      <section className="card mt-5 p-5 sm:p-6">
        <h2 className="font-bold">Klik 30 hari terakhir</h2>
        <div className="mt-4">
          {stats.isSuccess ? (
            <ClickChart data={stats.data.clicks_by_date} />
          ) : stats.isError ? (
            <p className="text-sm text-red-600 dark:text-red-400">{errorMessage(stats.error)}</p>
          ) : (
            <div className="h-40 animate-pulse rounded-xl bg-slate-100 dark:bg-slate-800" />
          )}
        </div>
      </section>

      {stats.isSuccess && (
        <div className="mt-5 grid gap-5 sm:grid-cols-2">
          <Breakdown title="Sumber (referrer)" items={stats.data.referrers} />
          <Breakdown title="Perangkat" items={stats.data.devices} labels={DEVICE_LABELS} />
        </div>
      )}
    </div>
  );
}
