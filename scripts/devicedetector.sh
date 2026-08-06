#!/bin/bash
# device_detector.sh - Detect device/volume information for a given file path
# Outputs JSON with device details, volume info, and classification.

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
# Path to a JSON file with device metadata mappings (optional)
DEVICES_JSON="${DEVICES_JSON:-./devices.json}"

# ============================================================================
# FUNCTIONS
# ============================================================================

# Detect mount point for a path (macOS/Linux/WSL)
get_mount_info() {
    local path="$1"
    local mount_point=""
    local device=""
    local fs_type=""
    local mount_opts=""

    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS: use df and diskutil
        mount_point=$(df -P "$path" 2>/dev/null | tail -1 | awk '{print $9}')
        device=$(df -P "$path" 2>/dev/null | tail -1 | awk '{print $1}')
        if [[ -n "$mount_point" ]]; then
            fs_type=$(diskutil info "$mount_point" 2>/dev/null | grep "File System Personality:" | awk -F': ' '{print $2}' || echo "")
            # Also try to get volume name and UUID
            local vol_name=$(diskutil info "$mount_point" 2>/dev/null | grep "Volume Name:" | awk -F': ' '{print $2}' || echo "")
            local vol_uuid=$(diskutil info "$mount_point" 2>/dev/null | grep "Volume UUID:" | awk -F': ' '{print $2}' || echo "")
            echo "mount_point=$mount_point|device=$device|fs_type=$fs_type|vol_name=$vol_name|vol_uuid=$vol_uuid"
        fi
    else
        # Linux / WSL: use df and findmnt
        mount_point=$(df -P "$path" 2>/dev/null | tail -1 | awk '{print $6}')
        device=$(df -P "$path" 2>/dev/null | tail -1 | awk '{print $1}')
        if [[ -n "$mount_point" ]]; then
            fs_type=$(df -T "$path" 2>/dev/null | tail -1 | awk '{print $2}')
            # Try to get volume name from /dev/disk/by-label
            local vol_name=""
            if [[ -n "$device" ]] && [[ -e "/dev/disk/by-label" ]]; then
                vol_name=$(find -L /dev/disk/by-label -samefile "$device" 2>/dev/null | head -1 | xargs basename 2>/dev/null || echo "")
            fi
            # Try to get UUID
            local vol_uuid=""
            if command -v blkid &>/dev/null && [[ -n "$device" ]]; then
                vol_uuid=$(blkid -s UUID -o value "$device" 2>/dev/null || echo "")
            fi
            echo "mount_point=$mount_point|device=$device|fs_type=$fs_type|vol_name=$vol_name|vol_uuid=$vol_uuid"
        fi
    fi
}

# Classify device type based on mount info and path
classify_device() {
    local mount_point="$1"
    local device="$2"
    local fs_type="$3"
    local vol_name="$4"
    local path="$5"

    # Check for optical discs (DVD, Blu-ray, CD)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # On macOS, optical discs usually mount under /Volumes with specific names
        if [[ "$mount_point" =~ ^/Volumes/[A-Z0-9_]+$ ]]; then
            # Check for DVD/Blu-ray structures
            if [ -d "$mount_point/VIDEO_TS" ] || [ -d "$mount_point/AUDIO_TS" ]; then
                echo "dvd"
                return 0
            elif [ -d "$mount_point/BDMV" ] || [ -d "$mount_point/CERTIFICATE" ]; then
                echo "bluray"
                return 0
            elif [ -f "$mount_point/README.TXT" ] || [ -f "$mount_point/README" ]; then
                # Could be a CD-ROM with autorun
                echo "cd_rom"
                return 0
            fi
        fi
    else
        # Linux optical discs usually mounted under /media or /run/media
        if [[ "$mount_point" =~ ^/media/.* ]] || [[ "$mount_point" =~ ^/run/media/.* ]]; then
            # Check for DVD/Blu-ray structures
            if [ -d "$mount_point/VIDEO_TS" ] || [ -d "$mount_point/AUDIO_TS" ]; then
                echo "dvd"
                return 0
            elif [ -d "$mount_point/BDMV" ] || [ -d "$mount_point/CERTIFICATE" ]; then
                echo "bluray"
                return 0
            fi
        fi
    fi

    # Check for cloud storage mounts (iCloud, OneDrive, Dropbox)
    if [[ "$path" == *"/Library/Mobile Documents/com~apple~CloudDocs"* ]] || [[ "$vol_name" == "iCloud Drive" ]]; then
        echo "icloud"
        return 0
    elif [[ "$path" == *"/OneDrive"* ]] || [[ "$vol_name" == "OneDrive" ]]; then
        echo "onedrive"
        return 0
    elif [[ "$path" == *"/Dropbox"* ]] || [[ "$vol_name" == "Dropbox" ]]; then
        echo "dropbox"
        return 0
    fi

    # Check for NAS mounts (NFS, SMB/CIFS)
    if [[ "$fs_type" == "nfs" ]] || [[ "$fs_type" == "cifs" ]] || [[ "$fs_type" == "smb" ]]; then
        echo "nas"
        return 0
    fi

    # Check for external USB drives (on macOS, check if not internal)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ "$device" =~ ^/dev/disk[0-9]+s[0-9]+$ ]] && [[ "$mount_point" == "/Volumes/"* ]]; then
            # Check if internal
            local internal=$(diskutil info "$mount_point" 2>/dev/null | grep "Internal" | grep -i "Yes" || echo "")
            if [[ -z "$internal" ]]; then
                echo "external_usb"
                return 0
            fi
        fi
    else
        # Linux: check if device is removable (via lsblk)
        if command -v lsblk &>/dev/null && [[ -n "$device" ]]; then
            local removable=$(lsblk -o NAME,MOUNTPOINT,RM -l | grep "$mount_point" | awk '{print $3}')
            if [[ "$removable" == "1" ]]; then
                echo "external_usb"
                return 0
            fi
        fi
    fi

    # Check for WSL mounts (mounted under /mnt/)
    if [[ "$mount_point" =~ ^/mnt/[a-z]/$ ]]; then
        echo "wsl_mount"
        return 0
    fi

    # Check for system volumes
    if [[ "$mount_point" == "/System/Volumes/"* ]] || [[ "$vol_name" == "Macintosh HD" ]] || [[ "$mount_point" == "/" ]]; then
        echo "system_volume"
        return 0
    fi

    # Fallback
    echo "unknown"
}

# Get device metadata (from devices.json if present)
get_device_metadata() {
    local device_type="$1"
    if [[ -f "$DEVICES_JSON" ]]; then
        jq -r ".devices[] | select(.type == \"$device_type\")" "$DEVICES_JSON" 2>/dev/null || echo "{}"
    else
        echo "{}"
    fi
}

# ============================================================================
# MAIN DETECTION FUNCTION (called by trawl.sh)
# ============================================================================
detect_device() {
    local file_path="$1"
    # Resolve to absolute path
    file_path=$(realpath "$file_path" 2>/dev/null || echo "$file_path")

    # Get mount info
    local mount_info=$(get_mount_info "$file_path")
    if [[ -z "$mount_info" ]]; then
        # Fallback: use df -P directly
        mount_info=$(df -P "$file_path" 2>/dev/null | tail -1 | awk '{print "mount_point="$6"|device="$1"|fs_type=unknown|vol_name=|vol_uuid="}')
    fi

    # Parse mount_info
    local mount_point=""
    local device=""
    local fs_type=""
    local vol_name=""
    local vol_uuid=""
    IFS='|' read -r -a parts <<< "$mount_info"
    for part in "${parts[@]}"; do
        case "$part" in
            mount_point=*) mount_point="${part#mount_point=}" ;;
            device=*) device="${part#device=}" ;;
            fs_type=*) fs_type="${part#fs_type=}" ;;
            vol_name=*) vol_name="${part#vol_name=}" ;;
            vol_uuid=*) vol_uuid="${part#vol_uuid=}" ;;
        esac
    done

    # If vol_name is empty, try to get from mount point basename
    if [[ -z "$vol_name" ]] && [[ -n "$mount_point" ]]; then
        vol_name=$(basename "$mount_point")
    fi

    # Classify
    local device_type=$(classify_device "$mount_point" "$device" "$fs_type" "$vol_name" "$file_path")

    # Try to get serial (placeholder)
    local serial=""
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if [[ -n "$device" ]]; then
            serial=$(diskutil info "$device" 2>/dev/null | grep "Serial Number:" | awk -F': ' '{print $2}' || echo "")
        fi
    else
        # Linux: try udevadm
        if command -v udevadm &>/dev/null && [[ -n "$device" ]]; then
            serial=$(udevadm info --query=property --name="$device" 2>/dev/null | grep ID_SERIAL_SHORT | cut -d= -f2 || echo "")
        fi
    fi

    # Get device metadata (placeholder)
    local device_metadata=$(get_device_metadata "$device_type")

    # Build JSON output
    cat <<EOF
{
  "device": "$device",
  "mount_point": "$mount_point",
  "volume_name": "$vol_name",
  "volume_uuid": "$vol_uuid",
  "filesystem": "$fs_type",
  "device_type": "$device_type",
  "serial": "$serial",
  "metadata": $device_metadata
}
EOF
}

# ============================================================================
# DIRECT EXECUTION (Standalone Mode)
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    path="${1:-.}"
    detect_device "$path"
fi
