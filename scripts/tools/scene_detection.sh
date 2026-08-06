#!/bin/bash
# scene_detection.sh - Extract scene change frames from a video file.
# Usage: ./scene_detection.sh <video_file> [threshold] [max_scenes]
#
# Output: media_cache/<md5>/HHMMSS.jpg  (one per detected scene)
#         plus an index.json file.

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
MEDIA_CACHE_DIR="${MEDIA_CACHE_DIR:-./media_cache}"
FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"
THRESHOLD="${2:-0.3}"
MAX_SCENES="${3:-50}"

# ----------------------------------------------------------------------------
# Helper: Compute MD5 (macOS/Linux)
# ----------------------------------------------------------------------------
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

# ----------------------------------------------------------------------------
# Helper: Check dependencies
# ----------------------------------------------------------------------------
check_deps() {
    if ! command -v "$FFMPEG" &>/dev/null; then
        echo "❌ ffmpeg not found. Please install ffmpeg." >&2
        exit 1
    fi
    if ! command -v "$FFPROBE" &>/dev/null; then
        echo "❌ ffprobe not found. Please install ffmpeg." >&2
        exit 1
    fi
}

# ============================================================================
# MAIN SCRIPT
# ============================================================================
if [ $# -lt 1 ]; then
    echo "Usage: $0 <video_file> [threshold] [max_scenes]"
    echo "  threshold  : scene change sensitivity (0.1-0.9, default 0.3)"
    echo "  max_scenes : maximum number of scenes to extract (default 50)"
    exit 1
fi

INPUT="$1"
THRESHOLD="${2:-0.3}"
MAX_SCENES="${3:-50}"

# Check dependencies
check_deps

# Validate input file
if [ ! -f "$INPUT" ]; then
    echo "❌ Input file not found: $INPUT" >&2
    exit 1
fi

# Compute MD5
MD5=$(get_md5 "$INPUT")
if [ -z "$MD5" ]; then
    echo "❌ Failed to compute MD5 for $INPUT" >&2
    exit 1
fi

# Set up output directory
OUTPUT_DIR="$MEDIA_CACHE_DIR/$MD5"
mkdir -p "$OUTPUT_DIR"

echo "🔍 Scene detection for: $(basename "$INPUT")"
echo "  MD5: $MD5"
echo "  Threshold: $THRESHOLD"
echo "  Max scenes: $MAX_SCENES"
echo "  Output dir: $OUTPUT_DIR"

# ----------------------------------------------------------------------------
# Step 1: Get video duration (to sample reasonably)
# ----------------------------------------------------------------------------
DURATION=$($FFPROBE -v quiet -show_format -print_format json "$INPUT" | jq -r '.format.duration // 0')
DURATION=${DURATION%.*}
if [ "$DURATION" -eq 0 ]; then
    echo "⚠️ Could not determine duration, defaulting to 60s" >&2
    DURATION=60
fi

echo "  Duration: ${DURATION}s"

# ----------------------------------------------------------------------------
# Step 2: Detect scene change timestamps using ffmpeg
# ----------------------------------------------------------------------------
TEMP_TIMESTAMPS=$(mktemp)
trap 'rm -f "$TEMP_TIMESTAMPS"' EXIT

# Run ffmpeg scene detection, writing metadata to a temp file
$FFMPEG -i "$INPUT" \
    -vf "select='gt(scene,$THRESHOLD)',metadata=print:file=$TEMP_TIMESTAMPS" \
    -vsync vfr -f null - 2>/dev/null || true

# Parse timestamps from the metadata file
# Format: pts_time: 12.345
TIMESTAMPS=()
while IFS= read -r line; do
    if [[ "$line" =~ pts_time:[[:space:]]*([0-9.]+) ]]; then
        ts="${BASH_REMATCH[1]}"
        TIMESTAMPS+=("$ts")
    fi
done < "$TEMP_TIMESTAMPS"

# If no scenes detected, fallback to time-based sampling
if [ ${#TIMESTAMPS[@]} -eq 0 ]; then
    echo "⚠️ No scene changes detected. Using time-based sampling."
    INTERVAL=$((DURATION / MAX_SCENES))
    [ $INTERVAL -lt 5 ] && INTERVAL=5
    for ((i=0; i<MAX_SCENES; i++)); do
        ts=$((i * INTERVAL))
        TIMESTAMPS+=("$ts")
    done
fi

# Limit to MAX_SCENES
if [ ${#TIMESTAMPS[@]} -gt "$MAX_SCENES" ]; then
    TIMESTAMPS=("${TIMESTAMPS[@]:0:$MAX_SCENES}")
fi

echo "  Found ${#TIMESTAMPS[@]} scenes"

# ----------------------------------------------------------------------------
# Step 3: Extract frames at each timestamp
# ----------------------------------------------------------------------------
SCENE_INDEX=()
COUNT=0

for ts in "${TIMESTAMPS[@]}"; do
    # Format timestamp as HHMMSS (rounded to nearest second)
    SECONDS=$(printf "%.0f" "$ts")
    HOURS=$((SECONDS / 3600))
    MINUTES=$(( (SECONDS % 3600) / 60 ))
    SECS=$((SECONDS % 60))
    TIMESTAMP_STR=$(printf "%02d%02d%02d" "$HOURS" "$MINUTES" "$SECS")

    OUTPUT_FILE="$OUTPUT_DIR/$TIMESTAMP_STR.jpg"

    # Skip if file already exists
    if [ -f "$OUTPUT_FILE" ]; then
        echo "  ⏭️ Scene at ${TIMESTAMP_STR}s already exists"
        continue
    fi

    # Extract frame
    $FFMPEG -i "$INPUT" -ss "$ts" -vframes 1 -vf "scale=640:-1" "$OUTPUT_FILE" -y 2>/dev/null

    if [ -f "$OUTPUT_FILE" ] && [ -s "$OUTPUT_FILE" ]; then
        COUNT=$((COUNT + 1))
        echo "  ✅ Scene $COUNT at ${TIMESTAMP_STR}s (${ts}s)"
        SCENE_INDEX+=("{\"scene\":$COUNT,\"timestamp\":$ts,\"file\":\"$TIMESTAMP_STR.jpg\"}")
    else
        echo "  ❌ Failed to extract frame at ${ts}s" >&2
    fi
done

# ----------------------------------------------------------------------------
# Step 4: Write index.json
# ----------------------------------------------------------------------------
INDEX_FILE="$OUTPUT_DIR/index.json"
{
    echo "{"
    echo "  \"source\": \"$INPUT\","
    echo "  \"md5\": \"$MD5\","
    echo "  \"duration\": $DURATION,"
    echo "  \"threshold\": $THRESHOLD,"
    echo "  \"total_scenes\": $COUNT,"
    echo "  \"scenes\": ["
    if [ $COUNT -gt 0 ]; then
        for i in "${!SCENE_INDEX[@]}"; do
            echo -n "    ${SCENE_INDEX[$i]}"
            if [ $i -lt $((COUNT - 1)) ]; then
                echo ","
            fi
        done
        echo ""
    fi
    echo "  ]"
    echo "}"
} > "$INDEX_FILE"

echo "✅ Scene detection complete: $COUNT scenes saved to $OUTPUT_DIR"
echo "📄 Index: $INDEX_FILE"
