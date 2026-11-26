CREATE TABLE IF NOT EXISTS catalog_items (
  kind TEXT NOT NULL CHECK (kind IN ('books', 'movies', 'series', 'theatre')),
  language TEXT NOT NULL CHECK (language IN ('tr', 'en')),
  source_id TEXT NOT NULL,
  position INTEGER NOT NULL,
  payload TEXT NOT NULL,
  updated_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (kind, language, source_id)
);

CREATE INDEX IF NOT EXISTS catalog_items_browse
  ON catalog_items (kind, language, position);
