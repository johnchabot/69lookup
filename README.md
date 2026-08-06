# 69lookup
it's like file_id.diz but kinda better

 PRAWN MANAGEMENT SYSTEM v5.0
 Meaningfully understand every single file -- spanning eras, formats, devices 
 "A file is not just bytes but echos in multidimensional space"

    ✅ Human-first < JSON5, low C02 footprint
    ✅ Trawl your files (check, add, pull)
 
    ✅ Bash-driven "Workflow Engine" that uses JSON, YAML, ND and "logic"
    ✅ We trade "MD5 hash + filename" for "helpful metadata" safely
    ✅ Transparent and self-documenting somehow
    ✅ Zero dependencies

apps
 app.py - search, statistics, filel details, responsive mobile/desktop

scripts/
 ** trawl.sh                     # check/add/pull/scrape by (SQLite-enabled)
 ** classify_filetype.sh         # look inside File type/era detection 
 ** device_detector.sh           # Device/volume detection  context -extract hardware serial via diskutil (macOS) or udevadm (Linux)., Gets mount point, device node, filesystem, volume name, and UUID + Uses heuristics (paths, filesystem types, presence of VIDEO_TS/BDMV) to classify as dvd, bluray, cd_rom, nas, external_usb, ddloud, onedrive, dropbox, system_volume, wsl_mount, or unknown.
 ** hierarchy_manager.sh  (path, get_category, assign, suggest, resolve_conflict, detect_conflicts    Taxonomy & conflict resolution  # categories and subcategories lookup, 	Maps file types, Turns category + subcategory (like videos/movies) into a human‑readable string like Videos → Movies, detects conflicts, 
 ** media_tools.sh               # (thumbnail/scene/transcript/metadata) Thumbnail, scene detection, transcript generation,metadata extraction, SRT → VTT, Caching, dependenciy checks

scripts/install
** db_init.sh     # Checks for dependencies (sqlite3, jq), warns about optional tools (ffmpeg, exiftool), Validates that schema.sql exists.Creates a new SQLite database (or overwrites if --force), Applies the schema (tables, indexes, views), Verifies that tables were created and shows a success summary.

tools/

    trawl.sh will automatically use the database file set by DB_PATH (default: ./file_archive.db).

    app.py uses the same default path, but you can override via environment variable.




install/
 schema.sql - Full schema with tables, indexes, and views — placed at the project root.
 hierarchy_seed.sql lace at the project root. It inserts all categories and subcategories from our extensive taxonomy.)

Workflow:
file_ingest.sh pull a1b2c3d4 md5  

classify_filetype.sh   Identifies what a file IS:  
device_detector.sh   nswers: WHERE did this file come from? 
 hierarchy_manager.sh HOW should we organize this file?  
   media_tools.sh      Enriches files with derived media assets: 


    schema.sql
device_detector.sh  Can load additional metadata from devices.json (if you want to define custom metadata per device type).

"Location" is not just a path string. It's a composition of: 
* Device × Volume × Path × Context
* Location (Device) × Type (Hierarchy) × Content (MD5) × Context (Metadata) × History (Timeline)

Understanding METADATA (What's inside is what counts) 
Image (Dimensions, Colours, Megapixels, GPS)
 3D (Favets, Verteces, Format)
Video (FPS, Height, Duration, 
Audio (Channels, Bitrate, Sample Rate, Duration
 Music (Band, Title, Song, 
Binaries
 Archive
 ISO
 Games
 Apps


# Suggest category
category=$(./hierarchy_manager.sh suggest "$file_type")

# Get hierarchy path
hierarchy_path=$(./hierarchy_manager.sh path "$category" "$subcategory")

# Detect conflicts
conflicts=$(./hierarchy_manager.sh detect_conflicts "$md5" "$(basename "$file")" "$file_type" "$device_serial")

# Resolve conflicts
resolution=$(./hierarchy_manager.sh resolve_conflict "$conflicts" "$md5" "$(basename "$file")" "$tags" "$batch_mode")

# Then handle based on resolution...


            instsall/
   ├── migrate_md_to_sqlite.sh
│   └── db_init.sh
            
│   └── templates/
│       ├── index.html
│       └── browse.html
├── file_archive.db             # Main SQLite database (created on first run)
├── files_index.md              # Optional Markdown backup (keep for human reading)


supporting scripts

 • scene_detection.sh     - Advanced FFmpeg scene detection   ││  │
│  │  │  • transcript_extract.sh  - Whisper/Vosk/Whisper.cpp wrapper ││  │
│  │  │  • get_filetype_metadata.sh - Type-specific metadata parsers  ││  │
│  │  │  • parse_3d_metadata.sh   - OBJ, PLY, GLTF, DICOM parser    ││  │
│  │  │  • parse_document_metadata.sh - PDF, DOCX, MD parser        ││  │
│  │  │  • parse_archive_metadata.sh - ZIP, RAR, 7Z parser          ││  │
│  │  │  • db_init.sh             - Initialize markdown database      ││  │
│  │  │  • generate_stats.sh      - Database statistics              ││  │
│  │  │  • export_from_markdown.sh - Export to CSV/JSON  
Hierarchy Manager Script (hierarchy_manager.sh)
   
  
PAY EXTRA FOR
    ✅ Transcript extraction for videos (saved as .srt and .vtt)
    ✅ simple TUI (Terminal UI) for browsing the database
    🏷️ Auto-tagging  📊 Reporting and stats  🔍 Search filtering


    pendencies

To use all features, install:
Tool	Install
ffmpeg	brew install ffmpeg (macOS) or apt install ffmpeg (Linux)
exiftool	brew install exiftool (macOS) or apt install exiftool (Linux)
whisper	pip install openai-whisper
whisper.cpp	Build from source
vosk-transcribe	pip install vosk-transcribe


schema
The Hierarchy Schema (hierarchy.json)

rules
Conflict Resolution Rules (conflict_rules.json)


 Type         │ DVD, Blu-ray, External USB, NAS, Cloud  │    │      │
│  │  │ Volume Name  │ "DVD_VIDEO", "iCloud Drive", "Media"    │    │      │
│  │  │ Serial       │ Unique hardware or volume identifier    │    │      │
│  │  │ Filesystem   │ UDF, APFS, NTFS, SMB, Cloud            │    │      │
│  │  │ Metadata     │ DVD Title, Disc #, Server, Account 

semantic meaning:

    DVD/Blu-ray → Title, serial, disc number
    External drive → Volume name, mount point, serial
    Network share → SMB path, server name
    Cloud sync → iCloud Drive, OneDrive, Dropbox
    System volume → APFS volume name, UUID


