# 69lookup
it's like file_id.diz but kinda better

 PRAWN MANAGEMENT SYSTEM v5.0
 Meaningfully understand every single file -- spanning eras, formats, devices 
 "A file is not just bytes but echos in multidimensional space"

    ✅ Bash-driven "Workflow Engine" that uses JSON5, YAML, ND and "logic"
    ✅ Human-first, low C02 after that
    ✅ Trawl your files (check, add, pull, scrape)

    ✅ We trade "MD5 hash + filename" for "helpful metadata" safely
    ✅ Transparent and self-documenting somehow
    ✅ Zero fscks given
  
PAY EXTRA FOR  
    ✅ Transcript extraction for videos (saved as .srt and .vtt)
    ✅ simple TUI (Terminal UI) for browsing the database
    🏷️ Auto-tagging  📊 Reporting and stats  🔍 Search filtering

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
    

69LOOKUP  
• trawl.sh                   # (check/add/pull/scrape)  
• classify_filetype.sh       # look inside File type/era detection  Identifies what a file IS  
• device_detector.sh         # WHERE did this file come from?  Device/volume detection  context -extract hardware serial via diskutil (macOS) or udevadm (Linux)., Gets mount point, device node, filesystem, volume name, and UUID + Uses heuristics (paths, filesystem types, presence of VIDEO_TS/BDMV) to classify as dvd, bluray, cd_rom, nas, external_usb, ddloud, onedrive, dropbox, system_volume, wsl_mount, or unknown  
• hierarchy_manager.sh       # (path, get_category, assign, suggest, resolve_conflict, detect_conflicts  HOW should we organize this file?   Taxonomy & conflict resolution  # categories and subcategories lookup, 	Maps file types, Turns category + subcategory (like videos/movies) into a human‑readable string like Videos → Movies, detects conflicts   
• media_tools.sh             # Enriches files with derived media assets:  (thumbnail/scene/transcript/metadata) Thumbnail, scene detection, transcript generation,metadata extraction, SRT → VTT, Caching, dependenciy checks  

apps/  
• app.py                    # powers search, statistics, file details, responsive mobile/desktop  
   
apps/templates/  
• index.html                # ransforms your SQLite database into a powerful, user-friendly search tool. primary discovery interface — a fast, flexible search engine for your digital archive. Its job is to help you find any file, anywhere, in seconds.
• browse.html               # hierarchy tree, category counts, click to browse, file details, responsive, integrates wtih api/search  
  
tools/  
• scene_detection.sh         # advanced scene detection  mediachache/scene/<md5>/-HHMMSS.jpg  
• transcript_extract.sh      # Supports OpenAI Whisper, Whisper.cpp (fast CPU), and Vosk (lightweight offline)   media_cache/transcripts/<md5>/<md5>.srt and .vtt  
• get_filetype_metadata.sh   # grabs basics (file size, modified date) + nice-to-haves (video/audio/image/document/archive/3d/retro) OBJ (vertices, faces, objects, groups), STL (ascii vs binary, triangle estimate, PLY (vertices/faces from header, and ascii/binary), DICOM, 
generate_stats.sh      - Database statistics  
export_from_markdown.sh - Export to CSV/JSON   

DID NOT YET MAKE:
• parse_3d_metadata.sh       # OBJ, PLY, GLTF, DICOM parser  
• parse_document_metadata.sh #  PDF, DOCX, MD parser  
• parse_archive_metadata.sh - ZIP, RAR, 7Z parser  


  
install/  
• schema.sql   # Full schema with tables, indexes, and views — placed at the project root.
 hierarchy_seed.sql # It inserts all categories and subcategories from our extensive taxonomy.)
• install.sh   #checks OS info, script +x, dependencies (sqllite3, jq + ffmpeg, ffprobe, exiftool, python3, flask), database (path, tables + initiate or fix), cache directory test, log directory 
• db_init.sh     # Checks for dependencies (sqlite3, jq), warns about optional tools (ffmpeg, exiftool), Validates that schema.sql exists.Creates a new SQLite database (or overwrites if --force), Applies the schema (tables, indexes, views), Verifies that tables were created and shows a success summary.


1. Specialized Format Metadata (Deeper, format‑specific)

While get_filetype_metadata.sh covers the basics, we didn't write dedicated deep parsers for:

    Documents (parse_document_metadata.sh) – Extract title, author, word count, page count, embedded images, etc. for PDF, DOCX, ODT, MD.

    Archives (parse_archive_metadata.sh) – Detailed listing of archive contents (file names, sizes, compression ratios).

    Audio (parse_audio_metadata.sh) – Deep ID3/FLAC tag extraction (album, artist, genre, bitrate, sample rate).

    Code/Web (parse_code_metadata.sh) – Detect programming language, line count, function count, dependencies.

✅ Dependencies
Tool	Used For	Install
ffprobe	Video/Audio metadata	brew install ffmpeg (macOS) / apt install ffmpeg (Linux)
exiftool	Image metadata	brew install exiftool / apt install exiftool
pdfinfo	PDF metadata	brew install poppler / apt install poppler-utils
zipinfo	ZIP / Office docs	brew install zip / apt install zip
unrar	RAR archives	brew install unrar / apt install unrar
7z	7z archives	brew install p7zip / apt install p7zip-full
identify	Image fallback	brew install imagemagick / apt install imagemagick
jq	JSON processing	brew install jq / apt install jq

    All tools are optional — the script gracefully falls back to file -b + stat if any tool is missing.
Input Type	Tool Used	Output
Video / Audio	ffprobe (or mediainfo)	Full streams + format JSON
Image	exiftool (or identify)	EXIF / metadata JSON
PDF	pdfinfo	Key/value pairs (title, pages, etc.)
Office Docs (docx, xlsx, etc.)	zipinfo	File count inside the archive
Archives (zip, rar, 7z)	zipinfo, unrar, 7z	File count, format
3D Models (obj, stl, ply)	Internal grep / parser	Vertex/face counts, format type
Retro (ANS, BBS, ROMs)	Internal detector + file	Format, ANSI detection flag
Everything Else	file -b + stat	Basic file info, size, modified date



# Suggest category
category=$(./hierarchy_manager.sh suggest "$file_type")

# Get hierarchy path
hierarchy_path=$(./hierarchy_manager.sh path "$category" "$subcategory")

# Detect conflicts
conflicts=$(./hierarchy_manager.sh detect_conflicts "$md5" "$(basename "$file")" "$file_type" "$device_serial")

# Resolve conflicts
resolution=$(./hierarchy_manager.sh resolve_conflict "$conflicts" "$md5" "$(basename "$file")" "$tags" "$batch_mode")

├── file_archive.db             # Main SQLite database (created on first run)
├── files_index.md              # Optional Markdown backup (keep for human reading)



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


