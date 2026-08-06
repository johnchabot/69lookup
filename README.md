# 69lookup
it's like file_id.diz but more better

 PRAWN MANAGEMENT SYSTEM v5.0                           │
 Track, organize and meaningfully understand every single file, spanning eras, formats, devices 
 "A file is not just bytes, it exists in multidimensional space"
 Location (Device) × Type (Hierarchy) × Content (MD5) × Context (Metadata) × History (Timeline)

    ✅ Human-first, then JSON and C02 footprint
    ✅ Transparent and self-documenting somehow
    ✅ Zero dependencies

better than file_id.diz, how exactly
    ✅ Bash Calls a "Workflow Engine" that uses JSON, YAML, ND and "logic"
    ✅ We trade "MD5 hash + filename" for "helpful metadata" safely

Privacy Doesn't Meta

METADATA (What's inside is what counts) 
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
    
there are actually many dependencies you liar
    ✅ jq, 
    ✅ pdf
    ✅ ffmpeg, ffprobe
    ✅ 
  
PAY EXTRA FOR
    ✅ Transcript extraction for videos (saved as .srt and .vtt)
    ✅ simple TUI (Terminal UI) for browsing the database
    🏷️ Auto-tagging  📊 Reporting and stats  🔍 Search filtering

schema
The Hierarchy Schema (hierarchy.json)

rules
Conflict Resolution Rules (conflict_rules.json)


scripts
Hierarchy Manager Script (hierarchy_manager.sh)

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

~/file_ingest/
├── files_index.md          # Database
├── media_cache/            # All generated media assets
│   ├── thumbnails/         # Thumbnail images
│   │   └── {md5}.jpg
│   ├── scenes/             # Scene change frames
│   │   └── {md5}/
│   │       ├── scene_001.jpg
│   │       ├── scene_002.jpg
│   │       └── scene_003.jpg
│   ├── transcripts/        # Subtitle files
│   │   └── {md5}/
│   │       ├── {md5}.srt
│   │       └── {md5}.vtt
│   └── metadata/           # Extracted metadata
│       └── {md5}.json
└── logs/
