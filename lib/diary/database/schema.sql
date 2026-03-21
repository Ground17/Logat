CREATE TABLE assets (
  asset_id TEXT PRIMARY KEY,
  created_at INTEGER NOT NULL,
  modified_at INTEGER NOT NULL,
  latitude REAL,
  longitude REAL,
  width INTEGER NOT NULL,
  height INTEGER NOT NULL,
  duration_seconds INTEGER NOT NULL DEFAULT 0,
  media_type TEXT NOT NULL,
  is_favorite INTEGER NOT NULL DEFAULT 0,
  album_id TEXT,
  album_name TEXT,
  indexed_at INTEGER NOT NULL,
  analyzed_at INTEGER,
  content_hash TEXT,
  is_locally_available INTEGER NOT NULL DEFAULT 1
);

CREATE INDEX idx_assets_created_at ON assets(created_at);
CREATE INDEX idx_assets_location ON assets(latitude, longitude);
CREATE INDEX idx_assets_album_created_at ON assets(album_id, created_at);

CREATE TABLE indexing_state (
  singleton_id INTEGER PRIMARY KEY CHECK (singleton_id = 1),
  status TEXT NOT NULL,
  last_completed_created_at INTEGER,
  last_completed_asset_id TEXT,
  resume_page INTEGER NOT NULL DEFAULT 0,
  scanned_count INTEGER NOT NULL DEFAULT 0,
  inserted_count INTEGER NOT NULL DEFAULT 0,
  skipped_count INTEGER NOT NULL DEFAULT 0,
  started_at INTEGER,
  completed_at INTEGER,
  updated_at INTEGER NOT NULL
);

CREATE TABLE events (
  event_id TEXT PRIMARY KEY,
  start_at INTEGER NOT NULL,
  end_at INTEGER NOT NULL,
  latitude REAL,
  longitude REAL,
  asset_count INTEGER NOT NULL,
  representative_asset_id TEXT NOT NULL,
  quality_score REAL NOT NULL,
  is_moving INTEGER NOT NULL DEFAULT 0
);

CREATE INDEX idx_events_start_at ON events(start_at);
CREATE INDEX idx_events_location ON events(latitude, longitude);

CREATE TABLE event_assets (
  event_id TEXT NOT NULL,
  asset_id TEXT NOT NULL,
  PRIMARY KEY (event_id, asset_id)
);

CREATE INDEX idx_event_assets_asset_id ON event_assets(asset_id);

CREATE TABLE tags (
  tag_id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  type TEXT NOT NULL,
  confidence REAL NOT NULL
);

CREATE TABLE asset_tags (
  asset_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (asset_id, tag_id)
);

CREATE TABLE event_tags (
  event_id TEXT NOT NULL,
  tag_id TEXT NOT NULL,
  PRIMARY KEY (event_id, tag_id)
);

INSERT INTO indexing_state (
  singleton_id,
  status,
  resume_page,
  scanned_count,
  inserted_count,
  skipped_count,
  updated_at
) VALUES (1, 'idle', 0, 0, 0, 0, strftime('%s', 'now') * 1000);
