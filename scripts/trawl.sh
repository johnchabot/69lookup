#!/bin/bash
# trawl.sh - The Digital Archivist's main tool
# Ingests files, extracts metadata, and builds a queryable archive.

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${DB_FILE:-$SCRIPT_DIR/file_archive.db}"
LOG_FILE="$SCRIPT_DIR/logs/trawl_$(date +%Y%m%d).log"
mkdir -p "$(dirname "$LOG_FILE")"

# Helper script locations (fallback to ./ if not found)
CLASSIFIER="${CLASSIFIER:-$SCRIPT_DIR/classify_filetype.sh}"
DEVICE_DETECTOR="${DEVICE_DETECTOR:-$SCRIPT_DIR/device_detector.sh}"
HIERARCHY_MANAGER="${HIERARCHY_MANAGER:-$SCRIPT_DIR/hierarchy_manager.sh}"
MEDIA_TOOLS="${MEDIA_TOOLS:-$SCRIPT_DIR/media_tools.sh}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# ============================================================================
# HELPERS
# ============================================================================
log() { echo -e "$*" | tee -a "$LOG_FILE"; }

error() { log "${RED}ERROR:${NC} $*"; }
warn() { log "${YELLOW}WARN:${NC} $*"; }
info() { log "${BLUE}INFO:${NC} $*"; }
success() { log "${GREEN}SUCCESS:${NC} $*"; }

# Normalize path (handles Windows/WSL)
normalize_path() {
    local path="$1"
    if [[ "$path" =~ ^[A-Za-z]: ]]; then
        local drive=$(echo "$path" | cut -d: -f1 | tr '[:upper:]' '[:lower:]')
        local rest=$(echo "$path" | cut -d: -f2- | sed 's/\\/\//g')
        echo "/mnt/$drive$rest"
    else
        echo "$path"
    fi
}

# Get MD5 hash (macOS/Linux)
get_md5() {
    local file="$1"
    if command -v md5 &>/dev/null; then
        md5 -q "$file" 2>/dev/null || echo ""
    elif command -v md5sum &>/dev/null; then
        md5sum "$file" 2>/dev/null | cut -d' ' -f1
    else
        echo ""
    fi
}

# ============================================================================
# SQLITE HELPERS
# ============================================================================
ensure_db() {
    if [ ! -f "$DB_FILE" ]; then
        info "Creating new SQLite database at $DB_FILE"
        sqlite3 "$DB_FILE" < "$SCRIPT_DIR/schema.sql" 2>/dev/null || {
            error "schema.sql not found. Please create it first."
            exit 1
        }
    fi
}

sqlite_query() {
    sqlite3 "$DB_FILE" "$@"
}

sqlite_insert_file() {
    local md5="$1"
    local filename="$2"
    local file_type="$3"
    local size="$4"
    local tags="$5"
    local status="$6"
    local metadata="$7"
    local location_id="$8"

    # Escape single quotes in strings
    md5=$(echo "$md5" | sed "s/'/''/g")
    filename=$(echo "$filename" | sed "s/'/''/g")
    file_type=$(echo "$file_type" | sed "s/'/''/g")
    tags=$(echo "$tags" | sed "s/'/''/g")
    status=$(echo "$status" | sed "s/'/''/g")
    metadata=$(echo "$metadata" | sed "s/'/''/g")

    sqlite_query "
        INSERT OR IGNORE INTO files (md5, filename, file_type, size_bytes, tags, status, metadata, location_id, indexed_at)
        VALUES ('$md5', '$filename', '$file_type', $size, '$tags', '$status', '$metadata', $location_id, datetime('now'));
    " 2>/dev/null
}

# Get or create location (device + volume + path)
get_or_create_location() {
    local absolute_path="$1"
    local device_info="$2"
    local volume_info="$3"
    
    # Extract device details
    local device_name=$(echo "$device_info" | jq -r '.device // "unknown"')
    local device_type=$(echo "$device_info" | jq -r '.type // "unknown"')
    local device_serial=$(echo "$device_info" | jq -r '.serial // ""')
    
    local volume_name=$(echo "$volume_info" | jq -r '.volume // "unknown"')
    local volume_serial=$(echo "$volume_info" | jq -r '.serial // ""')
    
    # Insert device if not exists
    local device_id=$(sqlite_query "SELECT device_id FROM devices WHERE device_serial = '$device_serial' LIMIT 1;" 2>/dev/null)
    if [ -z "$device_id" ]; then
        sqlite_query "
            INSERT INTO devices (device_type, device_name, device_serial, mount_point, metadata)
            VALUES ('$device_type', '$device_name', '$device_serial', '', '{}');
        "
        device_id=$(sqlite_query "SELECT last_insert_rowid();")
    fi
    
    # Insert volume if not exists
    local volume_id=$(sqlite_query "SELECT volume_id FROM volumes WHERE device_id = $device_id AND volume_serial = '$volume_serial' LIMIT 1;" 2>/dev/null)
    if [ -z "$volume_id" ]; then
        sqlite_query "
            INSERT INTO volumes (device_id, volume_name, volume_serial, metadata)
            VALUES ($device_id, '$volume_name', '$volume_serial', '{}');
        "
        volume_id=$(sqlite_query "SELECT last_insert_rowid();")
    fi
    
    # Insert location (path)
    local relative_path=$(basename "$absolute_path")
    local location_id=$(sqlite_query "SELECT location_id FROM locations WHERE device_id = $device_id AND volume_id = $volume_id AND relative_path = '$relative_path' LIMIT 1;" 2>/dev/null)
    if [ -z "$location_id" ]; then
        sqlite_query "
            INSERT INTO locations (device_id, volume_id, relative_path, absolute_path, is_mounted)
            VALUES ($device_id, $volume_id, '$relative_path', '$absolute_path', 1);
        "
        location_id=$(sqlite_query "SELECT last_insert_rowid();")
    fi
    
    echo "$location_id"
}

# ============================================================================
# COMMAND: CHECK - Inventory files
# ============================================================================
cmd_check() {
    local path="$1"
    local pattern="${2:-*}"
    local recursive="${3:-true}"
    
    info "CHECK: Inventorying files"
    info "  Path: $path"
    info "  Pattern: $pattern"
    
    path=$(normalize_path "$path")
    if [ ! -e "$path" ]; then
        error "Path not found: $path"
        return 1
    fi
    
    # Build find command
    local find_cmd="find \"$path\""
    [ "$recursive" != "true" ] && find_cmd="$find_cmd -maxdepth 1"
    find_cmd="$find_cmd -type f -name \"$pattern\" 2>/dev/null"
    
    info "Scanning files..."
    local count=0
    local temp_file="/tmp/trawl_check_$$.tmp"
    
    while IFS= read -r file; do
        [ -z "$file" ] && continue
        count=$((count + 1))
        
        local classification=$("$CLASSIFIER" "$file" 2>/dev/null || echo '{"file_type":"unknown","icon":"❓"}')
        local file_type=$(echo "$classification" | jq -r '.file_type // "unknown"')
        local icon=$(echo "$classification" | jq -r '.icon // "❓"')
        
        local md5=$(get_md5 "$file")
        if [ -z "$md5" ]; then
            warn "Skipping $file (MD5 failed)"
            continue
        fi
        
        # Check if already in DB
        local exists=$(sqlite_query "SELECT COUNT(*) FROM files WHERE md5='$md5';" 2>/dev/null || echo "0")
        local status_str=""
        if [ "$exists" -gt 0 ]; then
            status_str="${GREEN}✓ in DB${NC}"
        else
            status_str="${YELLOW}✗ new${NC}"
        fi
        
        echo -e "  $icon $file_type: $(basename "$file") - $status_str" | tee -a "$LOG_FILE"
        echo "$md5|$file|$file_type" >> "$temp_file"
        
    done < <(eval "$find_cmd" | sort)
    
    info "Check complete. Total files scanned: $count"
    if [ -f "$temp_file" ]; then
        local new_count=$(wc -l < "$temp_file" | tr -d ' ')
        info "New files not in DB: $new_count"
        # Save for later use by `add`
        echo "$temp_file" > "/tmp/trawl_last_check.tmp"
    fi
}

# ============================================================================
# COMMAND: ADD - Ingest files
# ============================================================================
cmd_add() {
    local path="${1:-}"
    local tag="${2:-auto}"
    local batch_mode="${3:-false}"
    local category="${4:-}"
    local subcategory="${5:-}"
    
    info "ADD: Ingesting files"
    
    ensure_db
    
    # Determine files to add
    local files_to_add=""
    if [ -z "$path" ] && [ -f "/tmp/trawl_last_check.tmp" ]; then
        info "Using files from last check"
        files_to_add=$(cat "/tmp/trawl_last_check.tmp")
    elif [ -n "$path" ]; then
        path=$(normalize_path "$path")
        if [ ! -e "$path" ]; then
            error "Path not found: $path"
            return 1
        fi
        info "Scanning: $path"
        files_to_add=$(find "$path" -type f -name "*" 2>/dev/null | while read -r f; do
            md5=$(get_md5 "$f")
            if [ -n "$md5" ]; then
                classification=$("$CLASSIFIER" "$f" 2>/dev/null || echo '{"file_type":"unknown"}')
                file_type=$(echo "$classification" | jq -r '.file_type // "unknown"')
                echo "$md5|$f|$file_type"
            fi
        done)
    else
        error "No path specified and no previous check results."
        return 1
    fi
    
    if [ -z "$files_to_add" ]; then
        warn "No files to add"
        return 0
    fi
    
    local total=$(echo "$files_to_add" | wc -l | tr -d ' ')
    info "Processing $total files..."
    
    local processed=0
    local skipped=0
    local conflicts=0
    
    while IFS='|' read -r md5 file file_type; do
        [ -z "$md5" ] && continue
        
        echo -e "\n  📥 Processing: $(basename "$file")" | tee -a "$LOG_FILE"
        
        # Check if MD5 already exists
        local exists=$(sqlite_query "SELECT COUNT(*) FROM files WHERE md5='$md5';" 2>/dev/null || echo "0")
        if [ "$exists" -gt 0 ]; then
            warn "⏭️ Already in DB: $(basename "$file")"
            skipped=$((skipped + 1))
            continue
        fi
        
        # Detect device and volume
        local device_info=$("$DEVICE_DETECTOR" detect "$file" 2>/dev/null || echo '{"device":"unknown","type":"unknown"}')
        local volume_info=$("$DEVICE_DETECTOR" volume "$file" 2>/dev/null || echo '{"volume":"unknown"}')
        local device_type=$(echo "$device_info" | jq -r '.type // "unknown"')
        local volume_name=$(echo "$volume_info" | jq -r '.volume // "unknown"')
        
        # Get location ID
        local location_id=$(get_or_create_location "$file" "$device_info" "$volume_info")
        echo "  💿 Device: $device_type, Volume: $volume_name" | tee -a "$LOG_FILE"
        
        # Suggest category if not given
        if [ -z "$category" ]; then
            category=$("$HIERARCHY_MANAGER" suggest "$file_type" 2>/dev/null || echo "documents")
            echo "  🏷️ Suggested category: $category" | tee -a "$LOG_FILE"
        fi
        
        # Hierarchy path
        local hierarchy_path=$("$HIERARCHY_MANAGER" path "$category" "$subcategory" 2>/dev/null || echo "$category")
        echo "  📂 Hierarchy: $hierarchy_path" | tee -a "$LOG_FILE"
        
        # Get basic stats
        local size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo "0")
        local created=$(stat -c %y "$file" 2>/dev/null | cut -d. -f1 || stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || echo "")
        local modified=$(stat -c %y "$file" 2>/dev/null | cut -d. -f1 || stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || echo "")
        
        # Extract metadata (simplified)
        local metadata="{}"
        if [ -x "$MEDIA_TOOLS" ]; then
            case "$file_type" in
                video|audio)
                    metadata=$("$MEDIA_TOOLS" video_metadata "$file" 2>/dev/null || echo "{}")
                    ;;
                image)
                    metadata=$(exiftool -j "$file" 2>/dev/null | jq -c '.[0]' 2>/dev/null || echo "{}")
                    ;;
                document)
                    if [ "${file##*.}" = "pdf" ] && command -v pdfinfo &>/dev/null; then
                        metadata=$(pdfinfo "$file" 2>/dev/null | jq -R -s -c 'split("\n") | map(select(. != ""))' 2>/dev/null || echo "{}")
                    fi
                    ;;
            esac
        fi
        
        # Interactive tagging (unless batch)
        local tags="$tag"
        if [ "$batch_mode" = false ] && [ "$tag" = "auto" ]; then
            echo -n "    🏷️ Tags (comma-separated, Enter for '$file_type'): "
            read -r input_tags
            if [ -n "$input_tags" ]; then
                tags="$input_tags"
            else
                tags="$file_type,auto"
            fi
        elif [ "$tag" = "auto" ]; then
            tags="$file_type,auto"
        fi
        
        # Insert into SQLite
        sqlite_insert_file "$md5" "$(basename "$file")" "$file_type" "$size" "$tags" "complete" "$metadata" "$location_id"
        
        processed=$((processed + 1))
        success "Added: $(basename "$file")"
        
    done <<< "$files_to_add"
    
    info "Add complete. Added: $processed, Skipped: $skipped, Conflicts: $conflicts"
}

# ============================================================================
# COMMAND: PULL - Query database
# ============================================================================
cmd_pull() {
    local query="${1:-}"
    local query_type="${2:-md5}"
    
    info "PULL: Querying database"
    
    ensure_db
    
    case "$query_type" in
        md5)
            sqlite_query "SELECT * FROM v_files_full WHERE md5 LIKE '%$query%';" -header -column
            ;;
        filename)
            sqlite_query "SELECT * FROM v_files_full WHERE filename LIKE '%$query%';" -header -column
            ;;
        type)
            sqlite_query "SELECT * FROM v_files_full WHERE file_type = '$query';" -header -column
            ;;
        tag)
            sqlite_query "SELECT * FROM v_files_full WHERE tags LIKE '%$query%';" -header -column
            ;;
        category)
            sqlite_query "
                SELECT f.* FROM v_files_full f
                JOIN file_hierarchy fh ON f.file_id = fh.file_id
                JOIN hierarchy h ON fh.category_id = h.category_id
                WHERE h.path LIKE '%$query%';
            " -header -column
            ;;
        stats)
            echo "📊 Database Statistics"
            echo "======================"
            sqlite_query "SELECT 'Total files' AS Metric, COUNT(*) AS Value FROM files;"
            sqlite_query "SELECT 'Total size (GB)' AS Metric, ROUND(SUM(size_bytes)/1e9, 2) AS Value FROM files;"
            sqlite_query "SELECT 'File types' AS Metric, COUNT(DISTINCT file_type) AS Value FROM files;"
            sqlite_query "SELECT 'Devices' AS Metric, COUNT(DISTINCT device_id) AS Value FROM locations;"
            echo ""
            echo "By File Type:"
            sqlite_query "SELECT file_type, COUNT(*) AS count FROM files GROUP BY file_type ORDER BY count DESC;"
            echo ""
            echo "By Device Type:"
            sqlite_query "SELECT device_type, COUNT(*) AS count FROM v_files_full GROUP BY device_type ORDER BY count DESC;"
            ;;
        *)
            echo "Unknown query type. Use: md5, filename, type, tag, category, stats"
            ;;
    esac
}

# ============================================================================
# MAIN DISPATCHER
# ============================================================================
show_help() {
    cat <<EOF
📁 trawl.sh - Digital Archivist

USAGE:
    trawl.sh <command> [options]

COMMANDS:
    check <path> [pattern] [recursive]
        Inventory files and report new ones.
        Examples:
            trawl.sh check ~/Documents
            trawl.sh check ~/Videos "*.mp4" true

    add [path] [tag] [batch] [category] [subcategory]
        Ingest files into the database.
        Examples:
            trawl.sh add                    # Use last check results
            trawl.sh add ~/Downloads        # Add all files
            trawl.sh add ~/Videos "movie" false "videos" "movies"
            trawl.sh add ~/Music "" true "audio" "music"

    pull <query> [type]
        Query the database.
        Types: md5, filename, type, tag, category, stats
        Examples:
            trawl.sh pull a1b2c3d4 md5
            trawl.sh pull report.pdf filename
            trawl.sh pull video type
            trawl.sh pull important tag
            trawl.sh pull stats

ENVIRONMENT:
    DB_FILE     Path to SQLite database (default: ./file_archive.db)
    LOG_FILE    Path to log file (default: ./logs/trawl_YYYYMMDD.log)

EOF
}

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        check) cmd_check "$@" ;;
        add) cmd_add "$@" ;;
        pull) cmd_pull "$@" ;;
        help|--help|-h) show_help ;;
        *) error "Unknown command: $command"; show_help; exit 1 ;;
    esac
}

# Ensure we have a database directory
mkdir -p "$(dirname "$DB_FILE")"

# Run
main "$@"
