#!/bin/bash
# hierarchy_manager.sh - Taxonomy & conflict resolution engine
# Used by trawl.sh to assign categories, detect duplicates, and resolve conflicts.

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
DB_FILE="${DB_FILE:-./file_archive.db}"
HIERARCHY_CONFIG="${HIERARCHY_CONFIG:-./hierarchy.json}"  # optional, but we'll build a default if missing

# ----------------------------------------------------------------------------
# DEFAULT HIERARCHY (built-in, used if no config file)
# ----------------------------------------------------------------------------
declare -A CATEGORY_NAMES=(
    ["videos"]="Videos"
    ["audio"]="Audio"
    ["images"]="Images"
    ["image_3d"]="3D"
    ["image_vector"]="Vector"
    ["documents"]="Documents"
    ["games"]="Games"
    ["binaries"]="Binaries"
    ["archives"]="Archives"
    ["web"]="Web"
    ["system"]="System"
    ["obscure"]="Obscure"
    ["bbs"]="BBS"
    ["ansi_art"]="ANSI Art"
)

declare -A CATEGORY_ICONS=(
    ["videos"]="🎬"
    ["audio"]="🎵"
    ["images"]="🖼️"
    ["image_3d"]="🧊"
    ["image_vector"]="📐"
    ["documents"]="📄"
    ["games"]="🎮"
    ["binaries"]="⚙️"
    ["archives"]="📦"
    ["web"]="🌐"
    ["system"]="⚙️"
    ["obscure"]="🔮"
    ["bbs"]="📟"
    ["ansi_art"]="🎨"
)

# Subcategory mappings (simple parent->child relationship)
declare -A SUBCATEGORY_MAP=(
    ["videos/movies"]="Movies"
    ["videos/tv"]="TV"
    ["videos/documentary"]="Documentary"
    ["videos/music_video"]="Music Video"
    ["videos/anime"]="Anime"
    ["videos/short"]="Short"
    ["videos/home_video"]="Home Video"
    ["audio/music"]="Music"
    ["audio/music/albums"]="Albums"
    ["audio/music/singles"]="Singles"
    ["audio/music/remixes"]="Remixes"
    ["audio/audiobooks"]="Audio Books"
    ["audio/podcasts"]="Podcasts"
    ["audio/samples"]="Samples"
    ["audio/notifications"]="Notifications"
    ["audio/piezo"]="Piezo"
    ["audio/field_recording"]="Field Recording"
    ["images/photography"]="Photography"
    ["images/photography/portraits"]="Portraits"
    ["images/photography/landscapes"]="Landscapes"
    ["images/photography/street"]="Street"
    ["images/photography/macro"]="Macro"
    ["images/art"]="Art"
    ["images/art/digital"]="Digital Art"
    ["images/art/traditional"]="Traditional Art"
    ["images/art/pixel_art"]="Pixel Art"
    ["images/screenshots"]="Screenshots"
    ["images/meme"]="Meme"
    ["images/retro"]="Retro"
    ["images/retro/ansi"]="ANSI Art"
    ["images/retro/bbs"]="BBS Art"
    ["images/retro/demoscene"]="Demoscene"
    ["image_3d/models"]="Models"
    ["image_3d/models/characters"]="Characters"
    ["image_3d/models/environments"]="Environments"
    ["image_3d/models/props"]="Props"
    ["image_3d/scans"]="Scans"
    ["image_3d/splats"]="Splats"
    ["image_3d/voxel"]="Voxel"
    ["documents/text"]="Text"
    ["documents/text/notes"]="Notes"
    ["documents/text/markdown"]="Markdown"
    ["documents/text/code"]="Code"
    ["documents/text/logs"]="Logs"
    ["documents/office"]="Office"
    ["documents/office/word"]="Word"
    ["documents/office/excel"]="Excel"
    ["documents/office/powerpoint"]="PowerPoint"
    ["documents/office/pdf"]="PDF"
    ["games/roms"]="ROMs"
    ["games/roms/nes"]="NES"
    ["games/roms/snes"]="SNES"
    ["games/roms/gameboy"]="GameBoy"
    ["games/roms/gameboy/gb"]="GB"
    ["games/roms/gameboy/gbc"]="GBC"
    ["games/roms/gameboy/gba"]="GBA"
    ["games/roms/gameboy/3ds"]="3DS"
    ["games/roms/dreamcast"]="Dreamcast"
    ["games/roms/n64"]="N64"
    ["games/roms/playstation"]="PlayStation"
    ["games/roms/playstation/ps1"]="PS1"
    ["games/roms/playstation/ps2"]="PS2"
    ["games/roms/playstation/ps3"]="PS3"
    ["games/roms/playstation/psp"]="PSP"
    ["games/roms/sega"]="Sega"
    ["games/roms/sega/genesis"]="Genesis"
    ["games/roms/sega/saturn"]="Saturn"
    ["games/executables"]="Executables"
    ["games/executables/windows"]="Windows"
    ["games/executables/mac"]="Mac"
    ["games/executables/linux"]="Linux"
    ["games/executables/android"]="Android"
    ["games/executables/android/tv"]="Android TV"
    ["games/executables/android/tablet"]="Android Tablet"
    ["games/executables/msdos"]="MS-DOS"
    ["games/iso"]="ISO"
    ["binaries/executables"]="Executables"
    ["binaries/libraries"]="Libraries"
    ["binaries/drivers"]="Drivers"
    ["binaries/firmware"]="Firmware"
    ["binaries/packages"]="Packages"
    ["binaries/packages/deb"]="DEB"
    ["binaries/packages/rpm"]="RPM"
    ["binaries/packages/flatpak"]="Flatpak"
    ["binaries/packages/appimage"]="AppImage"
    ["archives/zip"]="ZIP"
    ["archives/rar"]="RAR"
    ["archives/7z"]="7Z"
    ["archives/tar"]="TAR"
)

# ============================================================================
# HELPER: SQLITE QUERY WRAPPER
# ============================================================================
sqlite_query() {
    sqlite3 "$DB_FILE" "$@" 2>/dev/null
}

# ============================================================================
# FUNCTION: suggest_category
# Description: Map a file type (from classify_filetype.sh) to a top-level category
# Usage: suggest_category <file_type>
# ============================================================================
suggest_category() {
    local file_type="$1"
    case "$file_type" in
        video)          echo "videos" ;;
        audio)          echo "audio" ;;
        image)          echo "images" ;;
        image_3d)       echo "image_3d" ;;
        image_vector)   echo "image_vector" ;;
        document)       echo "documents" ;;
        game)           echo "games" ;;
        system)         echo "binaries" ;;
        compressed)     echo "archives" ;;
        web)            echo "web" ;;
        ansi_art)       echo "ansi_art" ;;
        bbs)            echo "bbs" ;;
        obscure)        echo "obscure" ;;
        directory)      echo "directory" ;;
        *)              echo "documents" ;;   # fallback
    esac
}

# ============================================================================
# FUNCTION: get_hierarchy_path
# Description: Build human-readable hierarchy path from category and subcategory
# Usage: get_hierarchy_path <category> [subcategory]
# ============================================================================
get_hierarchy_path() {
    local category="$1"
    local subcategory="${2:-}"
    local path=""

    # Get category display name
    local cat_name="${CATEGORY_NAMES[$category]:-$category}"
    path="$cat_name"

    if [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ]; then
        # Build subcategory path by splitting on '/'
        local IFS='/'
        local parts=($subcategory)
        local sub_path=""
        for part in "${parts[@]}"; do
            if [ -n "$sub_path" ]; then
                sub_path="$sub_path/$part"
            else
                sub_path="$part"
            fi
            # Look up display name from map
            local display="${SUBCATEGORY_MAP[$category/$sub_path]:-}"
            if [ -n "$display" ]; then
                # Use display name for this segment
                # But we need to build the whole thing - simpler: just append the last segment name
                # We'll just build a simple path
                sub_path="$sub_path"  # keep raw
            fi
        done
        # Now build a readable string from the raw parts using the map
        local readable=""
        local current="$category"
        for part in "${parts[@]}"; do
            current="$current/$part"
            local display="${SUBCATEGORY_MAP[$current]:-$part}"
            if [ -n "$readable" ]; then
                readable="$readable → $display"
            else
                readable="$display"
            fi
        done
        path="$cat_name → $readable"
    fi

    echo "$path"
}

# ============================================================================
# FUNCTION: detect_conflicts
# Description: Check for conflicts for a given file (MD5, filename, device)
# Usage: detect_conflicts <md5> <filename> <file_type> [device_serial]
# Output: Comma-separated list of conflict types (or empty)
# ============================================================================
detect_conflicts() {
    local md5="$1"
    local filename="$2"
    local file_type="$3"
    local device_serial="${4:-}"

    local conflicts=()

    # 1. Check if MD5 already exists
    local existing_count=$(sqlite_query "SELECT COUNT(*) FROM files WHERE md5='$md5';" 2>/dev/null || echo "0")
    if [ "$existing_count" -gt 0 ]; then
        # Check if it's on a different device (if serial provided)
        if [ -n "$device_serial" ]; then
            local existing_device=$(sqlite_query "
                SELECT d.device_serial FROM files f
                JOIN locations l ON f.location_id = l.location_id
                JOIN devices d ON l.device_id = d.device_id
                WHERE f.md5='$md5' LIMIT 1;
            " 2>/dev/null || echo "")
            if [ -n "$existing_device" ] && [ "$existing_device" != "$device_serial" ]; then
                conflicts+=("same_md5_different_device")
            else
                conflicts+=("same_md5_same_device")
            fi
        else
            conflicts+=("same_md5")
        fi
    fi

    # 2. Check if same filename exists with different MD5
    # (only if we have a filename and it's not a temporary path)
    if [ -n "$filename" ] && [[ "$filename" != *"tmp"* ]]; then
        local existing_file=$(sqlite_query "
            SELECT md5 FROM files WHERE filename='$filename' LIMIT 1;
        " 2>/dev/null || echo "")
        if [ -n "$existing_file" ] && [ "$existing_file" != "$md5" ]; then
            conflicts+=("same_filename_different_md5")
        fi
    fi

    # 3. Check if same file exists on same device but different path (duplicate)
    if [ -n "$device_serial" ]; then
        local existing_count_same_device=$(sqlite_query "
            SELECT COUNT(*) FROM files f
            JOIN locations l ON f.location_id = l.location_id
            JOIN devices d ON l.device_id = d.device_id
            WHERE f.md5='$md5' AND d.device_serial='$device_serial';
        " 2>/dev/null || echo "0")
        if [ "$existing_count_same_device" -gt 0 ]; then
            # Already counted as same_md5_same_device, but we can treat as duplicate path
            conflicts+=("duplicate_path_same_device")
        fi
    fi

    # Output as comma-separated list
    if [ ${#conflicts[@]} -eq 0 ]; then
        echo ""
    else
        # Join with commas
        local IFS=','
        echo "${conflicts[*]}"
    fi
}

# ============================================================================
# FUNCTION: resolve_conflict
# Description: Interactively or automatically resolve a conflict
# Usage: resolve_conflict <conflict_types> <md5> <filename> <user_tags> [batch_mode]
# Output: resolution action (keep_existing, replace, merge, skip, keep_both, etc.)
# ============================================================================
resolve_conflict() {
    local conflict_types="$1"
    local md5="$2"
    local filename="$3"
    local user_tags="$4"
    local batch_mode="${5:-false}"

    # If no conflict, just return "no_conflict"
    if [ -z "$conflict_types" ]; then
        echo "no_conflict"
        return 0
    fi

    # Split conflict types
    IFS=',' read -ra types <<< "$conflict_types"

    # Default action
    local action="prompt"

    # If batch mode, auto-resolve with default: skip
    if [ "$batch_mode" = "true" ]; then
        echo "skip"
        return 0
    fi

    # Check for known conflict patterns and suggest resolutions
    for t in "${types[@]}"; do
        case "$t" in
            same_md5_different_device)
                # Prefer to keep both (record both locations)
                action="keep_both"
                ;;
            same_md5_same_device)
                # Same file already exists on same device -> skip
                action="skip"
                ;;
            same_filename_different_md5)
                # Different file with same name -> keep both (rename new)
                action="keep_both"
                ;;
            duplicate_path_same_device)
                # Exact duplicate path -> skip
                action="skip"
                ;;
            *)
                action="prompt"
                ;;
        esac
    done

    # If we determined an action and it's not prompt, echo it
    if [ "$action" != "prompt" ]; then
        echo "$action"
        return 0
    fi

    # Otherwise, interactive prompt
    echo ""
    echo -e "\033[1;33m⚡ CONFLICT DETECTED\033[0m"
    echo "  File: $filename"
    echo "  MD5:  $md5"
    echo "  Conflict types: $conflict_types"
    echo ""
    echo "  Options:"
    echo "    [1] Keep existing (skip new)"
    echo "    [2] Replace with new"
    echo "    [3] Merge metadata (keep both, combine tags)"
    echo "    [4] Keep both (rename new)"
    echo "    [5] Skip (do nothing)"
    echo ""
    read -p "  Choose (1-5): " -n 1 -r choice
    echo ""

    case "$choice" in
        1) echo "keep_existing" ;;
        2) echo "replace" ;;
        3) echo "merge" ;;
        4) echo "keep_both" ;;
        *) echo "skip" ;;
    esac
}

# ============================================================================
# FUNCTION: get_or_create_category
# Description: Ensure a category exists in the hierarchy table
# Usage: get_or_create_category <category> [subcategory]
# Output: category_id
# ============================================================================
get_or_create_category() {
    local category="$1"
    local subcategory="${2:-}"

    # Build the full path
    local full_path="$category"
    if [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ]; then
        full_path="$category/$subcategory"
    fi

    # Check if path already exists
    local cat_id=$(sqlite_query "SELECT category_id FROM hierarchy WHERE path='$full_path' LIMIT 1;" 2>/dev/null)
    if [ -n "$cat_id" ]; then
        echo "$cat_id"
        return 0
    fi

    # Need to create it, possibly with parent
    local parent_id=""
    if [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ]; then
        # Get parent category (the part before the last slash)
        local parent_path="${full_path%/*}"
        parent_id=$(get_or_create_category "$parent_path" "")
    else
        # Top-level category
        parent_id="NULL"
    fi

    local name="${CATEGORY_NAMES[$category]:-$category}"
    if [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ]; then
        # Try to get friendly name from map
        local friendly="${SUBCATEGORY_MAP[$full_path]:-}"
        if [ -n "$friendly" ]; then
            name="$friendly"
        else
            # Use last part of path
            name="${full_path##*/}"
        fi
    fi

    local icon="${CATEGORY_ICONS[$category]:-❓}"

    sqlite_query "
        INSERT INTO hierarchy (parent_id, name, description, icon, path)
        VALUES ($parent_id, '$name', '', '$icon', '$full_path');
    " 2>/dev/null

    sqlite_query "SELECT last_insert_rowid();" 2>/dev/null
}

# ============================================================================
# FUNCTION: assign_hierarchy_to_file
# Description: Link a file to a category in file_hierarchy
# Usage: assign_hierarchy_to_file <file_id> <category> [subcategory]
# ============================================================================
assign_hierarchy_to_file() {
    local file_id="$1"
    local category="$2"
    local subcategory="${3:-}"

    local cat_id=$(get_or_create_category "$category" "$subcategory")
    if [ -n "$cat_id" ]; then
        sqlite_query "
            INSERT OR IGNORE INTO file_hierarchy (file_id, category_id)
            VALUES ($file_id, $cat_id);
        " 2>/dev/null
    fi
}

# ============================================================================
# MAIN DISPATCHER (Command-line interface)
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command="${1:-help}"
    shift || true

    case "$command" in
        suggest)
            file_type="${1:-unknown}"
            suggest_category "$file_type"
            ;;
        path)
            category="${1:-}"
            subcategory="${2:-}"
            get_hierarchy_path "$category" "$subcategory"
            ;;
        detect_conflicts)
            md5="${1:-}"
            filename="${2:-}"
            file_type="${3:-}"
            device_serial="${4:-}"
            detect_conflicts "$md5" "$filename" "$file_type" "$device_serial"
            ;;
        resolve_conflict)
            conflicts="${1:-}"
            md5="${2:-}"
            filename="${3:-}"
            tags="${4:-}"
            batch="${5:-false}"
            resolve_conflict "$conflicts" "$md5" "$filename" "$tags" "$batch"
            ;;
        get_category)
            category="${1:-}"
            subcategory="${2:-}"
            get_or_create_category "$category" "$subcategory"
            ;;
        assign)
            file_id="${1:-}"
            category="${2:-}"
            subcategory="${3:-}"
            assign_hierarchy_to_file "$file_id" "$category" "$subcategory"
            ;;
        help|--help|-h)
            cat <<EOF
Hierarchy Manager

USAGE:
    hierarchy_manager.sh <command> [args]

COMMANDS:
    suggest <file_type>
        Suggest top-level category for a file type.

    path <category> [subcategory]
        Get human-readable hierarchy path.

    detect_conflicts <md5> <filename> <file_type> [device_serial]
        Detect conflicts for a file.

    resolve_conflict <conflict_types> <md5> <filename> <tags> <batch_mode>
        Resolve conflicts (interactive or automatic).

    get_category <category> [subcategory]
        Ensure category exists in DB and return its ID.

    assign <file_id> <category> [subcategory]
        Assign a file to a category.

ENVIRONMENT:
    DB_FILE - Path to SQLite database (default: ./file_archive.db)
EOF
            ;;
        *)
            echo "Unknown command: $command"
            exit 1
            ;;
    esac
fi
