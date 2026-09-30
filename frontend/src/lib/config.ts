const trimSlash = (value: string) => value.replace(/\/+$/, "");

export const API_URL = trimSlash(import.meta.env.VITE_API_URL ?? "http://localhost:3000");
export const BASE_URL = trimSlash(import.meta.env.VITE_BASE_URL ?? API_URL);

/** "http://localhost:3000" → "localhost:3000", "https://urlku.com" → "urlku.com" */
export const BASE_HOST = BASE_URL.replace(/^https?:\/\//, "");
