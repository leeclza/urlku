-- URLKU schema (SQLite). Idempotent: safe to run on every boot.

CREATE TABLE IF NOT EXISTS links (
  id                INTEGER PRIMARY KEY AUTOINCREMENT,
  short_code        TEXT    NOT NULL UNIQUE CHECK (length(short_code) BETWEEN 3 AND 32),
  original_url      TEXT    NOT NULL CHECK (length(original_url) <= 2048),
  created_at        TEXT    NOT NULL,
  expires_at        TEXT,
  click_count       INTEGER NOT NULL DEFAULT 0 CHECK (click_count >= 0),
  last_clicked_at   TEXT,
  manage_token_hash TEXT    NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_links_expires_at ON links (expires_at);

CREATE TABLE IF NOT EXISTS clicks (
  id         INTEGER PRIMARY KEY AUTOINCREMENT,
  link_id    INTEGER NOT NULL REFERENCES links (id) ON DELETE CASCADE,
  clicked_at TEXT    NOT NULL,
  referrer   TEXT,
  user_agent TEXT
);

CREATE INDEX IF NOT EXISTS idx_clicks_link_id_clicked_at ON clicks (link_id, clicked_at);
