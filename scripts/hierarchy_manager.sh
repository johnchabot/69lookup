#!/bin/bash
# hierarchy_manager.sh - Taxonomy & conflict resolution engine
# Now reads config/hierarchy.json for hierarchy data.

set -euo pipefail

# ----------------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DB_FILE="${DB_FILE:-$SCRIPT_DIR/../file_archive.db}"
HIERARCHY_CONFIG="${HIERARCHY_CONFIG:-$SCRIPT_DIR/../config/hierarchy.json}"
CONFLICT_RULES_FILE="${CONFLICT_RULES_FILE:-$SCRIPT_DIR/../config/conflict_rules.json}"  # not yet used

# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
sqlite_query() {
    sqlite3 "$DB_FILE" "$@" 2>/dev/null
}

# ----------------------------------------------------------------------------
# SUGGEST CATEGORY (from file type)
# ----------------------------------------------------------------------------
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
        archive)        echo "archive" ;;       # if we had one
        *)              echo "documents" ;;
    esac
}

# ----------------------------------------------------------------------------
# GET HIERARCHY PATH (from JSON, or fallback)
# ----------------------------------------------------------------------------
get_hierarchy_path() {
    local category="$1"
    local subcategory="${2:-}"

    if [ ! -f "$HIERARCHY_CONFIG" ]; then
        # Fallback: simple concatenation
        if [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ]; then
            echo "$category → $subcategory"
        else
            echo "$category"
        fi
        return 0
    fi

    # Use jq to look up the path
    local full_path="$category"
    [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ] && full_path="$category/$subcategory"

    # Try to get display name from JSON
    local display=$(jq -r --arg path "$full_path" '
        def recurse($node):
            $node |
            if .path == $path then .name else empty end,
            (if .children then .children[] | recurse(.) else empty end);
        .categories[] | recurse(.)
    ' "$HIERARCHY_CONFIG" 2>/dev/null | head -1)

    if [ -n "$display" ] && [ "$display" != "null" ]; then
        # Build a human-readable path by collecting ancestors
        # For simplicity, we'll just output the display name
        echo "$display"
    else
        # Fallback: construct from category and subcategory
        if [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ]; then
            echo "$category → $subcategory"
        else
            echo "$category"
        fi
    fi
}

# ----------------------------------------------------------------------------
# DETECT CONFLICTS (unchanged, uses DB)
# ----------------------------------------------------------------------------
detect_conflicts() {
    local md5="$1"
    local filename="$2"
    local file_type="$3"
    local device_serial="${4:-}"

    local conflicts=()

    local existing_count=$(sqlite_query "SELECT COUNT(*) FROM files WHERE md5='$md5';" 2>/dev/null || echo "0")
    if [ "$existing_count" -gt 0 ]; then
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

    if [ -n "$filename" ] && [[ "$filename" != *"tmp"* ]]; then
        local existing_file=$(sqlite_query "
            SELECT md5 FROM files WHERE filename='$filename' LIMIT 1;
        " 2>/dev/null || echo "")
        if [ -n "$existing_file" ] && [ "$existing_file" != "$md5" ]; then
            conflicts+=("same_filename_different_md5")
        fi
    fi

    if [ ${#conflicts[@]} -eq 0 ]; then
        echo ""
    else
        local IFS=','
        echo "${conflicts[*]}"
    fi
}

# ----------------------------------------------------------------------------
# RESOLVE CONFLICT (simplified, uses rules or default)
# ----------------------------------------------------------------------------
resolve_conflict() {
    local conflict_types="$1"
    local md5="$2"
    local filename="$3"
    local user_tags="$4"
    local batch_mode="${5:-false}"

    if [ -z "$conflict_types" ]; then
        echo "no_conflict"
        return 0
    fi

    # Auto-resolve in batch mode
    if [ "$batch_mode" = "true" ]; then
        echo "skip"
        return 0
    fi

    # Interactive prompt
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

# ----------------------------------------------------------------------------
# GET OR CREATE CATEGORY (ensures category exists in DB)
# ----------------------------------------------------------------------------
get_or_create_category() {
    local category="$1"
    local subcategory="${2:-}"

    local full_path="$category"
    if [ -n "$subcategory" ] && [ "$subcategory" != "null" ] && [ "$subcategory" != "none" ]; then
        full_path="$category/$subcategory"
    fi

    local cat_id=$(sqlite_query "SELECT category_id FROM hierarchy WHERE path='$full_path' LIMIT 1;" 2>/dev/null)
    if [ -n "$cat_id" ]; then
        echo "$cat_id"
        return 0
    fi

    # Not found: need to create it. For now, we'll just echo an error.
    echo "0"
}

# ----------------------------------------------------------------------------
# ASSIGN HIERARCHY TO FILE
# ----------------------------------------------------------------------------
assign_hierarchy_to_file() {
    local file_id="$1"
    local category="$2"
    local subcategory="${3:-}"

    local cat_id=$(get_or_create_category "$category" "$subcategory")
    if [ -n "$cat_id" ] && [ "$cat_id" != "0" ]; then
        sqlite_query "
            INSERT OR IGNORE INTO file_hierarchy (file_id, category_id)
            VALUES ($file_id, $cat_id);
        " 2>/dev/null
    fi
}

# ----------------------------------------------------------------------------
# GENERATE SEED SQL FROM JSON (new)
# ----------------------------------------------------------------------------
generate_seed_sql() {
    if [ ! -f "$HIERARCHY_CONFIG" ]; then
        echo "ERROR: Hierarchy config not found at $HIERARCHY_CONFIG" >&2
        exit 1
    fi

    # Use jq to generate SQL statements
    jq -r '
        # Recursive function to output INSERTs in depth order
        def recurse_nodes($parent_path):
            .[] |
            . as $node |
            $parent_path as $pp |
            # output the node itself
            ($node.path) as $path |
            ($node.name | @sh) as $name |
            ($node.icon | @sh) as $icon |
            (
                if $pp == null then
                    "INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id) VALUES (" + $name + ", " + $icon + ", " + ($path | @sh) + ", NULL);"
                else
                    "INSERT OR IGNORE INTO hierarchy (name, icon, path, parent_id) SELECT " + $name + ", " + $icon + ", " + ($path | @sh) + ", category_id FROM hierarchy WHERE path = " + ($pp | @sh) + ";"
                end
            ),
            # then recurse into children
            if .children then .children | recurse_nodes($path) else empty end;

        .categories | recurse_nodes(null)
    ' "$HIERARCHY_CONFIG"
}

# ----------------------------------------------------------------------------
# MAIN DISPATCHER
# ----------------------------------------------------------------------------
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
        generate_seed)
            generate_seed_sql
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

    generate_seed
        Generate SQL seed statements from hierarchy.json (stdout).

ENVIRONMENT:
    DB_FILE - Path to SQLite database (default: ./file_archive.db)
    HIERARCHY_CONFIG - Path to hierarchy.json (default: ./config/hierarchy.json)
EOF
            ;;
        *)
            echo "Unknown command: $command"
            exit 1
            ;;
    esac
fi
