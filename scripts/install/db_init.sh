#!/bin/bash
# db_init.sh - Initialize the file archive SQLite database.
# Usage: ./db_init.sh [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default paths
DB_PATH="${DB_PATH:-$PROJECT_ROOT/file_archive.db}"
SCHEMA_PATH="${SCHEMA_PATH:-$PROJECT_ROOT/schema.sql}"
HIERARCHY_SEED="${HIERARCHY_SEED:-$PROJECT_ROOT/hierarchy_seed.sql}"
LOG_FILE="${LOG_FILE:-$PROJECT_ROOT/logs/db_init.log}"
mkdir -p "$(dirname "$LOG_FILE")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ---------------------------------------------------------------------------
# Helper functions
# ---------------------------------------------------------------------------
log() { echo -e "$*" | tee -a "$LOG_FILE"; }
info() { log "${BLUE}INFO:${NC} $*"; }
warn() { log "${YELLOW}WARN:${NC} $*"; }
error() { log "${RED}ERROR:${NC} $*"; }
success() { log "${GREEN}SUCCESS:${NC} $*"; }

die() {
    error "$*"
    exit 1
}

# ---------------------------------------------------------------------------
# Check dependencies
# ---------------------------------------------------------------------------
check_dependencies() {
    info "Checking dependencies..."

    local missing=()
    for cmd in sqlite3 jq; do
        if ! command -v "$cmd" &>/dev/null; then
            missing+=("$cmd")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        die "Missing required dependencies: ${missing[*]}. Please install them."
    fi

    # Optional: check for media tools (ffmpeg, exiftool) and warn
    if ! command -v ffmpeg &>/dev/null; then
        warn "ffmpeg not found (optional) – media processing will be limited."
    fi
    if ! command -v exiftool &>/dev/null; then
        warn "exiftool not found (optional) – image metadata will be limited."
    fi

    success "All required dependencies are present."
}

# ---------------------------------------------------------------------------
# Validate schema file
# ---------------------------------------------------------------------------
validate_schema() {
    if [ ! -f "$SCHEMA_PATH" ]; then
        die "Schema file not found: $SCHEMA_PATH"
    fi
    info "Schema file found: $SCHEMA_PATH"
}

# ---------------------------------------------------------------------------
# Create or force-recreate database
# ---------------------------------------------------------------------------
init_database() {
    local force="${1:-false}"

    if [ -f "$DB_PATH" ] && [ "$force" != "true" ]; then
        warn "Database already exists at $DB_PATH. Use --force to overwrite."
        read -p "Continue anyway? (y/N) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            info "Exiting."
            exit 0
        fi
    fi

    # Remove if exists and force
    if [ -f "$DB_PATH" ] && [ "$force" = "true" ]; then
        info "Removing existing database..."
        rm -f "$DB_PATH"
    fi

    info "Creating new database at $DB_PATH..."
    sqlite3 "$DB_PATH" "VACUUM;" 2>/dev/null || die "Failed to create database file."
    success "Database file created."
}

# ---------------------------------------------------------------------------
# Run schema.sql
# ---------------------------------------------------------------------------
apply_schema() {
    info "Applying schema..."
    if ! sqlite3 "$DB_PATH" < "$SCHEMA_PATH" 2>>"$LOG_FILE"; then
        die "Failed to apply schema. Check $LOG_FILE for details."
    fi
    success "Schema applied successfully."
}

# ---------------------------------------------------------------------------
# Seed hierarchy (if hierarchy_seed.sql exists)
# ---------------------------------------------------------------------------
seed_hierarchy() {
    if [ -f "$HIERARCHY_SEED" ]; then
        info "Seeding hierarchy from $HIERARCHY_SEED..."
        if ! sqlite3 "$DB_PATH" < "$HIERARCHY_SEED" 2>>"$LOG_FILE"; then
            warn "Failed to seed hierarchy (non-fatal). You can add categories later using hierarchy_manager.sh."
        else
            success "Hierarchy seeded successfully."
        fi
    else
        info "No hierarchy seed file found. Skipping hierarchy seeding."
        info "You can later seed categories using:"
        info "  ./hierarchy_manager.sh get_category <category> [subcategory]"
    fi
}

# ---------------------------------------------------------------------------
# Verify database
# ---------------------------------------------------------------------------
verify_database() {
    info "Verifying database..."
    local tables=$(sqlite3 "$DB_PATH" ".tables" 2>/dev/null)
    if [[ -z "$tables" ]]; then
        warn "No tables found – schema may not have been applied correctly."
    else
        success "Tables present: $tables"
    fi
}

# ---------------------------------------------------------------------------
# Show summary
# ---------------------------------------------------------------------------
show_summary() {
    echo ""
    success "✅ Database initialization complete!"
    echo "  Database: $DB_PATH"
    echo "  Schema:   $SCHEMA_PATH"
    echo ""
    info "Next steps:"
    echo "  1. Start ingesting files: ./trawl.sh check <path>"
    echo "  2. Launch web UI: python3 apps/app.py"
    echo "  3. Browse your archive at http://localhost:8080"
    echo ""
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------
main() {
    local force=false
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --force) force=true ;;
            --help|-h)
                echo "Usage: $0 [--force]"
                echo "  --force  Overwrite existing database"
                exit 0
                ;;
            *) die "Unknown option: $1";;
        esac
        shift
    done

    echo "🔧 File Archive Database Initializer"
    echo "===================================="
    echo ""

    check_dependencies
    validate_schema
    init_database "$force"
    apply_schema
    seed_hierarchy
    verify_database
    show_summary
}

main "$@"
