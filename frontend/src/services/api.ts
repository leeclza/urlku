import { API_URL } from "../lib/config";
import type { ApiErrorBody, CreateLinkInput, CreatedLink, Link, LinkStats } from "../types/link";

const FALLBACK_MESSAGES: Record<string, string> = {
  INVALID_URL: "URL-nya belum valid. Cek lagi, ya.",
  UNSUPPORTED_SCHEME: "Hanya link http:// dan https:// yang bisa dipendekkan.",
  BLOCKED_HOST: "Alamat tersebut tidak diizinkan.",
  URL_TOO_LONG: "URL terlalu panjang.",
  INVALID_ALIAS: "Alias tidak valid.",
  RESERVED_ALIAS: "Alias tersebut tidak bisa dipakai.",
  CUSTOM_ALIAS_TAKEN: "Alias tersebut sudah digunakan.",
  INVALID_EXPIRATION: "Tanggal kedaluwarsa tidak valid.",
  LINK_NOT_FOUND: "Link tidak ditemukan.",
  FORBIDDEN: "Kamu tidak punya akses untuk link ini.",
  RATE_LIMITED: "Terlalu banyak permintaan. Coba lagi sebentar lagi, ya.",
  NETWORK_ERROR: "Tidak bisa terhubung ke server. Cek koneksi internet kamu.",
  INTERNAL_ERROR: "Terjadi kesalahan di server. Coba lagi nanti.",
};

export class ApiError extends Error {
  readonly code: string;
  readonly status: number;

  constructor(code: string, message: string, status: number) {
    super(message);
    this.name = "ApiError";
    this.code = code;
    this.status = status;
  }
}

async function request<T>(path: string, init: RequestInit = {}): Promise<T> {
  let res: Response;
  try {
    res = await fetch(`${API_URL}${path}`, {
      ...init,
      headers: { Accept: "application/json", ...(init.body ? { "Content-Type": "application/json" } : {}), ...init.headers },
    });
  } catch {
    throw new ApiError("NETWORK_ERROR", FALLBACK_MESSAGES.NETWORK_ERROR!, 0);
  }

  if (res.status === 204) return undefined as T;

  let body: unknown = null;
  try {
    body = await res.json();
  } catch {
    body = null;
  }

  if (!res.ok) {
    const err = (body ?? {}) as Partial<ApiErrorBody>;
    const code = err.error ?? "INTERNAL_ERROR";
    const message = err.message || FALLBACK_MESSAGES[code] || FALLBACK_MESSAGES.INTERNAL_ERROR!;
    throw new ApiError(code, message, res.status);
  }
  return body as T;
}

export const api = {
  createLink: (input: CreateLinkInput) =>
    request<CreatedLink>("/api/links", { method: "POST", body: JSON.stringify(input) }),

  getLink: (code: string) => request<Link>(`/api/links/${encodeURIComponent(code)}`),

  getLinks: async (codes: string[]) => {
    if (codes.length === 0) return [] as Link[];
    const query = encodeURIComponent(codes.join(","));
    const res = await request<{ links: Link[] }>(`/api/links?codes=${query}`);
    return res.links;
  },

  getStats: (code: string) => request<LinkStats>(`/api/links/${encodeURIComponent(code)}/stats`),

  deleteLink: (code: string, manageToken: string) =>
    request<void>(`/api/links/${encodeURIComponent(code)}`, {
      method: "DELETE",
      headers: { "X-Manage-Token": manageToken },
    }),
};

export function errorMessage(error: unknown): string {
  if (error instanceof ApiError) return error.message;
  return FALLBACK_MESSAGES.INTERNAL_ERROR!;
}
