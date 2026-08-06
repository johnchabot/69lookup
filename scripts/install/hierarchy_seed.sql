-- ============================================================================
-- HIERARCHY SEED
-- Inserts the full category taxonomy: root → subcategories → sub-subcategories
-- ============================================================================

-- ----------------------------------------------------------------------------
-- 1. ROOT CATEGORIES (parent_id = NULL)
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id) VALUES
  ('Videos', '🎬', 'videos', NULL),
  ('Audio', '🎵', 'audio', NULL),
  ('Images', '🖼️', 'images', NULL),
  ('3D', '🧊', 'image_3d', NULL),
  ('Vector', '📐', 'image_vector', NULL),
  ('Documents', '📄', 'documents', NULL),
  ('Games', '🎮', 'games', NULL),
  ('Binaries', '⚙️', 'binaries', NULL),
  ('Archives', '📦', 'archives', NULL),
  ('Web', '🌐', 'web', NULL),
  ('System', '⚙️', 'system', NULL),
  ('Obscure', '🔮', 'obscure', NULL),
  ('BBS', '📟', 'bbs', NULL),
  ('ANSI Art', '🎨', 'ansi_art', NULL);

-- ----------------------------------------------------------------------------
-- 2. VIDEO SUBCATEGORIES (parent = 'videos')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Movies', '🎬', 'videos/movies', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'TV', '📺', 'videos/tv', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Documentary', '🎥', 'videos/documentary', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Music Video', '🎤', 'videos/music_video', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Anime', '🌸', 'videos/anime', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Short', '⏳', 'videos/short', category_id FROM hierarchy WHERE path = 'videos';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Home Video', '🏠', 'videos/home_video', category_id FROM hierarchy WHERE path = 'videos';

-- ----------------------------------------------------------------------------
-- 3. AUDIO SUBCATEGORIES (parent = 'audio')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Music', '🎵', 'audio/music', category_id FROM hierarchy WHERE path = 'audio';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Audio Books', '📖', 'audio/audiobooks', category_id FROM hierarchy WHERE path = 'audio';
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

-- AUDIO / MUSIC sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Albums', '💿', 'audio/music/albums', category_id FROM hierarchy WHERE path = 'audio/music';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Singles', '🎶', 'audio/music/singles', category_id FROM hierarchy WHERE path = 'audio/music';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Remixes', '🔄', 'audio/music/remixes', category_id FROM hierarchy WHERE path = 'audio/music';

-- ----------------------------------------------------------------------------
-- 4. IMAGE SUBCATEGORIES (parent = 'images')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Photography', '📷', 'images/photography', category_id FROM hierarchy WHERE path = 'images';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Art', '🎨', 'images/art', category_id FROM hierarchy WHERE path = 'images';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Screenshots', '🖥️', 'images/screenshots', category_id FROM hierarchy WHERE path = 'images';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Meme', '😂', 'images/meme', category_id FROM hierarchy WHERE path = 'images';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Retro', '🕹️', 'images/retro', category_id FROM hierarchy WHERE path = 'images';

-- IMAGES / PHOTOGRAPHY sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Portraits', '👤', 'images/photography/portraits', category_id FROM hierarchy WHERE path = 'images/photography';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Landscapes', '🏞️', 'images/photography/landscapes', category_id FROM hierarchy WHERE path = 'images/photography';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Street', '🚶', 'images/photography/street', category_id FROM hierarchy WHERE path = 'images/photography';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Macro', '🔬', 'images/photography/macro', category_id FROM hierarchy WHERE path = 'images/photography';

-- IMAGES / ART sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Digital Art', '🖌️', 'images/art/digital', category_id FROM hierarchy WHERE path = 'images/art';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Traditional Art', '🖼️', 'images/art/traditional', category_id FROM hierarchy WHERE path = 'images/art';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Pixel Art', '👾', 'images/art/pixel_art', category_id FROM hierarchy WHERE path = 'images/art';

-- IMAGES / RETRO sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'ANSI Art', '🎨', 'images/retro/ansi', category_id FROM hierarchy WHERE path = 'images/retro';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'BBS Art', '📟', 'images/retro/bbs', category_id FROM hierarchy WHERE path = 'images/retro';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Demoscene', '✨', 'images/retro/demoscene', category_id FROM hierarchy WHERE path = 'images/retro';

-- ----------------------------------------------------------------------------
-- 5. 3D SUBCATEGORIES (parent = 'image_3d')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Models', '🧊', 'image_3d/models', category_id FROM hierarchy WHERE path = 'image_3d';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Scans', '🔍', 'image_3d/scans', category_id FROM hierarchy WHERE path = 'image_3d';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Splats', '🌀', 'image_3d/splats', category_id FROM hierarchy WHERE path = 'image_3d';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Voxel', '🧱', 'image_3d/voxel', category_id FROM hierarchy WHERE path = 'image_3d';

-- 3D / MODELS sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Characters', '🧑', 'image_3d/models/characters', category_id FROM hierarchy WHERE path = 'image_3d/models';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Environments', '🌍', 'image_3d/models/environments', category_id FROM hierarchy WHERE path = 'image_3d/models';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Props', '🪑', 'image_3d/models/props', category_id FROM hierarchy WHERE path = 'image_3d/models';

-- ----------------------------------------------------------------------------
-- 6. DOCUMENT SUBCATEGORIES (parent = 'documents')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Text', '📝', 'documents/text', category_id FROM hierarchy WHERE path = 'documents';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Office', '📊', 'documents/office', category_id FROM hierarchy WHERE path = 'documents';

-- DOCUMENTS / TEXT sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Notes', '📋', 'documents/text/notes', category_id FROM hierarchy WHERE path = 'documents/text';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Markdown', '📓', 'documents/text/markdown', category_id FROM hierarchy WHERE path = 'documents/text';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Code', '💻', 'documents/text/code', category_id FROM hierarchy WHERE path = 'documents/text';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Logs', '📜', 'documents/text/logs', category_id FROM hierarchy WHERE path = 'documents/text';

-- DOCUMENTS / OFFICE sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Word', '📄', 'documents/office/word', category_id FROM hierarchy WHERE path = 'documents/office';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Excel', '📊', 'documents/office/excel', category_id FROM hierarchy WHERE path = 'documents/office';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'PowerPoint', '📽️', 'documents/office/powerpoint', category_id FROM hierarchy WHERE path = 'documents/office';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'PDF', '📕', 'documents/office/pdf', category_id FROM hierarchy WHERE path = 'documents/office';

-- ----------------------------------------------------------------------------
-- 7. GAME SUBCATEGORIES (parent = 'games')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'ROMs', '🕹️', 'games/roms', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Executables', '🎮', 'games/executables', category_id FROM hierarchy WHERE path = 'games';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'ISO', '💿', 'games/iso', category_id FROM hierarchy WHERE path = 'games';

-- GAMES / ROMS sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'NES', '🟥', 'games/roms/nes', category_id FROM hierarchy WHERE path = 'games/roms';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'SNES', '🟨', 'games/roms/snes', category_id FROM hierarchy WHERE path = 'games/roms';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'GameBoy', '🟩', 'games/roms/gameboy', category_id FROM hierarchy WHERE path = 'games/roms';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Dreamcast', '🌀', 'games/roms/dreamcast', category_id FROM hierarchy WHERE path = 'games/roms';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'N64', '🔶', 'games/roms/n64', category_id FROM hierarchy WHERE path = 'games/roms';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'PlayStation', '🔵', 'games/roms/playstation', category_id FROM hierarchy WHERE path = 'games/roms';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Sega', '🟦', 'games/roms/sega', category_id FROM hierarchy WHERE path = 'games/roms';

-- GAMES / ROMS / GAMEBOY sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'GB', '🟩', 'games/roms/gameboy/gb', category_id FROM hierarchy WHERE path = 'games/roms/gameboy';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'GBC', '🟪', 'games/roms/gameboy/gbc', category_id FROM hierarchy WHERE path = 'games/roms/gameboy';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'GBA', '🟫', 'games/roms/gameboy/gba', category_id FROM hierarchy WHERE path = 'games/roms/gameboy';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT '3DS', '🟧', 'games/roms/gameboy/3ds', category_id FROM hierarchy WHERE path = 'games/roms/gameboy';

-- GAMES / ROMS / PLAYSTATION sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'PS1', '🔵', 'games/roms/playstation/ps1', category_id FROM hierarchy WHERE path = 'games/roms/playstation';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'PS2', '🟣', 'games/roms/playstation/ps2', category_id FROM hierarchy WHERE path = 'games/roms/playstation';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'PS3', '⚫', 'games/roms/playstation/ps3', category_id FROM hierarchy WHERE path = 'games/roms/playstation';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'PSP', '🎮', 'games/roms/playstation/psp', category_id FROM hierarchy WHERE path = 'games/roms/playstation';

-- GAMES / ROMS / SEGA sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Genesis', '🟦', 'games/roms/sega/genesis', category_id FROM hierarchy WHERE path = 'games/roms/sega';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Saturn', '🪐', 'games/roms/sega/saturn', category_id FROM hierarchy WHERE path = 'games/roms/sega';

-- GAMES / EXECUTABLES sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Windows', '🪟', 'games/executables/windows', category_id FROM hierarchy WHERE path = 'games/executables';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Mac', '🍎', 'games/executables/mac', category_id FROM hierarchy WHERE path = 'games/executables';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Linux', '🐧', 'games/executables/linux', category_id FROM hierarchy WHERE path = 'games/executables';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Android', '🤖', 'games/executables/android', category_id FROM hierarchy WHERE path = 'games/executables';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'MS-DOS', '💾', 'games/executables/msdos', category_id FROM hierarchy WHERE path = 'games/executables';

-- GAMES / EXECUTABLES / ANDROID sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Android TV', '📺', 'games/executables/android/tv', category_id FROM hierarchy WHERE path = 'games/executables/android';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Android Tablet', '📱', 'games/executables/android/tablet', category_id FROM hierarchy WHERE path = 'games/executables/android';

-- ----------------------------------------------------------------------------
-- 8. BINARY SUBCATEGORIES (parent = 'binaries')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Executables', '⚙️', 'binaries/executables', category_id FROM hierarchy WHERE path = 'binaries';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Libraries', '📚', 'binaries/libraries', category_id FROM hierarchy WHERE path = 'binaries';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Drivers', '🔧', 'binaries/drivers', category_id FROM hierarchy WHERE path = 'binaries';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Firmware', '💾', 'binaries/firmware', category_id FROM hierarchy WHERE path = 'binaries';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Packages', '📦', 'binaries/packages', category_id FROM hierarchy WHERE path = 'binaries';

-- BINARIES / PACKAGES sub-subcategories
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'DEB', '📦', 'binaries/packages/deb', category_id FROM hierarchy WHERE path = 'binaries/packages';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'RPM', '📦', 'binaries/packages/rpm', category_id FROM hierarchy WHERE path = 'binaries/packages';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'Flatpak', '📦', 'binaries/packages/flatpak', category_id FROM hierarchy WHERE path = 'binaries/packages';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'AppImage', '📦', 'binaries/packages/appimage', category_id FROM hierarchy WHERE path = 'binaries/packages';

-- ----------------------------------------------------------------------------
-- 9. ARCHIVE SUBCATEGORIES (parent = 'archives')
-- ----------------------------------------------------------------------------
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'ZIP', '📦', 'archives/zip', category_id FROM hierarchy WHERE path = 'archives';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'RAR', '📦', 'archives/rar', category_id FROM hierarchy WHERE path = 'archives';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT '7Z', '📦', 'archives/7z', category_id FROM hierarchy WHERE path = 'archives';
INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id)
SELECT 'TAR', '📦', 'archives/tar', category_id FROM hierarchy WHERE path = 'archives';

-- ----------------------------------------------------------------------------
-- 10. FINAL CHECK (optional: show all paths inserted)
-- ---------------------------------------------------------------------------
-- .output /dev/null
-- SELECT '✅ Hierarchy seeded: ' || COUNT(*) || ' categories' FROM hierarchy;
-- .output stdout
