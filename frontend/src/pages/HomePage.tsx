import { useState } from "react";
import { ShortenForm } from "../components/ShortenForm";
import { ResultCard } from "../components/ResultCard";
import type { CreatedLink } from "../types/link";

const FEATURES = [
  { title: "Alias sendiri", body: "Pakai nama yang gampang diingat, misalnya /toko atau /promo-akhir-bulan." },
  { title: "Masa berlaku", body: "Atur link supaya otomatis kedaluwarsa setelah 1, 7, 30 hari, atau tanggal pilihanmu." },
  { title: "Statistik klik", body: "Lihat berapa kali link diklik, dari mana, dan pakai perangkat apa." },
];

export function HomePage() {
  const [created, setCreated] = useState<CreatedLink | null>(null);

  return (
    <div className="mx-auto max-w-2xl px-4 pb-16 pt-10 sm:px-6 sm:pt-20">
      <section className="text-center">
        <p className="mx-auto mb-5 inline-flex items-center gap-2 rounded-full border border-brand-100 bg-brand-50 px-3 py-1 text-xs font-semibold text-brand-700 dark:border-brand-500/20 dark:bg-brand-500/10 dark:text-brand-300">
          Gratis · Tanpa daftar
        </p>
        <h1 className="text-4xl font-extrabold leading-[1.1] tracking-tight sm:text-6xl">
          Link panjang?
          <br />
          <span className="relative inline-block text-brand-600 dark:text-brand-400">
            Pendekin aja.
            <svg aria-hidden="true" viewBox="0 0 220 12" className="absolute -bottom-2 left-0 w-full text-brand-200 dark:text-brand-500/40" preserveAspectRatio="none">
              <path d="M2 9c40-6 150-8 216-3" fill="none" stroke="currentColor" strokeWidth="4" strokeLinecap="round" />
            </svg>
          </span>
        </h1>
        <p className="mx-auto mt-6 max-w-md text-base text-slate-600 sm:text-lg dark:text-slate-300">
          Bikin link singkat, mudah dibagikan, dan gampang diingat.
        </p>
      </section>

      <div className="mt-10">
        <ShortenForm onCreated={setCreated} />
        {created && <ResultCard key={created.short_code} link={created} />}
      </div>

      <section className="mt-16 grid gap-4 sm:grid-cols-3">
        {FEATURES.map((f) => (
          <div key={f.title} className="rounded-2xl p-1">
            <h2 className="font-bold">{f.title}</h2>
            <p className="mt-1 text-sm leading-relaxed text-slate-600 dark:text-slate-400">{f.body}</p>
          </div>
        ))}
      </section>
    </div>
  );
}
