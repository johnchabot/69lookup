-- ============================================================================
-- HIERARCHY SEED
-- Generated from config/hierarchy.json
-- ============================================================================

-- Root categories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id) VALUES
  ('Videos', '🎬', 'videos', NULL),
  ('Audio', '🎵', 'audio', NULL),
  ('Images', '🖼️', 'images', NULL),
  ('3D', '🧊', 'image_3d', NULL),
  ('Vector', '📐', 'image_vector', NULL),
  ('Documents', '📄', 'documents', NULL),
  ('Games', '🎮', 'games', NULL);

-- Videos subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Movies', '🎬', 'videos/movies', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'TV', '📺', 'videos/tv', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Documentaries', '🎥', 'videos/documentaries', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Music Video', '🎤', 'videos/music_video', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Webrips', '🌐', 'videos/webrips', category_id FROM hierarchy WHERE path = 'videos';

-- Audio subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Books', '📖', 'audio/books', category_id FROM hierarchy WHERE path = 'audio';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Podcasts', '🎙️', 'audio/podcasts', category_id FROM hierarchy WHERE path = 'audio';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Samples', '🔊', 'audio/samples', category_id FROM hierarchy WHERE path = 'audio';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Notifications', '🔔', 'audio/notifications', category_id FROM hierarchy WHERE path = 'audio';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Piezo', '🔌', 'audio/piezo', category_id FROM hierarchy WHERE path = 'audio';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Field Recording', '🌿', 'audio/field_recording', category_id FROM hierarchy WHERE path = 'audio';

-- Images subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Art', '🎨', 'images/art', category_id FROM hierarchy WHERE path = 'images';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Screenshots', '🖥️', 'images/screenshots', category_id FROM hierarchy WHERE path = 'images';

-- 3D subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Characters', '🧑', 'image_3d/characters', category_id FROM hierarchy WHERE path = 'image_3d';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Environments', '🌍', 'image_3d/environments', category_id FROM hierarchy WHERE path = 'image_3d';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Props', '🪑', 'image_3d/props', category_id FROM hierarchy WHERE path = 'image_3d';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Scans', '🔍', 'image_3d/scans', category_id FROM hierarchy WHERE path = 'image_3d';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Splats', '🌀', 'image_3d/splats', category_id FROM hierarchy WHERE path = 'image_3d';

-- Vector (leaf)
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Vector', '📐', 'image_vector', NULL;

-- Documents (leaf)
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Documents', '📄', 'documents', NULL;

-- Games subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'NES', '🟥', 'games/nes', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'SNES', '🟨', 'games/snes', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Dreamcast', '🌀', 'games/dreamcast', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'N64', '🔶', 'games/n64', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Windows', '🪟', 'games/windows', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Mac', '🍎', 'games/mac', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Linux', '🐧', 'games/linux', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Android', '🤖', 'games/android', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'MS-DOS', '💾', 'games/msdos', category_id FROM hierarchy WHERE path = 'games';
