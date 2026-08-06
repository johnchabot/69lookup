#!/bin/bash
# db_init.sh - Initialize the file archive SQLite database.
# Usage: ./db_init.sh [--force]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Default paths
DB_PATH="${DB_PATH:-$PROJECT_ROOT/file_archive.db}"
SCHEMA_PATH="${SCHEMA_PATH:-$PROJECT_ROOT/schema.sql}"
HIERARCHY_SEED_STATIC="${HIERARCHY_SEED_STATIC:-$PROJECT_ROOT/hierarchy_seed.sql}"
HIERARCHY_MANAGER="${HIERARCHY_MANAGER:-$PROJECT_ROOT/hierarchy_manager.sh}"
LOG_FILE="${LOG_FILE:-$PROJECT_ROOT/logs/db_init.log}"
mkdir -p "$(dirname "$LOG_FILE")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

    # Optional: check if hierarchy_manager.sh exists (for dynamic seeding)
    if [ ! -f "$HIERARCHY_MANAGER" ]; then
        warn "hierarchy_manager.sh not found at $HIERARCHY_MANAGER – will use static seed if available."
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
# Seed hierarchy
# ---------------------------------------------------------------------------
seed_hierarchy() {
    info "Seeding hierarchy..."

    # Prefer dynamic generation via hierarchy_manager.sh
    if [ -f "$HIERARCHY_MANAGER" ] && [ -x "$HIERARCHY_MANAGER" ]; then
        info "Using hierarchy_manager.sh to generate seed from config/hierarchy.json..."
        if ! "$HIERARCHY_MANAGER" generate_seed 2>>"$LOG_FILE" | sqlite3 "$DB_FILE" 2>>"$LOG_FILE"; then
            warn "Dynamic hierarchy seeding failed. Falling back to static seed file."
        else
            success "Hierarchy seeded dynamically from config/hierarchy.json."
            return 0
        fi
    fi

    # Fallback to static seed file
    if [ -f "$HIERARCHY_SEED_STATIC" ]; then
        info "Using static hierarchy_seed.sql..."
        if ! sqlite3 "$DB_PATH" < "$HIERARCHY_SEED_STATIC" 2>>"$LOG_FILE"; then
            warn "Static hierarchy seeding failed (non-fatal). You can seed later with hierarchy_manager.sh."
        else
            success "Hierarchy seeded from static file."
            return 0
        fi
    else
        warn "No hierarchy seed found. Skipping hierarchy seeding."
        info "You can seed later by running:"
        info "  $HIERARCHY_MANAGER generate_seed | sqlite3 $DB_PATH"
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

    # Check hierarchy count
    local count=$(sqlite3 "$DB_PATH" "SELECT COUNT(*) FROM hierarchy;" 2>/dev/null || echo "0")
    if [ "$count" -gt 0 ]; then
        success "Hierarchy table has $count categories."
    else
        warn "Hierarchy table is empty (you may need to seed it manually)."
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
