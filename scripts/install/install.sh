#!/bin/bash
# install.sh - Project installer and health check.
# Usage: ./install.sh [--fix] [--quiet]

set -euo pipefail

# ============================================================================
# CONFIGURATION (Edit these to match your environment)
# ============================================================================
PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd 2>/dev/null || pwd)"
DB_PATH="${DB_PATH:-$PROJECT_ROOT/file_archive.db}"
CACHE_PATH="${CACHE_PATH:-$PROJECT_ROOT/media_cache}"
LOG_DIR="${LOG_DIR:-$PROJECT_ROOT/logs}"
SCHEMA_PATH="${SCHEMA_PATH:-$PROJECT_ROOT/schema.sql}"

# Scripts to check (relative to PROJECT_ROOT)
SCRIPTS=(
    "trawl.sh"
    "classify_filetype.sh"
    "device_detector.sh"
    "hierarchy_manager.sh"
    "media_tools.sh"
)

# ============================================================================
# INITIALIZATION
# ============================================================================
FIX_MODE=false
QUIET=false
while [[ $# -gt 0 ]]; do
    case "$1" in
        --fix)   FIX_MODE=true ;;
        --quiet) QUIET=false ;;  # Actually, we'll keep quiet mode for less output
        --help)  echo "Usage: $0 [--fix] [--quiet]"; exit 0 ;;
        *)       echo "Unknown option: $1"; exit 1 ;;
    esac
    shift
done

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()    { $QUIET || echo -e "${BLUE}ℹ${NC} $*"; }
warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
error()   { echo -e "${RED}✗${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }

# ============================================================================
# FUNCTION: check_os
# ============================================================================
check_os() {
    info "Checking OS..."
    local os_type=$(uname -s)
    case "$os_type" in
        Darwin)  success "macOS detected" ;;
        Linux)   success "Linux detected" ;;
        *)       warn "Unsupported OS: $os_type (things may still work)" ;;
    esac
    echo "$os_type"
}

# ============================================================================
# FUNCTION: check_scripts
# ============================================================================
check_scripts() {
    info "Checking required scripts..."
    local all_ok=true
    for script in "${SCRIPTS[@]}"; do
        local full_path="$PROJECT_ROOT/$script"
        if [ -f "$full_path" ]; then
            if [ -x "$full_path" ]; then
                success "Script $script exists and is executable"
            else
                warn "Script $script exists but is NOT executable"
                if $FIX_MODE; then
                    chmod +x "$full_path"
                    success "  → Fixed permissions"
                fi
                all_ok=false
            fi
        else
            error "Script $script NOT FOUND at $full_path"
            all_ok=false
        fi
    done
    $all_ok || warn "Some scripts are missing or not executable. Use --fix to correct permissions."
}

# ============================================================================
# FUNCTION: check_dependencies
# ============================================================================
check_dependencies() {
    info "Checking dependencies..."
    local deps_ok=true
    local deps_list=("sqlite3" "jq")
    for dep in "${deps_list[@]}"; do
        if command -v "$dep" &>/dev/null; then
            success "Found $dep"
        else
            error "Missing $dep (required)"
            deps_ok=false
        fi
    done

    # Optional dependencies
    for dep in ffmpeg ffprobe exiftool; do
        if command -v "$dep" &>/dev/null; then
            success "Found $dep (optional)"
        else
            warn "Missing $dep (optional) – limited media processing"
        fi
    done

    # Python + Flask
    if command -v python3 &>/dev/null; then
        success "Found python3"
        if python3 -c "import flask" 2>/dev/null; then
            success "Found Flask (Python module)"
        else
            warn "Flask not installed (required for web UI). Install with: pip install flask"
        fi
    else
        error "python3 not found (required for web UI)"
        deps_ok=false
    fi

    $deps_ok || warn "Some required dependencies are missing."
}

# ============================================================================
# FUNCTION: check_database
# ============================================================================
check_database() {
    info "Checking database..."
    info "  DB Path: $DB_PATH"
    info "  Connection: sqlite3://$DB_PATH"

    if [ -f "$DB_PATH" ]; then
        success "Database file exists"
        # Check if schema is applied (look for the 'files' table)
        if sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='files';" | grep -q files; then
            success "Schema appears to be applied (found 'files' table)"
            # Check if hierarchy table exists
            if sqlite3 "$DB_PATH" "SELECT name FROM sqlite_master WHERE type='table' AND name='hierarchy';" | grep -q hierarchy; then
                success "Hierarchy table exists"
                local cat_count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM hierarchy;" 2>/dev/null || echo "0")
                success "  $cat_count categories in hierarchy"
            else
                warn "Hierarchy table not found – run ./scripts/installer/db_init.sh to seed"
            fi
        else
            error "Schema not applied. Run ./scripts/installer/db_init.sh"
            return 1
        fi
    else
        warn "Database file not found at $DB_PATH"
        if $FIX_MODE; then
            info "Attempting to initialize database via db_init.sh..."
            if [ -f "$PROJECT_ROOT/scripts/installer/db_init.sh" ]; then
                "$PROJECT_ROOT/scripts/installer/db_init.sh" --force
            else
                error "db_init.sh not found. Please create database manually."
            fi
        fi
    fi
}

# ============================================================================
# FUNCTION: check_cache
# ============================================================================
check_cache() {
    info "Checking cache..."
    local cache_dirs=(
        "$CACHE_PATH"
        "$CACHE_PATH/thumbnails"
        "$CACHE_PATH/scenes"
        "$CACHE_PATH/transcripts"
        "$CACHE_PATH/metadata"
    )

    for dir in "${cache_dirs[@]}"; do
        if [ ! -d "$dir" ]; then
            info "Creating cache directory: $dir"
            mkdir -p "$dir"
        fi
        if [ -w "$dir" ]; then
            # Test write
            if touch "$dir/.write_test" 2>/dev/null; then
                rm -f "$dir/.write_test"
                success "Cache directory $dir exists and is writable"
            else
                error "Cache directory $dir exists but is NOT writable"
            fi
        else
            error "Cache directory $dir does not exist or is not writable"
        fi
    done
}

# ============================================================================
# FUNCTION: check_logs
# ============================================================================
check_logs() {
    info "Checking logs directory..."
    if [ ! -d "$LOG_DIR" ]; then
        info "Creating logs directory: $LOG_DIR"
        mkdir -p "$LOG_DIR"
    fi
    if [ -w "$LOG_DIR" ]; then
        # Test write
        if touch "$LOG_DIR/.write_test" 2>/dev/null; then
            rm -f "$LOG_DIR/.write_test"
            success "Logs directory exists and is writable"
        else
            error "Logs directory exists but is NOT writable"
        fi
    else
        error "Logs directory not writable"
    fi
}

# ============================================================================
# FUNCTION: summary
# ============================================================================
summary() {
    echo ""
    echo "=========================================="
    echo "  INSTALLER SUMMARY"
    echo "=========================================="
    echo "  Project Root: $PROJECT_ROOT"
    echo "  DB Path:      $DB_PATH"
    echo "  Cache Path:   $CACHE_PATH"
    echo "  Logs Dir:     $LOG_DIR"
    echo ""
    echo "  To complete setup:"
    echo "    - Ensure all dependencies are installed"
    echo "    - Run ./scripts/installer/db_init.sh to initialize the database"
    echo "    - Start ingesting files with ./trawl.sh check <path>"
    echo "    - Launch web UI: python3 apps/app.py"
    echo "=========================================="
}

# ============================================================================
# MAIN
# ============================================================================
main() {
    echo "🔧 File Archive Installer"
    echo "========================="
    echo ""

    check_os
    echo ""
    check_scripts
    echo ""
    check_dependencies
    echo ""
    check_database
    echo ""
    check_cache
    echo ""
    check_logs
    echo ""
    summary
}

main "$@"
