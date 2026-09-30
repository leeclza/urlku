import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { QueryClient, QueryClientProvider } from "@tanstack/react-query";
import { MemoryRouter } from "react-router";
import { HomePage } from "../pages/HomePage";
import { loadSavedLinks } from "../lib/storage";

const created = {
  id: 1,
  short_code: "toko",
  short_url: "http://localhost:3000/toko",
  original_url: "https://example.com/very/long/url",
  created_at: "2026-09-30T12:00:00Z",
  expires_at: null,
  click_count: 0,
  last_clicked_at: null,
  status: "active",
  manage_token: "secret-token-123",
};

function renderHome() {
  const client = new QueryClient({ defaultOptions: { queries: { retry: false }, mutations: { retry: false } } });
  return render(
    <QueryClientProvider client={client}>
      <MemoryRouter>
        <HomePage />
      </MemoryRouter>
    </QueryClientProvider>,
  );
}

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { status, headers: { "Content-Type": "application/json" } });
}

describe("ShortenForm", () => {
  let fetchMock: ReturnType<typeof vi.fn>;

  beforeEach(() => {
    fetchMock = vi.fn();
    vi.stubGlobal("fetch", fetchMock);
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  it("renders the URL form", () => {
    renderHome();
    expect(screen.getByRole("heading", { name: /Link panjang\?/ })).toBeInTheDocument();
    expect(screen.getByPlaceholderText("Tempel URL panjang kamu di sini...")).toBeInTheDocument();
    expect(screen.getByLabelText(/Alias custom/)).toBeInTheDocument();
    expect(screen.getByRole("button", { name: "Pendekin Link" })).toBeInTheDocument();
  });

  it("validates input before calling the API", async () => {
    const user = userEvent.setup();
    renderHome();

    await user.click(screen.getByRole("button", { name: "Pendekin Link" }));
    expect(await screen.findByText("Tempel URL yang mau dipendekkan dulu, ya.")).toBeInTheDocument();

    await user.type(screen.getByPlaceholderText(/Tempel URL/), "javascript:alert(1)");
    await user.click(screen.getByRole("button", { name: "Pendekin Link" }));
    expect(await screen.findByText(/Hanya link http/)).toBeInTheDocument();

    expect(fetchMock).not.toHaveBeenCalled();
  });

  it("shortens a URL and shows the result card", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(created, 201));
    const user = userEvent.setup();
    renderHome();

    await user.type(screen.getByPlaceholderText(/Tempel URL/), "https://example.com/very/long/url");
    await user.type(screen.getByLabelText(/Alias custom/), "toko");
    await user.click(screen.getByRole("button", { name: "Pendekin Link" }));

    expect(await screen.findByText(/Link kamu sudah siap!/)).toBeInTheDocument();
    expect(screen.getByText("localhost:3000/toko")).toBeInTheDocument();
    expect(screen.getByText("https://example.com/very/long/url")).toBeInTheDocument();

    const [url, init] = fetchMock.mock.calls[0]!;
    expect(url).toBe("http://localhost:3000/api/links");
    expect(JSON.parse(init.body)).toEqual({ url: "https://example.com/very/long/url", custom_alias: "toko", expires_at: null });

    expect(loadSavedLinks()).toEqual([{ short_code: "toko", manage_token: "secret-token-123", created_at: created.created_at }]);
  });

  it("shows a clear error when the alias is taken", async () => {
    fetchMock.mockResolvedValueOnce(
      jsonResponse({ error: "CUSTOM_ALIAS_TAKEN", message: "Alias tersebut sudah digunakan." }, 409),
    );
    const user = userEvent.setup();
    renderHome();

    await user.type(screen.getByPlaceholderText(/Tempel URL/), "https://example.com");
    await user.type(screen.getByLabelText(/Alias custom/), "toko");
    await user.click(screen.getByRole("button", { name: "Pendekin Link" }));

    expect(await screen.findByText("Alias tersebut sudah digunakan.")).toBeInTheDocument();
  });

  it("copies the short link and shows feedback", async () => {
    fetchMock.mockResolvedValueOnce(jsonResponse(created, 201));
    const user = userEvent.setup();
    const writeText = vi.fn().mockResolvedValue(undefined);
    Object.defineProperty(navigator, "clipboard", { value: { writeText }, configurable: true });
    renderHome();

    await user.type(screen.getByPlaceholderText(/Tempel URL/), "https://example.com/very/long/url");
    await user.click(screen.getByRole("button", { name: "Pendekin Link" }));
    await user.click(await screen.findByRole("button", { name: /Salin/ }));

    expect(writeText).toHaveBeenCalledWith("http://localhost:3000/toko");
    await waitFor(() => expect(screen.getByRole("button", { name: /Tersalin!/ })).toBeInTheDocument());
  });
});
