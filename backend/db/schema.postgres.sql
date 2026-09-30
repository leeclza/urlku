-- URLKU schema (PostgreSQL). Idempotent: safe to run on every boot.

CREATE TABLE IF NOT EXISTS links (
  id                BIGSERIAL    PRIMARY KEY,
  short_code        VARCHAR(32)  NOT NULL UNIQUE CHECK (char_length(short_code) BETWEEN 3 AND 32),
  original_url      VARCHAR(2048) NOT NULL,
  created_at        TIMESTAMPTZ  NOT NULL,
  expires_at        TIMESTAMPTZ,
  click_count       BIGINT       NOT NULL DEFAULT 0 CHECK (click_count >= 0),
  last_clicked_at   TIMESTAMPTZ,
  manage_token_hash VARCHAR(64)  NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_links_expires_at ON links (expires_at);

CREATE TABLE IF NOT EXISTS clicks (
  id         BIGSERIAL    PRIMARY KEY,
  link_id    BIGINT       NOT NULL REFERENCES links (id) ON DELETE CASCADE,
  clicked_at TIMESTAMPTZ  NOT NULL,
  referrer   VARCHAR(255),
  user_agent VARCHAR(16)
);

CREATE INDEX IF NOT EXISTS idx_clicks_link_id_clicked_at ON clicks (link_id, clicked_at);
