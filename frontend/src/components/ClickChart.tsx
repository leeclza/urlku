import { formatNumber } from "../lib/format";

interface Props {
  data: { date: string; clicks: number }[];
}

const shortDate = new Intl.DateTimeFormat("id-ID", { day: "numeric", month: "short" });

/** Lightweight bar chart (no chart library): clicks per day. */
export function ClickChart({ data }: Props) {
  const max = Math.max(1, ...data.map((d) => d.clicks));
  const total = data.reduce((sum, d) => sum + d.clicks, 0);

  if (total === 0) {
    return (
      <div className="grid h-40 place-items-center rounded-xl border border-dashed border-slate-200 text-sm text-slate-500 dark:border-night-line dark:text-slate-400">
        Belum ada klik dalam {data.length} hari terakhir.
      </div>
    );
  }

  return (
    <figure>
      <div className="flex h-40 items-end gap-[3px]" role="img" aria-label={`Grafik klik ${data.length} hari terakhir, total ${total} klik`}>
        {data.map((d) => {
          const label = `${shortDate.format(new Date(`${d.date}T00:00:00Z`))}: ${formatNumber(d.clicks)} klik`;
          return (
            <div key={d.date} className="group relative flex h-full flex-1 items-end" title={label}>
              <div
                className={`w-full rounded-t-[3px] transition-colors ${
                  d.clicks > 0 ? "bg-brand-500 group-hover:bg-brand-600 dark:bg-brand-400" : "bg-slate-200 dark:bg-slate-800"
                }`}
                style={{ height: d.clicks > 0 ? `${Math.max(6, (d.clicks / max) * 100)}%` : "3px" }}
              />
            </div>
          );
        })}
      </div>
      <figcaption className="mt-2 flex justify-between text-xs text-slate-500 dark:text-slate-400">
        <span>{data[0] && shortDate.format(new Date(`${data[0].date}T00:00:00Z`))}</span>
        <span>Hari ini</span>
      </figcaption>
    </figure>
  );
}
