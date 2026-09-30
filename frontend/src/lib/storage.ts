/**
 * Links created in this browser, with their management token.
 * URLKU has no accounts yet, so the dashboard is "links made on this device".
 */
export interface SavedLink {
  short_code: string;
  manage_token: string;
  created_at: string;
}

const KEY = "urlku:links";
const MAX = 100;

export function loadSavedLinks(): SavedLink[] {
  try {
    const raw = localStorage.getItem(KEY);
    const parsed: unknown = raw ? JSON.parse(raw) : [];
    if (!Array.isArray(parsed)) return [];
    return parsed.filter(
      (l): l is SavedLink =>
        typeof l?.short_code === "string" && typeof l?.manage_token === "string" && typeof l?.created_at === "string",
    );
  } catch {
    return [];
  }
}

function write(links: SavedLink[]) {
  try {
    localStorage.setItem(KEY, JSON.stringify(links.slice(0, MAX)));
    window.dispatchEvent(new Event("urlku:links-changed"));
  } catch {
    /* storage unavailable (private mode) — dashboard just stays empty */
  }
}

export function saveLink(link: SavedLink) {
  write([link, ...loadSavedLinks().filter((l) => l.short_code !== link.short_code)]);
}

export function removeSavedLink(code: string) {
  write(loadSavedLinks().filter((l) => l.short_code !== code));
}

export function findSavedLink(code: string): SavedLink | undefined {
  return loadSavedLinks().find((l) => l.short_code === code);
}
