import { useId, useState, type FormEvent } from "react";
import { useMutation } from "@tanstack/react-query";
import { api, errorMessage } from "../services/api";
import { BASE_HOST } from "../lib/config";
import { ALIAS_MAX, validateAlias, validateUrl } from "../lib/validation";
import { saveLink } from "../lib/storage";
import type { CreatedLink } from "../types/link";
import { SpinnerIcon } from "./Icons";

type Expiry = "never" | "1" | "7" | "30" | "custom";

const EXPIRY_OPTIONS: { value: Expiry; label: string }[] = [
  { value: "never", label: "Tidak pernah" },
  { value: "1", label: "1 hari" },
  { value: "7", label: "7 hari" },
  { value: "30", label: "30 hari" },
  { value: "custom", label: "Custom" },
];

function toLocalInputValue(date: Date) {
  const pad = (n: number) => String(n).padStart(2, "0");
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`;
}

function computeExpiresAt(expiry: Expiry, custom: string): { value: string | null; error?: string } {
  if (expiry === "never") return { value: null };
  if (expiry === "custom") {
    if (!custom) return { value: null, error: "Pilih tanggal dan jam kedaluwarsa." };
    const date = new Date(custom);
    if (Number.isNaN(date.getTime())) return { value: null, error: "Tanggal kedaluwarsa tidak valid." };
    if (date.getTime() <= Date.now()) return { value: null, error: "Tanggal kedaluwarsa harus di masa depan." };
    return { value: date.toISOString().replace(/\.\d{3}Z$/, "Z") };
  }
  const date = new Date(Date.now() + Number(expiry) * 24 * 60 * 60 * 1000);
  return { value: date.toISOString().replace(/\.\d{3}Z$/, "Z") };
}

interface Props {
  onCreated: (link: CreatedLink) => void;
}

export function ShortenForm({ onCreated }: Props) {
  const ids = { url: useId(), alias: useId(), expiry: useId(), custom: useId() };
  const [url, setUrl] = useState("");
  const [alias, setAlias] = useState("");
  const [expiry, setExpiry] = useState<Expiry>("never");
  const [customDate, setCustomDate] = useState("");
  const [fieldErrors, setFieldErrors] = useState<{ url?: string; alias?: string; expiry?: string }>({});

  const mutation = useMutation({
    mutationFn: api.createLink,
    onSuccess: (link) => {
      saveLink({ short_code: link.short_code, manage_token: link.manage_token, created_at: link.created_at });
      onCreated(link);
      setUrl("");
      setAlias("");
    },
    onError: (error) => {
      const code = (error as { code?: string }).code;
      if (code === "CUSTOM_ALIAS_TAKEN" || code === "INVALID_ALIAS" || code === "RESERVED_ALIAS") {
        setFieldErrors({ alias: errorMessage(error) });
      } else if (code === "INVALID_EXPIRATION") {
        setFieldErrors({ expiry: errorMessage(error) });
      } else if (code && ["INVALID_URL", "UNSUPPORTED_SCHEME", "BLOCKED_HOST", "URL_TOO_LONG"].includes(code)) {
        setFieldErrors({ url: errorMessage(error) });
      }
    },
  });

  const submit = (e: FormEvent) => {
    e.preventDefault();
    const urlError = validateUrl(url) ?? undefined;
    const aliasError = validateAlias(alias) ?? undefined;
    const expires = computeExpiresAt(expiry, customDate);
    const errors = { url: urlError, alias: aliasError, expiry: expires.error };
    setFieldErrors(errors);
    if (urlError || aliasError || expires.error) return;

    mutation.mutate({
      url: url.trim(),
      custom_alias: alias.trim() || null,
      expires_at: expires.value,
    });
  };

  const generalError =
    mutation.isError && !fieldErrors.url && !fieldErrors.alias && !fieldErrors.expiry ? errorMessage(mutation.error) : null;

  return (
    <form onSubmit={submit} noValidate className="card p-4 sm:p-6">
      <label htmlFor={ids.url} className="sr-only">
        URL panjang
      </label>
      <input
        id={ids.url}
        type="url"
        inputMode="url"
        autoComplete="off"
        autoCapitalize="off"
        spellCheck={false}
        placeholder="Tempel URL panjang kamu di sini..."
        value={url}
        onChange={(e) => {
          setUrl(e.target.value);
          if (fieldErrors.url) setFieldErrors((f) => ({ ...f, url: undefined }));
        }}
        aria-invalid={!!fieldErrors.url}
        aria-describedby={fieldErrors.url ? `${ids.url}-err` : undefined}
        className={`input h-14 text-base sm:text-lg ${fieldErrors.url ? "!border-red-400 focus:!ring-red-500/15" : ""}`}
      />
      {fieldErrors.url && (
        <p id={`${ids.url}-err`} role="alert" className="mt-2 text-sm text-red-600 dark:text-red-400">
          {fieldErrors.url}
        </p>
      )}

      <div className="mt-4 grid gap-4 sm:grid-cols-[1fr_auto]">
        <div>
          <label htmlFor={ids.alias} className="mb-1.5 block text-sm font-medium text-slate-600 dark:text-slate-300">
            Alias custom <span className="font-normal text-slate-400">(opsional)</span>
          </label>
          <div
            className={`flex items-center overflow-hidden rounded-xl border bg-white transition focus-within:ring-4 dark:bg-night ${
              fieldErrors.alias
                ? "border-red-400 focus-within:ring-red-500/15"
                : "border-slate-200 focus-within:border-brand-500 focus-within:ring-brand-500/15 dark:border-night-line"
            }`}
          >
            <span className="shrink-0 select-none border-r border-slate-200 bg-slate-50 px-3 py-3 font-mono text-sm text-slate-500 dark:border-night-line dark:bg-night-card dark:text-slate-400">
              {BASE_HOST}/
            </span>
            <input
              id={ids.alias}
              type="text"
              autoComplete="off"
              autoCapitalize="off"
              spellCheck={false}
              maxLength={ALIAS_MAX}
              placeholder="toko-kamu"
              value={alias}
              onChange={(e) => {
                setAlias(e.target.value.replace(/\s/g, ""));
                if (fieldErrors.alias) setFieldErrors((f) => ({ ...f, alias: undefined }));
              }}
              aria-invalid={!!fieldErrors.alias}
              aria-describedby={fieldErrors.alias ? `${ids.alias}-err` : undefined}
              className="min-w-0 flex-1 bg-transparent px-3 py-3 font-mono text-sm outline-none placeholder:text-slate-400 dark:placeholder:text-slate-500"
            />
          </div>
          {fieldErrors.alias && (
            <p id={`${ids.alias}-err`} role="alert" className="mt-2 text-sm text-red-600 dark:text-red-400">
              {fieldErrors.alias}
            </p>
          )}
        </div>

        <div className="sm:w-44">
          <label htmlFor={ids.expiry} className="mb-1.5 block text-sm font-medium text-slate-600 dark:text-slate-300">
            Masa berlaku
          </label>
          <select
            id={ids.expiry}
            value={expiry}
            onChange={(e) => {
              const next = e.target.value as Expiry;
              setExpiry(next);
              setFieldErrors((f) => ({ ...f, expiry: undefined }));
              if (next === "custom" && !customDate) {
                setCustomDate(toLocalInputValue(new Date(Date.now() + 3 * 24 * 60 * 60 * 1000)));
              }
            }}
            className="input !py-3 text-sm"
          >
            {EXPIRY_OPTIONS.map((o) => (
              <option key={o.value} value={o.value}>
                {o.label}
              </option>
            ))}
          </select>
        </div>
      </div>

      {expiry === "custom" && (
        <div className="mt-4 animate-pop-in">
          <label htmlFor={ids.custom} className="mb-1.5 block text-sm font-medium text-slate-600 dark:text-slate-300">
            Kedaluwarsa pada
          </label>
          <input
            id={ids.custom}
            type="datetime-local"
            value={customDate}
            min={toLocalInputValue(new Date())}
            onChange={(e) => setCustomDate(e.target.value)}
            className="input text-sm"
          />
        </div>
      )}
      {fieldErrors.expiry && (
        <p role="alert" className="mt-2 text-sm text-red-600 dark:text-red-400">
          {fieldErrors.expiry}
        </p>
      )}

      {generalError && (
        <div role="alert" className="mt-4 rounded-xl bg-red-50 px-4 py-3 text-sm text-red-700 dark:bg-red-950/40 dark:text-red-300">
          {generalError}
        </div>
      )}

      <button type="submit" disabled={mutation.isPending} className="btn-primary mt-5 h-12 w-full text-base">
        {mutation.isPending ? (
          <>
            <SpinnerIcon /> Memendekkan...
          </>
        ) : (
          "Pendekin Link"
        )}
      </button>
    </form>
  );
}
