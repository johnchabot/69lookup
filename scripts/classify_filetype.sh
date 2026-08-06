#!/bin/bash
# classify_filetype.sh - Classify a file by extension using config/filetypes.json
# Usage: ./classify_filetype.sh <file_path>
# Output: JSON with file_type, icon, description

set -euo pipefail

# ----------------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/filetypes.json}"

# ----------------------------------------------------------------------------
# FALLBACK (hardcoded defaults if config or jq is missing)
# ----------------------------------------------------------------------------
fallback_classify() {
    local ext="$1"
    case "$ext" in
        mp4|mov|avi|mkv|webm|flv|wmv|m4v|mpg|mpeg)
            echo '{"file_type":"video","icon":"🎬","description":"Digital Video File"}'
            ;;
        jpg|jpeg|png|gif|bmp|tiff|tif|webp|heic|heif|raw|cr2|nef|arw)
            echo '{"file_type":"image","icon":"🖼️","description":"Raster Image"}'
            ;;
        obj|dcm|dicom|splat|ply|stl|fbx|gltf|glb|usd|usda|usdc)
            echo '{"file_type":"image_3d","icon":"🧊","description":"3D Model / Point Cloud"}'
            ;;
        svg|eps|ai|cdr|wmf)
            echo '{"file_type":"image_vector","icon":"📐","description":"Vector Graphic"}'
            ;;
        mp3|flac|fla|wav|aac|ogg|wma|m4a|opus|aiff|mod|s3m)
            echo '{"file_type":"audio","icon":"🎵","description":"Digital Audio File"}'
            ;;
        zip|rar|7z|gz|bz2|xz|tar|tgz|cab|arj)
            echo '{"file_type":"archive","icon":"📦","description":"Compressed Archive"}'
            ;;
        pdf|doc|docx|rtf|pages|txt|md|odt|ods|odp|xls|xlsx|ppt|pptx)
            echo '{"file_type":"document","icon":"📄","description":"Document / Text File"}'
            ;;
        xex|xbla|iso|nsp|xci|rom|nes|smc|gba|n64|ps2|wbfs)
            echo '{"file_type":"game","icon":"🎮","description":"Game ROM / Console Format"}'
            ;;
        html|htm|css|js|json|xml|yaml|yml)
            echo '{"file_type":"web","icon":"🌐","description":"Web / Code File"}'
            ;;
        dmd|dmp|bin|dll|so|dylib|exe)
            echo '{"file_type":"obscure","icon":"🔮","description":"Obscure / Binary File"}'
            ;;
        *)
            echo '{"file_type":"unknown","icon":"❓","description":"Unknown File Type"}'
            ;;
    esac
}

# ----------------------------------------------------------------------------
# CLASSIFY USING JSON CONFIG
# ----------------------------------------------------------------------------
classify_file() {
    local file="$1"
    local ext="${file##*.}"
    ext="${ext,,}"  # lowercase

    # If directory
    if [ -d "$file" ]; then
        echo '{"file_type":"directory","icon":"📁","description":"Directory / Folder"}'
        return 0
    fi

    # If config file doesn't exist, fallback
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚠️ Config file not found: $CONFIG_FILE" >&2
        fallback_classify "$ext"
        return 0
    fi

    # Check if jq is installed
    if ! command -v jq &>/dev/null; then
        echo "⚠️ jq not found. Falling back to hardcoded classification." >&2
        fallback_classify "$ext"
        return 0
    fi

    # Search for the extension in the config
    local result=$(jq -r --arg ext "$ext" '
        .filetypes | to_entries[] | 
        select(.value.extensions | index($ext)) | 
        {
            file_type: .key,
            icon: .value.icon,
            description: .value.description
        }
    ' "$CONFIG_FILE" 2>/dev/null | jq -c '.')

    if [ -n "$result" ] && [ "$result" != "null" ]; then
        echo "$result"
    else
        echo '{"file_type":"unknown","icon":"❓","description":"Unknown File Type"}'
    fi
}

# ----------------------------------------------------------------------------
# COMMAND DISPATCHER
# ----------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    file_path="${1:-.}"
    classify_file "$file_path"
fi
