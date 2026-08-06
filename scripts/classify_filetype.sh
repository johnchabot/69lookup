#!/bin/bash
# classify_filetype.sh - Era-aware file type classification
# Outputs JSON with: file_type, era, icon, description, default_tags

set -euo pipefail

# ============================================================================
# 1. EXTENSION → CATEGORY MAP (The "Source of Truth")
# ============================================================================

declare -A FILE_TYPE_MAP
declare -A FILE_ERA_MAP
declare -A FILE_DESCRIPTION_MAP
declare -A FILE_ICON_MAP

# ----- Video -----
for ext in mp4 mov avi mpg mpeg ts m4v mkv webm flv wmv; do
    FILE_TYPE_MAP["$ext"]="video"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="Digital Video File"
    FILE_ICON_MAP["$ext"]="🎬"
done

# ----- Image (Raster) -----
for ext in jpg jpeg png gif bmp tiff tif webp heic heif raw cr2 nef arw; do
    FILE_TYPE_MAP["$ext"]="image"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="Raster Image"
    FILE_ICON_MAP["$ext"]="🖼️"
done
# GIF spans eras (retro web)
FILE_ERA_MAP["gif"]="retro"
FILE_DESCRIPTION_MAP["gif"]="GIF Image (Retro Web/Animation)"

# ----- Image 3D -----
for ext in obj dcm dicom splat ply stl fbx gltf glb usd usda usdc; do
    FILE_TYPE_MAP["$ext"]="image_3d"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="3D Model / Point Cloud"
    FILE_ICON_MAP["$ext"]="🧊"
done

# ----- Image Vector -----
for ext in svg eps ai cdr wmf; do
    FILE_TYPE_MAP["$ext"]="image_vector"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="Vector Graphic"
    FILE_ICON_MAP["$ext"]="📐"
done

# ----- Audio -----
for ext in mp3 flac fla s3m mod wav aac ogg wma m4a opus aiff; do
    FILE_TYPE_MAP["$ext"]="audio"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="Digital Audio File"
    FILE_ICON_MAP["$ext"]="🎵"
done
# Retro tracker modules
FILE_ERA_MAP["mod"]="retro"
FILE_ERA_MAP["s3m"]="retro"
FILE_DESCRIPTION_MAP["mod"]="MOD Music Tracker (Retro)"
FILE_DESCRIPTION_MAP["s3m"]="ScreamTracker 3 Module (Retro)"

# ----- Compressed Archives -----
for ext in zip rar 7z gz bz2 xz tar tgz zst lz4 lzma cab arj; do
    FILE_TYPE_MAP["$ext"]="compressed"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="Compressed Archive"
    FILE_ICON_MAP["$ext"]="📦"
done
FILE_ERA_MAP["arj"]="retro"
FILE_DESCRIPTION_MAP["arj"]="ARJ Archive (Retro/DOS)"

# ----- Documents -----
for ext in pdf doc docx rtf pages txt md odt ods odp xls xlsx ppt pptx; do
    FILE_TYPE_MAP["$ext"]="document"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="Document / Text File"
    FILE_ICON_MAP["$ext"]="📄"
done

# ----- Games / ROMs (Retro heavy) -----
for ext in xex xbla iso nsp xci rom nes smc gba n64 ps2 wbfs; do
    FILE_TYPE_MAP["$ext"]="game"
    FILE_ERA_MAP["$ext"]="retro"
    FILE_DESCRIPTION_MAP["$ext"]="Game ROM / Console Format"
    FILE_ICON_MAP["$ext"]="🎮"
done

# ----- Web / Code -----
for ext in html htm css js ts jsx tsx json xml yaml yml toml; do
    FILE_TYPE_MAP["$ext"]="web"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="Web / Code File"
    FILE_ICON_MAP["$ext"]="🌐"
done

# ----- System / Binaries -----
for ext in exe dll so dylib bin dmg pkg deb rpm appimage flatpak snap; do
    FILE_TYPE_MAP["$ext"]="system"
    FILE_ERA_MAP["$ext"]="modern"
    FILE_DESCRIPTION_MAP["$ext"]="System / Executable File"
    FILE_ICON_MAP["$ext"]="⚙️"
done

# ----- Obscure / Temp / BBS era -----
for ext in dmd dme dmp bak tmp swp swo log core dump bbs ans vga; do
    FILE_TYPE_MAP["$ext"]="obscure"
    FILE_ERA_MAP["$ext"]="unknown"
    FILE_DESCRIPTION_MAP["$ext"]="Obscure / Temporary File"
    FILE_ICON_MAP["$ext"]="🔮"
done
# BBS specific overrides
FILE_TYPE_MAP["bbs"]="bbs"
FILE_DESCRIPTION_MAP["bbs"]="BBS Door / Descriptor File"
FILE_ERA_MAP["bbs"]="retro"
FILE_ICON_MAP["bbs"]="📟"
FILE_TYPE_MAP["ans"]="ansi_art"
FILE_DESCRIPTION_MAP["ans"]="ANSI Art (BBS Graphics)"
FILE_ERA_MAP["ans"]="retro"
FILE_ICON_MAP["ans"]="🎨"

# ============================================================================
# 2. CORE CLASSIFICATION FUNCTION
# ============================================================================

classify_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"  # Force lowercase

    # If it's a directory
    if [ -d "$file" ]; then
        cat <<EOF
{
  "file_type": "directory",
  "era": "n/a",
  "icon": "📁",
  "description": "Directory / Folder",
  "default_tags": "directory,folder",
  "extension": "dir"
}
EOF
        return 0
    fi

    # Default unknown
    local file_type="unknown"
    local era="unknown"
    local description="Unknown File Type"
    local icon="❓"

    # Lookup in maps
    if [[ -n "${FILE_TYPE_MAP[$ext]:-}" ]]; then
        file_type="${FILE_TYPE_MAP[$ext]}"
        era="${FILE_ERA_MAP[$ext]:-modern}"
        description="${FILE_DESCRIPTION_MAP[$ext]:-$file_type}"
        icon="${FILE_ICON_MAP[$ext]:-❓}"
    else
        # Try MIME type as fallback (placeholder)
        local mime_type=$(file -b --mime-type "$file" 2>/dev/null || echo "")
        case "$mime_type" in
            video/*) file_type="video"; icon="🎬"; era="modern"; description="Video (detected by MIME)";;
            image/*) file_type="image"; icon="🖼️"; era="modern"; description="Image (detected by MIME)";;
            audio/*) file_type="audio"; icon="🎵"; era="modern"; description="Audio (detected by MIME)";;
            text/plain) file_type="document"; icon="📄"; era="modern"; description="Plain Text (detected by MIME)";;
            application/pdf) file_type="document"; icon="📄"; era="modern"; description="PDF Document";;
            application/zip|application/x-rar|application/x-7z-compressed) 
                file_type="compressed"; icon="📦"; era="modern"; description="Archive (detected by MIME)";;
            *) file_type="obscure"; icon="🔮"; era="unknown"; description="Unrecognized MIME type";;
        esac
    fi

    # ----- SPECIAL CONTENT DETECTION (Placeholders) -----
    # 1. ANSI Art detection (Look for escape sequences in first 1KB)
    if [[ "$file_type" == "document" ]] || [[ "$file_type" == "obscure" ]]; then
        if head -c 1000 "$file" 2>/dev/null | grep -q -E '\x1B\[[0-9;]*m|\[[0-9;]*m|\[[0-9;]*[A-Za-z]'; then
            file_type="ansi_art"
            era="retro"
            description="ANSI Art (Detected via escape sequences)"
            icon="🎨"
        fi
    fi

    # 2. PLACEHOLDER: PDF Title extraction (just a placeholder, returns filename as title)
    if [[ "$file_type" == "document" ]] && [[ "$ext" == "pdf" ]]; then
        # In a real implementation, you'd run: pdfinfo "$file" | grep "Title"
        # For now, we just note it's a PDF.
        description="PDF Document (Metadata extraction placeholder)"
    fi

    # 3. PLACEHOLDER: EXIF for images
    if [[ "$file_type" == "image" ]] && command -v exiftool &>/dev/null; then
        # We don't output EXIF here to keep the main JSON small; 
        # EXIF extraction is done via media_tools.sh.
        description="Image File (EXIF extraction available via media_tools.sh)"
    fi

    # Default tags
    local default_tags="$file_type"
    if [[ "$era" == "retro" ]]; then
        default_tags="${default_tags},retro,vintage"
    elif [[ "$era" == "modern" ]]; then
        default_tags="${default_tags},modern"
    fi
    # Add extension as a tag if not already there
    default_tags="${default_tags},${ext}"

    # Output JSON
    cat <<EOF
{
  "file_type": "$file_type",
  "era": "$era",
  "icon": "$icon",
  "description": "$description",
  "extension": "$ext",
  "default_tags": "$default_tags"
}
EOF
}

# ============================================================================
# 3. DIRECT EXECUTION (Standalone Mode)
# ============================================================================

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    file_path="${1:-.}"
    classify_file "$file_path"
fi
