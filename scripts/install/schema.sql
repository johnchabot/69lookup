-- ============================================================================
-- DATABASE: file_archive.db
-- ============================================================================

-- ----------------------------------------------------------------------------
-- DEVICES (Physical or logical storage devices)
-- ----------------------------------------------------------------------------
CREATE TABLE devices (
    device_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    device_type     TEXT NOT NULL,          -- dvd, bluray, nas, usb, cloud, system
    device_name     TEXT,                    -- Human-readable name
    device_serial   TEXT UNIQUE,             -- Hardware serial number
    mount_point     TEXT,                    -- Where it's mounted
    filesystem      TEXT,                    -- UDF, APFS, NTFS, SMB, etc.
    metadata        JSON,                    -- Type-specific: {title, server, account}
    is_physical     BOOLEAN DEFAULT 0,
    is_removable    BOOLEAN DEFAULT 0,
    is_cloud        BOOLEAN DEFAULT 0,
    is_network      BOOLEAN DEFAULT 0,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- VOLUMES (Named volumes within devices)
-- ----------------------------------------------------------------------------
CREATE TABLE volumes (
    volume_id       INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id       INTEGER REFERENCES devices(device_id) ON DELETE CASCADE,
    volume_name     TEXT NOT NULL,           -- Label of the volume
    volume_serial   TEXT,                    -- Unique volume identifier
    volume_type     TEXT,                    -- primary, external, archive, disc
    capacity        INTEGER,                 -- Bytes
    free_space      INTEGER,                 -- Bytes
    is_encrypted    BOOLEAN DEFAULT 0,
    metadata        JSON,                    -- {disc_number, region, encryption_type}
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- LOCATIONS (Specific paths within volumes)
-- ----------------------------------------------------------------------------
CREATE TABLE locations (
    location_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id       INTEGER REFERENCES devices(device_id) ON DELETE CASCADE,
    volume_id       INTEGER REFERENCES volumes(volume_id) ON DELETE CASCADE,
    relative_path   TEXT NOT NULL,           -- Path within the volume
    absolute_path   TEXT UNIQUE,             -- Full filesystem path
    is_mounted      BOOLEAN DEFAULT 1,
    mount_state     TEXT DEFAULT 'mounted',  -- mounted, unmounted, offline
    last_seen       DATETIME,                -- When this location was last verified
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    UNIQUE(device_id, volume_id, relative_path)
);

-- ----------------------------------------------------------------------------
-- FILES (The core entity)
-- ----------------------------------------------------------------------------
CREATE TABLE files (
    file_id         INTEGER PRIMARY KEY AUTOINCREMENT,
    md5             TEXT UNIQUE NOT NULL,    -- Cryptographic fingerprint
    location_id     INTEGER REFERENCES locations(location_id) ON DELETE SET NULL,
    filename        TEXT NOT NULL,           -- Base filename
    extension       TEXT,                    -- File extension (lowercase)
    size_bytes      INTEGER,
    file_type       TEXT,                    -- video, image, audio, etc.
    era             TEXT,                    -- retro, modern, unknown
    icon            TEXT,                    -- Emoji indicator
    status          TEXT DEFAULT 'pending',  -- pending, processing, complete, failed
    processed_at    DATETIME,
    created_at      DATETIME,                -- File creation time (from OS)
    modified_at     DATETIME,                -- File modification time (from OS)
    indexed_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    metadata        JSON,                    -- Type-specific metadata
    media_assets    JSON,                    -- {thumbnail, scenes, transcripts}
    tags            TEXT,                    -- Comma-separated tags
    notes           TEXT,                    -- User notes
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- HIERARCHY (Taxonomy categories)
-- ----------------------------------------------------------------------------
CREATE TABLE hierarchy (
    category_id     INTEGER PRIMARY KEY AUTOINCREMENT,
    parent_id       INTEGER REFERENCES hierarchy(category_id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    description     TEXT,
    icon            TEXT,                    -- Emoji
    path            TEXT UNIQUE,             -- Full hierarchy path
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP,
    updated_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- ----------------------------------------------------------------------------
-- FILE_HIERARCHY (Many-to-many mapping)
-- ----------------------------------------------------------------------------
CREATE TABLE file_hierarchy (
    file_id         INTEGER REFERENCES files(file_id) ON DELETE CASCADE,
    category_id     INTEGER REFERENCES hierarchy(category_id) ON DELETE CASCADE,
    PRIMARY KEY (file_id, category_id)
);

-- ----------------------------------------------------------------------------
-- TAGS (Normalized tags for faster querying)
-- ----------------------------------------------------------------------------
CREATE TABLE tags (
    tag_id          INTEGER PRIMARY KEY AUTOINCREMENT,
    tag_name        TEXT UNIQUE NOT NULL,
    created_at      DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE file_tags (
    file_id         INTEGER REFERENCES files(file_id) ON DELETE CASCADE,
    tag_id          INTEGER REFERENCES tags(tag_id) ON DELETE CASCADE,
    PRIMARY KEY (file_id, tag_id)
);

-- ============================================================================
-- INDEXES (For performance at GB scale)
-- ============================================================================
CREATE INDEX idx_files_md5 ON files(md5);
CREATE INDEX idx_files_location ON files(location_id);
CREATE INDEX idx_files_type ON files(file_type);
CREATE INDEX idx_files_status ON files(status);
CREATE INDEX idx_files_extension ON files(extension);
CREATE INDEX idx_locations_device ON locations(device_id);
CREATE INDEX idx_locations_volume ON locations(volume_id);
CREATE INDEX idx_locations_absolute ON locations(absolute_path);
CREATE INDEX idx_hierarchy_parent ON hierarchy(parent_id);
CREATE INDEX idx_hierarchy_path ON hierarchy(path);
CREATE INDEX idx_devices_serial ON devices(device_serial);
CREATE INDEX idx_volumes_device ON volumes(device_id);

-- ============================================================================
-- VIEWS (For common queries)
-- ============================================================================

-- File with full location context
CREATE VIEW v_files_full AS
SELECT 
    f.file_id,
    f.md5,
    f.filename,
    f.extension,
    f.size_bytes,
    f.file_type,
    f.era,
    f.icon,
    f.status,
    f.tags,
    f.metadata,
    f.media_assets,
    f.created_at AS file_created,
    f.modified_at AS file_modified,
    f.indexed_at,
    l.absolute_path,
    l.relative_path,
    l.is_mounted,
    d.device_name,
    d.device_type,
    d.device_serial,
    d.metadata AS device_metadata,
    v.volume_name,
    v.volume_serial,
    v.metadata AS volume_metadata
FROM files f
LEFT JOIN locations l ON f.location_id = l.location_id
LEFT JOIN devices d ON l.device_id = d.device_id
LEFT JOIN volumes v ON l.volume_id = v.volume_id;

-- File hierarchy paths
CREATE VIEW v_file_hierarchy AS
SELECT 
    f.file_id,
    f.md5,
    f.filename,
    GROUP_CONCAT(h.path, ' / ') AS hierarchy_path
FROM files f
JOIN file_hierarchy fh ON f.file_id = fh.file_id
JOIN hierarchy h ON fh.category_id = h.category_id
GROUP BY f.file_id;

-- Statistics by device type
CREATE VIEW v_stats_by_device_type AS
SELECT 
    d.device_type,
    COUNT(f.file_id) AS file_count,
    SUM(f.size_bytes) AS total_bytes,
    AVG(f.size_bytes) AS avg_bytes,
    COUNT(DISTINCT d.device_id) AS device_count
FROM devices d
LEFT JOIN locations l ON d.device_id = l.device_id
LEFT JOIN files f ON l.location_id = f.location_id
GROUP BY d.device_type;

-- Statistics by file type
CREATE VIEW v_stats_by_file_type AS
SELECT 
    file_type,
    COUNT(*) AS file_count,
    SUM(size_bytes) AS total_bytes,
    AVG(size_bytes) AS avg_bytes,
    COUNT(DISTINCT era) AS era_count
FROM files
WHERE file_type IS NOT NULL
GROUP BY file_type;

-- Recent files (last 7 days)
CREATE VIEW v_recent_files AS
SELECT 
    file_id,
    filename,
    file_type,
    size_bytes,
    status,
    indexed_at,
    absolute_path
FROM v_files_full
WHERE indexed_at >= datetime('now', '-7 days')
ORDER BY indexed_at DESC;

-- Orphaned files (location deleted but file record exists)
CREATE VIEW v_orphaned_files AS
SELECT 
    f.file_id,
    f.md5,
    f.filename,
    f.absolute_path
FROM v_files_full f
WHERE f.location_id IS NULL
   OR (f.is_mounted = 0 AND f.status != 'pending');
