#!/bin/bash
# get_filetype_metadata.sh - Extract type-specific metadata from any file.
# Usage: ./get_filetype_metadata.sh <file_path>
# Output: JSON (stdout)

set -euo pipefail

# ----------------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------------
FFPROBE_CMD="${FFPROBE_CMD:-ffprobe}"
EXIFTOOL_CMD="${EXIFTOOL_CMD:-exiftool}"
MEDIAINFO_CMD="${MEDIAINFO_CMD:-mediainfo}"
PDFINFO_CMD="${PDFINFO_CMD:-pdfinfo}"
ZIPINFO_CMD="${ZIPINFO_CMD:-zipinfo}"
UNRAR_CMD="${UNRAR_CMD:-unrar}"
SEVENZ_CMD="${SEVENZ_CMD:-7z}"
IDENTIFY_CMD="${IDENTIFY_CMD:-identify}"
FILE_CMD="${FILE_CMD:-file}"

# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
log_error() { echo "❌ $*" >&2; }

# Convert plain text key: value to JSON
text_to_json() {
    local input="$1"
    echo "$input" | jq -R -s -c '
        split("\n") |
        map(select(. != "")) |
        map(
            capture("^(?<key>[^:]+):\\s*(?<value>.*)$") // {key: ., value: null}
        ) |
        from_entries
    '
}

# Fallback: use `file -b` and `stat`
fallback_metadata() {
    local file="$1"
    local file_info=$($FILE_CMD -b "$file" 2>/dev/null || echo "Unknown")
    local size=$(stat -c %s "$file" 2>/dev/null || stat -f %z "$file" 2>/dev/null || echo "0")
    local mtime=$(stat -c %y "$file" 2>/dev/null | cut -d. -f1 || stat -f %Sm -t "%Y-%m-%d %H:%M:%S" "$file" 2>/dev/null || echo "Unknown")
    jq -n \
        --arg tool "fallback" \
        --arg info "$file_info" \
        --arg size "$size" \
        --arg mtime "$mtime" \
        '{tool: $tool, file_info: $info, size_bytes: ($size | tonumber), modified: $mtime}'
}

# ----------------------------------------------------------------------------
# MAIN DISPATCH
# ----------------------------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "Usage: $0 <file_path>" >&2
    exit 1
fi

INPUT="$1"

if [ ! -f "$INPUT" ]; then
    log_error "File not found: $INPUT"
    exit 1
fi

# Detect MIME type and extension
MIME_TYPE=$($FILE_CMD -b --mime-type "$INPUT" 2>/dev/null || echo "")
EXT="${INPUT##*.}"
EXT="${EXT,,}"

# ----------------------------------------------------------------------------
# BRANCH: Video / Audio (ffprobe)
# ----------------------------------------------------------------------------
if [[ "$MIME_TYPE" == video/* ]] || [[ "$MIME_TYPE" == audio/* ]] || \
   [[ "$EXT" =~ ^(mp4|mov|avi|mkv|webm|flv|mp3|flac|wav|aac|ogg|m4a|opus)$ ]]; then
    if command -v "$FFPROBE_CMD" &>/dev/null; then
        $FFPROBE_CMD -v quiet -print_format json -show_format -show_streams "$INPUT" 2>/dev/null | \
            jq -c --arg tool "ffprobe" '{tool: $tool, data: .}'
        exit 0
    elif command -v "$MEDIAINFO_CMD" &>/dev/null; then
        $MEDIAINFO_CMD --Output=JSON "$INPUT" 2>/dev/null | \
            jq -c --arg tool "mediainfo" '{tool: $tool, data: .}'
        exit 0
    else
        fallback_metadata "$INPUT"
    fi
fi

# ----------------------------------------------------------------------------
# BRANCH: Image (exiftool / identify)
# ----------------------------------------------------------------------------
if [[ "$MIME_TYPE" == image/* ]] || \
   [[ "$EXT" =~ ^(jpg|jpeg|png|gif|bmp|tiff|webp|heic|raw|cr2|nef)$ ]]; then
    if command -v "$EXIFTOOL_CMD" &>/dev/null; then
        $EXIFTOOL_CMD -j "$INPUT" 2>/dev/null | \
            jq -c --arg tool "exiftool" '.[0] as $d | {tool: $tool, data: $d}'
        exit 0
    elif command -v "$IDENTIFY_CMD" &>/dev/null; then
        $IDENTIFY_CMD -format '{"width":%w,"height":%h,"format":"%m"}' "$INPUT" 2>/dev/null | \
            jq -c --arg tool "imagemagick" '{tool: $tool, data: .}'
        exit 0
    else
        fallback_metadata "$INPUT"
    fi
fi

# ----------------------------------------------------------------------------
# BRANCH: PDF Document (pdfinfo)
# ----------------------------------------------------------------------------
if [[ "$MIME_TYPE" == application/pdf ]] || [[ "$EXT" == "pdf" ]]; then
    if command -v "$PDFINFO_CMD" &>/dev/null; then
        PDF_OUTPUT=$($PDFINFO_CMD "$INPUT" 2>/dev/null)
        if [ -n "$PDF_OUTPUT" ]; then
            echo "$PDF_OUTPUT" | jq -R -s -c --arg tool "pdfinfo" '
                split("\n") |
                map(select(. != "")) |
                map(
                    capture("^(?<key>[^:]+):\\s*(?<value>.*)$") // {key: ., value: null}
                ) |
                from_entries as $d |
                {tool: $tool, data: $d}
            '
            exit 0
        fi
    fi
    fallback_metadata "$INPUT"
fi

# ----------------------------------------------------------------------------
# BRANCH: Office Documents (docx, xlsx, pptx) - peek inside zip
# ----------------------------------------------------------------------------
if [[ "$EXT" =~ ^(docx|xlsx|pptx|odt|ods|odp)$ ]]; then
    if command -v "$ZIPINFO_CMD" &>/dev/null; then
        FILE_COUNT=$($ZIPINFO_CMD -1 "$INPUT" 2>/dev/null | wc -l | tr -d ' ')
        jq -n --arg tool "zipinfo" --arg count "$FILE_COUNT" \
            '{tool: $tool, data: {file_count: ($count | tonumber), format: $EXT}}'
        exit 0
    fi
    fallback_metadata "$INPUT"
fi

# ----------------------------------------------------------------------------
# BRANCH: Archives (zip, rar, 7z, tar, gz)
# ----------------------------------------------------------------------------
if [[ "$EXT" =~ ^(zip|rar|7z|tar|gz|bz2|xz)$ ]]; then
    if [[ "$EXT" == "zip" ]] && command -v "$ZIPINFO_CMD" &>/dev/null; then
        FILE_COUNT=$($ZIPINFO_CMD -1 "$INPUT" 2>/dev/null | wc -l | tr -d ' ')
        jq -n --arg tool "zipinfo" --arg count "$FILE_COUNT" \
            '{tool: $tool, data: {file_count: ($count | tonumber), format: "zip"}}'
        exit 0
    elif [[ "$EXT" == "rar" ]] && command -v "$UNRAR_CMD" &>/dev/null; then
        FILE_COUNT=$($UNRAR_CMD l "$INPUT" 2>/dev/null | tail -1 | awk '{print $2}' || echo "0")
        jq -n --arg tool "unrar" --arg count "$FILE_COUNT" \
            '{tool: $tool, data: {file_count: ($count | tonumber), format: "rar"}}'
        exit 0
    elif [[ "$EXT" == "7z" ]] && command -v "$SEVENZ_CMD" &>/dev/null; then
        FILE_COUNT=$($SEVENZ_CMD l "$INPUT" 2>/dev/null | tail -2 | head -1 | awk '{print $3}' || echo "0")
        jq -n --arg tool "7z" --arg count "$FILE_COUNT" \
            '{tool: $tool, data: {file_count: ($count | tonumber), format: "7z"}}'
        exit 0
    fi
    fallback_metadata "$INPUT"
fi

# ----------------------------------------------------------------------------
# BRANCH: 3D Models (obj, stl, ply, gltf, glb)
# ----------------------------------------------------------------------------
if [[ "$EXT" =~ ^(obj|stl|ply|gltf|glb|dae|fbx)$ ]]; then
    if [[ "$EXT" == "obj" ]] || [[ "$EXT" == "ply" ]]; then
        # Count vertices and faces for ASCII formats
        VERTICES=$(grep -c "^v " "$INPUT" 2>/dev/null || echo "0")
        FACES=$(grep -c "^f " "$INPUT" 2>/dev/null || echo "0")
        jq -n --arg tool "3d_parser" --arg vertices "$VERTICES" --arg faces "$FACES" \
            '{tool: $tool, data: {vertices: ($vertices | tonumber), faces: ($faces | tonumber), format: $EXT}}'
        exit 0
    elif [[ "$EXT" == "stl" ]]; then
        # ASCII vs Binary STL detection
        if head -c 5 "$INPUT" 2>/dev/null | grep -q "solid"; then
            FORMAT="ascii"
        else
            FORMAT="binary"
        fi
        jq -n --arg tool "3d_parser" --arg format "$FORMAT" \
            '{tool: $tool, data: {format: "stl", type: $format}}'
        exit 0
    fi
    fallback_metadata "$INPUT"
fi

# ----------------------------------------------------------------------------
# BRANCH: Retro / Obscure (ANS, BBS, DMD, etc.) - just file info
# ----------------------------------------------------------------------------
if [[ "$EXT" =~ ^(ans|asc|vga|bbs|dmd|dme|dmp|mod|s3m|xex|nes|smc|gba)$ ]]; then
    # Try to detect ANSI escape sequences for ANS files
    if [[ "$EXT" =~ ^(ans|asc|vga)$ ]]; then
        if head -c 1000 "$INPUT" 2>/dev/null | grep -qE '\x1B\[[0-9;]*m'; then
            jq -n --arg tool "retro_detector" \
                '{tool: $tool, data: {format: "ansi_art", detected: true, note: "Contains ANSI escape sequences"}}'
            exit 0
        fi
    fi
    # Generic retro file info
    FILE_INFO=$($FILE_CMD -b "$INPUT" 2>/dev/null || echo "Retro file")
    jq -n --arg tool "retro" --arg info "$FILE_INFO" \
        '{tool: $tool, data: {format: $EXT, file_info: $info}}'
    exit 0
fi

# ----------------------------------------------------------------------------
# BRANCH: Fallback for everything else
# ----------------------------------------------------------------------------
fallback_metadata "$INPUT"
