export const ALIAS_MIN = 3;
export const ALIAS_MAX = 32;
export const URL_MAX = 2048;

const RESERVED = new Set([
  "api", "login", "logout", "register", "signup", "dashboard", "settings", "about", "admin",
  "docs", "health", "static", "assets", "public", "favicon", "robots", "sitemap", "expired",
  "not-found", "404", "stats", "help", "privacy", "terms", "urlku", "www", "app",
]);

/** Client-side mirror of the server rules, for instant feedback. The server stays authoritative. */
export function validateUrl(raw: string): string | null {
  const value = raw.trim();
  if (!value) return "Tempel URL yang mau dipendekkan dulu, ya.";
  if (value.length > URL_MAX) return `URL terlalu panjang (maksimal ${URL_MAX} karakter).`;
  if (/\s/.test(value)) return "URL tidak boleh mengandung spasi.";

  const scheme = /^([a-z][a-z0-9+.-]*):/i.exec(value)?.[1]?.toLowerCase();
  if (!scheme) return "URL harus diawali dengan http:// atau https://.";
  if (scheme !== "http" && scheme !== "https") return "Hanya link http:// dan https:// yang bisa dipendekkan.";

  try {
    const url = new URL(value);
    if (!url.hostname) return "URL harus memiliki domain yang valid.";
  } catch {
    return "Format URL tidak valid.";
  }
  return null;
}

export function validateAlias(raw: string): string | null {
  const value = raw.trim();
  if (!value) return null;
  if (value.length < ALIAS_MIN || value.length > ALIAS_MAX)
    return `Alias harus terdiri dari ${ALIAS_MIN}–${ALIAS_MAX} karakter.`;
  if (!/^[A-Za-z0-9_-]+$/.test(value))
    return "Alias hanya boleh berisi huruf, angka, tanda hubung (-), dan garis bawah (_).";
  if (RESERVED.has(value.toLowerCase())) return `Alias "${value}" tidak bisa dipakai. Coba alias lain.`;
  return null;
}
