#!/bin/bash
# device_detector.sh - Detect device type from file path using config/devices.json
# Usage: ./device_detector.sh detect <path>

set -euo pipefail

# ----------------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${CONFIG_FILE:-$SCRIPT_DIR/../config/devices.json}"

# Fallback if config file is missing (hardcoded defaults)
fallback_detect() {
    local path="$1"
    if [[ "$path" =~ ^/Volumes/[A-Z0-9_]+$ ]]; then
        echo '{"device_type":"dvd","icon":"💿","description":"DVD Video Disc"}'
    elif [[ "$path" =~ ^/Volumes/BD-[A-Z0-9]+$ ]]; then
        echo '{"device_type":"bluray","icon":"💿","description":"Blu-ray Disc"}'
    elif [[ "$path" =~ ^/mnt/.*$ ]]; then
        # check if it's a NAS mount (simplified)
        if mount | grep -q "$path.*nfs\|smb\|cifs"; then
            echo '{"device_type":"nas","icon":"🖥️","description":"Network Attached Storage"}'
        else
            echo '{"device_type":"wsl_mount","icon":"🐧","description":"WSL Mount"}'
        fi
    elif [[ "$path" =~ ^/Volumes/.*$ ]]; then
        echo '{"device_type":"external_usb","icon":"💾","description":"External USB Drive"}'
    elif [[ "$path" =~ /Library/Mobile\ Documents/com~apple~CloudDocs/.*$ ]]; then
        echo '{"device_type":"icloud","icon":"☁️","description":"iCloud Drive"}'
    else
        echo '{"device_type":"unknown","icon":"❓","description":"Unknown Device"}'
    fi
}

# ----------------------------------------------------------------------------
# DETECT DEVICE FROM JSON CONFIG
# ----------------------------------------------------------------------------
detect_device() {
    local path="$1"
    local os_type="$(uname -s)"

    # If config file doesn't exist, fallback to hardcoded logic
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "⚠️ Config file not found: $CONFIG_FILE" >&2
        fallback_detect "$path"
        return 0
    fi

    # Check if jq is installed (needed for JSON parsing)
    if ! command -v jq &>/dev/null; then
        echo "⚠️ jq not found. Falling back to hardcoded detection." >&2
        fallback_detect "$path"
        return 0
    fi

    # Iterate over each device type in the config
    local device_types=$(jq -r '.device_types | keys[]' "$CONFIG_FILE" 2>/dev/null)
    if [ -z "$device_types" ]; then
        echo "❌ Invalid or empty config file. Falling back." >&2
        fallback_detect "$path"
        return 0
    fi

    for dtype in $device_types; do
        # Extract detection rules
        local path_pattern=$(jq -r ".device_types.\"$dtype\".detection.path_pattern // \"\"" "$CONFIG_FILE")
        local mount_type=$(jq -r ".device_types.\"$dtype\".detection.mount_type // \"\"" "$CONFIG_FILE")

        # Check path pattern
        if [[ -n "$path_pattern" ]] && [[ ! "$path" =~ $path_pattern ]]; then
            continue
        fi

        # If mount_type is defined, check it
        if [[ -n "$mount_type" ]]; then
            # For mount_type, we need to check the mount point's filesystem type
            # Get mount point for this path
            local mount_point=""
            if [[ "$os_type" == "Darwin" ]]; then
                mount_point=$(df -P "$path" 2>/dev/null | tail -1 | awk '{print $9}')
            else
                mount_point=$(df -P "$path" 2>/dev/null | tail -1 | awk '{print $6}')
            fi
            if [ -z "$mount_point" ]; then
                continue
            fi
            # Get filesystem type
            local fs_type=""
            if [[ "$os_type" == "Darwin" ]]; then
                fs_type=$(diskutil info "$mount_point" 2>/dev/null | grep "File System Personality:" | awk -F': ' '{print $2}' || echo "")
            else
                fs_type=$(df -T "$mount_point" 2>/dev/null | tail -1 | awk '{print $2}' || echo "")
            fi
            # Check if fs_type matches mount_type regex
            if [[ -n "$fs_type" ]] && [[ ! "$fs_type" =~ $mount_type ]]; then
                continue
            fi
        fi

        # All checks passed – return this device type
        local description=$(jq -r ".device_types.\"$dtype\".description // \"$dtype\"" "$CONFIG_FILE")
        local icon=$(jq -r ".device_types.\"$dtype\".icon // \"❓\"" "$CONFIG_FILE")
        echo "{\"device_type\":\"$dtype\",\"icon\":\"$icon\",\"description\":\"$description\"}"
        return 0
    done

    # No match found
    echo '{"device_type":"unknown","icon":"❓","description":"Unknown Device"}'
}

# ----------------------------------------------------------------------------
# COMMAND DISPATCHER
# ----------------------------------------------------------------------------
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command="${1:-detect}"
    shift || true

    case "$command" in
        detect)
            path="${1:-.}"
            detect_device "$path"
            ;;
        *)
            echo "Usage: $0 detect <path>" >&2
            exit 1
            ;;
    esac
fi
