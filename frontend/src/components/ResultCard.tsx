import { Link as RouterLink } from "react-router";
import type { CreatedLink } from "../types/link";
import { formatDateTime, formatNumber } from "../lib/format";
import { CopyButton } from "./CopyButton";
import { ChartIcon, ExternalIcon } from "./Icons";

export function ResultCard({ link }: { link: CreatedLink }) {
  const display = link.short_url.replace(/^https?:\/\//, "");

  return (
    <section aria-live="polite" className="card animate-pop-in mt-6 overflow-hidden">
      <div className="border-b border-slate-100 bg-emerald-50/60 px-5 py-3 text-sm font-semibold text-emerald-700 dark:border-night-line dark:bg-emerald-500/10 dark:text-emerald-400">
        🎉 Link kamu sudah siap!
      </div>
      <div className="p-5">
        <a
          href={link.short_url}
          target="_blank"
          rel="noopener noreferrer"
          className="block break-all font-mono text-xl font-semibold text-brand-700 hover:underline sm:text-2xl dark:text-brand-300"
        >
          {display}
        </a>

        <div className="mt-4 flex flex-wrap gap-2">
          <CopyButton text={link.short_url} />
          <a href={link.short_url} target="_blank" rel="noopener noreferrer" className="btn-ghost">
            <ExternalIcon /> Buka
          </a>
          <RouterLink to={`/dashboard/${encodeURIComponent(link.short_code)}`} className="btn-ghost">
            <ChartIcon /> Statistik
          </RouterLink>
        </div>

        <dl className="mt-5 grid gap-3 text-sm sm:grid-cols-[auto_1fr] sm:gap-x-6">
          <dt className="text-slate-500 dark:text-slate-400">URL asli</dt>
          <dd className="break-all text-slate-700 dark:text-slate-200">{link.original_url}</dd>
          <dt className="text-slate-500 dark:text-slate-400">Klik</dt>
          <dd className="font-semibold">{formatNumber(link.click_count)}</dd>
          <dt className="text-slate-500 dark:text-slate-400">Berlaku sampai</dt>
          <dd>{link.expires_at ? formatDateTime(link.expires_at) : "Selamanya"}</dd>
        </dl>
      </div>
    </section>
  );
}
