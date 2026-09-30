# URLKU

> **Link panjang? Pendekin aja.**
> Bikin link singkat, mudah dibagikan, dan gampang diingat.

URLKU adalah layanan pemendek URL (URL shortener). Kamu tempel URL panjang, lalu URLKU memberimu link pendek seperti `https://urlku.com/a8K2x`, atau alias pilihanmu sendiri seperti `https://urlku.com/toko`. Setiap klik tercatat, jadi kamu bisa melihat statistik sederhana.

- **Backend:** Crystal + Kemal (REST API + redirect)
- **Frontend:** React + Vite + TypeScript + Tailwind CSS (SPA)
- **Database:** SQLite (development), siap pindah ke PostgreSQL (production)

---

## Daftar isi

1. [SKPL singkat](#1-skpl-singkat)
2. [Fitur](#2-fitur)
3. [Tech stack](#3-tech-stack)
4. [Arsitektur](#4-arsitektur)
5. [Cara setup & menjalankan](#5-cara-setup--menjalankan)
6. [Environment variables](#6-environment-variables)
7. [Testing](#7-testing)
8. [Dokumentasi API](#8-dokumentasi-api)
9. [Deployment production](#9-deployment-production)
10. [Rencana pengembangan](#10-rencana-pengembangan)

---

## 1. SKPL singkat

*Spesifikasi Kebutuhan Perangkat Lunak.*

### 1.1 Tujuan
Menyediakan layanan web untuk mengubah URL panjang menjadi link pendek yang mudah dibagikan, dengan opsi alias sendiri, masa berlaku, dan statistik klik.

### 1.2 Lingkup
- Aplikasi web (SPA) berbahasa Indonesia untuk membuat dan mengelola link.
- REST API untuk membuat, melihat, menghapus link, dan mengambil statistik.
- Endpoint redirect `GET /:short_code` yang mengarahkan pengunjung ke URL asli.
- Belum ada sistem akun. Link dikelola per browser lewat *manage token* (lihat 1.5).

### 1.3 Pengguna
| Pengguna | Kebutuhan |
|---|---|
| Pengguna umum | Memendekkan link untuk dibagikan di chat atau media sosial |
| Pelaku usaha / kreator | Link bermerek (`/toko`, `/promo`) dan jumlah klik |
| Developer | Integrasi lewat REST API JSON |
| Pengunjung link | Diarahkan dengan cepat ke tujuan, atau diberi tahu kalau link sudah kedaluwarsa |

### 1.4 Kebutuhan fungsional
| Kode | Kebutuhan |
|---|---|
| FR-01 | Sistem menerima URL `http`/`https` dan menghasilkan kode pendek acak (7 karakter, kriptografis, tahan tabrakan). |
| FR-02 | Pengguna bisa memilih alias sendiri: 3–32 karakter, hanya `a-z A-Z 0-9 - _`, unik, dan bukan rute cadangan (`api`, `login`, `register`, `dashboard`, `settings`, `about`, `admin`, `docs`, `health`, dll). |
| FR-03 | Pengguna bisa mengatur masa berlaku: tidak pernah, 1 hari, 7 hari, 30 hari, atau tanggal custom. |
| FR-04 | `GET /:short_code` melakukan redirect HTTP 302 ke URL asli dan menambah jumlah klik. |
| FR-05 | Link yang kedaluwarsa tidak di-redirect dan menampilkan halaman "Link ini sudah kedaluwarsa." (HTTP 410). Kode yang tidak dikenal menampilkan halaman 404. |
| FR-06 | Sistem mencatat total klik, `created_at`, `expires_at`, `last_clicked_at`, klik per hari, host referrer, dan kategori perangkat. |
| FR-07 | Dashboard menampilkan total link, total klik, link aktif, link kedaluwarsa, dan daftar link dengan aksi Salin / Buka / Statistik / Hapus. |
| FR-08 | Halaman detail link menampilkan informasi link dan grafik klik 30 hari terakhir. |
| FR-09 | Link hanya bisa dihapus oleh pembuatnya (lewat manage token). |
| FR-10 | UI mendukung mode terang/gelap, dan pilihannya disimpan di `localStorage`. |

### 1.5 Kebutuhan non-fungsional
| Kode | Kebutuhan |
|---|---|
| NFR-01 **Keamanan** | Hanya skema `http`/`https` (menolak `javascript:`, `data:`, `file:`, `ftp:`, dll). Menolak host lokal/privat (anti-SSRF & open-redirect abuse), URL dengan kredensial, karakter kontrol, dan URL > 2048 karakter. URL tujuan **tidak** di-request oleh server. SQL selalu memakai parameter binding. HTML di-escape. CORS berbasis allow-list. Ada security header dan batas body 16 KB. |
| NFR-02 **Rate limiting** | Pembuatan link maksimal 20 request/menit per client, endpoint API lain 120/menit. Implementasinya in-memory di balik interface `RateLimiter` supaya bisa diganti Redis. |
| NFR-03 **Privasi** | IP tidak disimpan. User-Agent hanya disimpan sebagai kategori (`desktop`/`mobile`/`tablet`/`bot`/`lainnya`), referrer hanya host-nya. |
| NFR-04 **Konsistensi error** | Semua error API berformat `{"error": "KODE", "message": "Pesan bahasa Indonesia"}` tanpa stack trace. |
| NFR-05 **Portabilitas DB** | Satu kode repository untuk SQLite dan PostgreSQL (dialect dipilih dari `DATABASE_URL`). |
| NFR-06 **Responsif** | Mobile-first, bisa dipakai di ponsel, tablet, dan desktop. |
| NFR-07 **Deploy** | Seluruh stack bisa jalan dengan `docker compose up`. |

### 1.6 Model data
```
links                                  clicks
─────────────────────────────          ───────────────────────────
id               PK                    id          PK
short_code       UNIQUE, 3–32          link_id     FK → links.id (CASCADE)
original_url     ≤ 2048                clicked_at
created_at                             referrer    (host saja)
expires_at       NULL = selamanya      user_agent  (kategori perangkat)
click_count      ≥ 0
last_clicked_at                        INDEX (link_id, clicked_at)
manage_token_hash  SHA-256
INDEX (expires_at)
```

---

## 2. Fitur

- ✂️ Pemendek URL dengan kode acak yang aman
- 🏷️ Alias custom (`urlku.com/toko`) dengan validasi dan pesan error yang jelas
- ⏳ Masa berlaku link (1/7/30 hari atau tanggal custom)
- 📊 Statistik: total klik, klik per hari (grafik 30 hari), sumber referrer, perangkat
- 📋 Tombol salin dengan feedback "Tersalin!"
- 🗂️ Dashboard link milikmu (disimpan di browser ini)
- 🌗 Dark mode
- 🛡️ Validasi URL anti-SSRF, rate limiting, CORS allow-list, security headers

---

## 3. Tech stack

| Lapisan | Teknologi | Versi target |
|---|---|---|
| Backend | Crystal | 1.21 |
| Web framework | Kemal | 1.14 |
| DB driver | crystal-db / crystal-sqlite3 / crystal-pg | 0.14 / 0.23 / 0.30 |
| Frontend | React, React Router, TanStack Query | 19 / 7 / 5 |
| Build | Vite, TypeScript | 7 / 5.8 |
| Styling | Tailwind CSS | 4 |
| Test | Crystal `spec`, Vitest + Testing Library | – |
| Deploy | Docker, Docker Compose, nginx | – |

---

## 4. Arsitektur

```
Browser ──► Frontend SPA (Vite/React, :5173 / :8080)
   │              │  fetch JSON (CORS)
   │              ▼
   └──────► Backend Kemal (:3000) ──► SQLite / PostgreSQL
            ├─ /api/*   REST API
            ├─ /health
            └─ /:code   redirect 302 / halaman 404 / 410
```

Short URL mengarah ke **backend** (`BASE_URL`). Backend yang melakukan redirect, jadi frontend tidak ikut dalam alur klik.

```
urlku/
├── backend/
│   ├── src/
│   │   ├── app.cr                 # entrypoint (Kemal.run)
│   │   ├── urlku.cr               # wiring: container, middleware, routes
│   │   ├── config/                # Config (ENV), Database (dialect + migrasi)
│   │   ├── controllers/           # LinksController, RedirectController, presenter
│   │   ├── models/                # Link, LinkStats
│   │   ├── repositories/          # LinkRepository, ClickRepository (SQL)
│   │   ├── services/              # LinkService, UrlValidator, AliasValidator,
│   │   │                          # ShortCodeGenerator, RateLimiter
│   │   ├── middleware/            # CORS, rate limit, security headers
│   │   └── utils/                 # errors, http helper, halaman HTML, dotenv
│   ├── db/                        # schema.sqlite.sql, schema.postgres.sql
│   ├── spec/                      # test backend
│   ├── Dockerfile
│   └── shard.yml
├── frontend/
│   ├── src/
│   │   ├── components/            # Logo, Layout, ShortenForm, ResultCard, ClickChart...
│   │   ├── pages/                 # Home, Dashboard, LinkDetail, NotFound
│   │   ├── hooks/                 # useTheme, useCopy, useSavedLinks
│   │   ├── lib/                   # config, validasi, format, storage
│   │   ├── services/api.ts        # REST client
│   │   └── types/
│   ├── public/favicon.svg
│   ├── Dockerfile, nginx.conf
│   └── package.json
├── docker-compose.yml
├── .env.example
└── README.md
```

**Alur request pembuatan link:** `RateLimitHandler` → `LinksController#create` → `LinkService` (validasi URL, alias, expiry → generate kode → simpan) → `LinkRepository`.

**Kepemilikan link tanpa akun:** saat link dibuat, API mengembalikan `manage_token` sekali saja. Server hanya menyimpan hash SHA-256-nya. Frontend menyimpan token di `localStorage`, dan token ini wajib dikirim sebagai header `X-Manage-Token` untuk menghapus link.

---

## 5. Cara setup & menjalankan

### Opsi A: Docker (paling gampang, disarankan untuk Windows)

Prasyarat: [Docker Desktop](https://www.docker.com/products/docker-desktop/).

```bash
cp .env.example .env        # opsional, default-nya sudah jalan
docker compose up --build
```

- Frontend: http://localhost:8080
- Backend / short link: http://localhost:3000
- Health check: http://localhost:3000/health

Data SQLite disimpan di volume `urlku-data`.

### Opsi B: Jalankan lokal (development)

**Prasyarat**
- [Crystal](https://crystal-lang.org/install/) ≥ 1.12 + `shards`
- SQLite3 development library (`libsqlite3-dev` di Debian/Ubuntu, `sqlite` di macOS/Homebrew)
- Node.js ≥ 20 + npm

> **Catatan Windows:** Crystal di Windows butuh (1) *Developer Mode* aktif supaya `shards` bisa membuat symlink, (2) Visual Studio Build Tools dengan workload **Desktop development with C++** (termasuk Windows SDK), dan (3) `sqlite3.lib`. Kalau belum ada, lebih mudah jalankan backend lewat **WSL2** atau Docker: `docker compose up backend`, lalu frontend tetap jalan dengan `npm run dev` (set `CORS_ORIGIN=http://localhost:5173` di `.env` root).

**1. Backend**
```bash
cd backend
cp .env.example .env         # sudah berisi config lokal
shards install
crystal run src/app.cr       # atau: shards build && ./bin/urlku
```
Backend jalan di http://localhost:3000. Tabel dibuat otomatis saat start (lihat *Database setup* di bawah).

**2. Frontend** (terminal lain)
```bash
cd frontend
cp .env.example .env
npm install
npm run dev
```
Buka http://localhost:5173.

### Database setup

Kamu tidak perlu menjalankan migrasi manual. Saat boot, backend menjalankan `db/schema.sqlite.sql` atau `db/schema.postgres.sql` (idempotent, `CREATE ... IF NOT EXISTS`), tergantung `DATABASE_URL`:

| `DATABASE_URL` | Dialect |
|---|---|
| `./db/urlku.db` (path file) | SQLite (mode WAL, foreign keys aktif) |
| `postgres://user:pass@host:5432/urlku` | PostgreSQL |

Repository menulis SQL dengan placeholder `?`, yang otomatis diubah menjadi `$1, $2, …` untuk PostgreSQL.

---

## 6. Environment variables

**Backend** (`backend/.env`)

| Variabel | Default | Keterangan |
|---|---|---|
| `PORT` | `3000` | Port HTTP |
| `HOST` | `0.0.0.0` | Alamat bind |
| `DATABASE_URL` | `./db/urlku.db` | Path SQLite atau URL PostgreSQL |
| `BASE_URL` | `http://localhost:3000` | Prefix short URL di response API |
| `CORS_ORIGIN` | `http://localhost:5173` | Origin yang diizinkan (pisahkan dengan koma) |
| `FRONTEND_URL` | origin CORS pertama | Tujuan tombol "Bikin link baru" di halaman 404/410 dan redirect `/` |
| `RATE_LIMIT_CREATE_PER_MINUTE` | `20` | Batas `POST /api/links` per client |
| `RATE_LIMIT_API_PER_MINUTE` | `120` | Batas endpoint `/api/*` lain |
| `TRUST_PROXY` | `false` | `true` untuk memakai `X-Forwarded-For` (hanya di belakang proxy tepercaya) |
| `KEMAL_ENV` | `production` | `development` untuk log error yang lebih detail |

**Frontend** (`frontend/.env`, dibaca saat build)

| Variabel | Default | Keterangan |
|---|---|---|
| `VITE_API_URL` | `http://localhost:3000` | Base URL REST API |
| `VITE_BASE_URL` | = `VITE_API_URL` | Domain short link yang ditampilkan di UI |

**Root** (`.env`, untuk Docker Compose): `BASE_URL`, `FRONTEND_URL`, `CORS_ORIGIN`, `RATE_LIMIT_*`, `TRUST_PROXY`.

---

## 7. Testing

**Backend**
```bash
cd backend
crystal spec
```
Cakupan: validasi URL (skema berbahaya, host privat, panjang), short code generator, alias custom & duplikat, rute cadangan, expiration, redirect + click counter, format response API, statistik, hapus dengan token, rate limiting, CORS, dan error JSON.

**Frontend**
```bash
cd frontend
npm test            # Vitest
npm run typecheck   # tsc
```
Cakupan: render form URL, validasi, berhasil memendekkan (fetch di-mock), error alias terpakai, dan interaksi salin ("Tersalin!").

---

## 8. Dokumentasi API

Base URL: `BASE_URL` (default `http://localhost:3000`). Semua body menggunakan JSON.

### Format error
```json
{ "error": "CUSTOM_ALIAS_TAKEN", "message": "Alias tersebut sudah digunakan." }
```

| Kode | HTTP | Arti |
|---|---|---|
| `INVALID_JSON` | 400 | Body bukan JSON yang valid |
| `INVALID_URL` | 400 | URL kosong atau format salah |
| `UNSUPPORTED_SCHEME` | 400 | Bukan `http`/`https` |
| `BLOCKED_HOST` | 400 | Host lokal/privat atau domain URLKU sendiri |
| `URL_TOO_LONG` | 400 | Lebih dari 2048 karakter |
| `INVALID_ALIAS` | 400 | Alias tidak memenuhi aturan |
| `RESERVED_ALIAS` | 400 | Alias termasuk rute cadangan |
| `INVALID_EXPIRATION` | 400 | Format salah, sudah lewat, atau lebih dari 10 tahun |
| `FORBIDDEN` | 403 | Manage token salah atau tidak ada |
| `LINK_NOT_FOUND` / `NOT_FOUND` | 404 | Link atau endpoint tidak ada |
| `CUSTOM_ALIAS_TAKEN` | 409 | Alias sudah dipakai |
| `PAYLOAD_TOO_LARGE` | 413 | Body lebih dari 16 KB |
| `RATE_LIMITED` | 429 | Terlalu banyak request (lihat header `Retry-After`) |
| `INTERNAL_ERROR` | 500 | Kesalahan server |

### `POST /api/links`
Membuat link. `custom_alias` dan `expires_at` (RFC 3339) opsional.
```json
{ "url": "https://example.com", "custom_alias": "example", "expires_at": null }
```
**201 Created**
```json
{
  "id": 1,
  "short_code": "example",
  "short_url": "http://localhost:3000/example",
  "original_url": "https://example.com",
  "created_at": "2026-09-30T12:00:00Z",
  "expires_at": null,
  "click_count": 0,
  "last_clicked_at": null,
  "status": "active",
  "manage_token": "k1Xh…"
}
```
`manage_token` hanya muncul di response ini. Simpan kalau kamu ingin bisa menghapus link.

### `GET /api/links/:short_code`
Detail link: `original_url`, `short_url`, `created_at`, `expires_at`, `click_count`, `last_clicked_at`, `status` (`active`/`expired`). Bentuknya sama dengan response di atas, tanpa `manage_token`.

### `GET /api/links?codes=a,b,c`
Mengambil hingga 100 link sekaligus (dipakai dashboard). Response: `{ "links": [ … ] }`.

### `GET /api/links/:short_code/stats`
```json
{
  "short_code": "example",
  "short_url": "http://localhost:3000/example",
  "total_clicks": 42,
  "created_at": "2026-09-30T12:00:00Z",
  "expires_at": null,
  "last_clicked_at": "2026-09-30T15:20:11Z",
  "status": "active",
  "clicks_by_date": [{ "date": "2026-09-01", "clicks": 0 }, "… 30 hari …"],
  "referrers": [{ "name": "twitter.com", "clicks": 20 }, { "name": "Langsung", "clicks": 12 }],
  "devices": [{ "name": "mobile", "clicks": 30 }, { "name": "desktop", "clicks": 12 }]
}
```

### `DELETE /api/links/:short_code`
Header wajib: `X-Manage-Token: <token>`. Response **204 No Content**, atau 403 `FORBIDDEN`.

### `GET /:short_code`
- `302` ke URL asli (klik dicatat, `Cache-Control: no-store`)
- `404` halaman "Link tidak ditemukan."
- `410` halaman "Link ini sudah kedaluwarsa."

### `GET /health`
`{ "status": "ok", "version": "1.0.0" }`

---

## 9. Deployment production

1. **Domain:** arahkan misalnya `urlku.com` ke backend (short link) dan `app.urlku.com` ke frontend. Atau pakai satu domain dengan reverse proxy yang meneruskan `/api/*`, `/health`, dan `/:code` ke backend, dengan halaman SPA di path khusus.
2. **Env:** `BASE_URL=https://urlku.com`, `CORS_ORIGIN=https://app.urlku.com`, `FRONTEND_URL=https://app.urlku.com`, `TRUST_PROXY=true` jika berada di belakang Nginx/Caddy/load balancer. Build frontend dengan `VITE_API_URL`/`VITE_BASE_URL` yang sesuai (build args di compose).
3. **PostgreSQL:** set `DATABASE_URL=postgres://…`. Skema dibuat otomatis saat start.
4. **TLS:** pasang HTTPS di reverse proxy (Caddy atau Nginx + Let's Encrypt).
5. **Skala horizontal:** rate limiter bawaan bersifat per-instance. Untuk lebih dari satu instance, buat implementasi `RateLimiter` berbasis Redis (`INCR` + `EXPIRE`) lalu pasang di `Urlku::Container`.
6. **Backup:** backup volume `urlku-data` (SQLite) atau gunakan backup terkelola PostgreSQL.

---

## 10. Rencana pengembangan

- Akun pengguna (login) sebagai pengganti manage token di browser
- Rate limiter Redis + cache lookup redirect
- QR code untuk setiap link
- Edit URL tujuan dan masa berlaku
- Integrasi daftar hitam domain berbahaya (mis. Google Safe Browsing), tanpa fetch URL tujuan
- Tool migrasi versi skema (saat ini skema bersifat additive/idempotent)
- Custom domain per pengguna
- Ekspor statistik (CSV)
