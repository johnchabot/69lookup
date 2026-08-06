#!/bin/bash
# media_tools.sh - Media processing: thumbnails, scenes, transcripts, metadata
# Used by trawl.sh to enrich files with derived assets.

set -euo pipefail

# ============================================================================
# CONFIGURATION (Override via environment)
# ============================================================================
FFMPEG="${FFMPEG:-ffmpeg}"
FFPROBE="${FFPROBE:-ffprobe}"
EXIFTOOL="${EXIFTOOL:-exiftool}"
WHISPER_MODEL="${WHISPER_MODEL:-small}"    # small, base, tiny
WHISPER_COMMAND="${WHISPER_COMMAND:-whisper}"  # or whisper.cpp, etc.
VOSK_COMMAND="${VOSK_COMMAND:-vosk-transcribe}"

# Directories for caches
CACHE_DIR="${CACHE_DIR:-./media_cache}"
THUMBNAIL_DIR="$CACHE_DIR/thumbnails"
SCENE_DIR="$CACHE_DIR/scenes"
TRANSCRIPT_DIR="$CACHE_DIR/transcripts"
METADATA_DIR="$CACHE_DIR/metadata"

mkdir -p "$THUMBNAIL_DIR" "$SCENE_DIR" "$TRANSCRIPT_DIR" "$METADATA_DIR"

# Logging (optional)
LOG_FILE="${LOG_FILE:-/dev/null}"
log() { echo "$*" | tee -a "$LOG_FILE" >&2; }

# ============================================================================
# DEPENDENCY CHECKS
# ============================================================================
check_ffmpeg() {
    if ! command -v "$FFMPEG" &>/dev/null; then
        log "⚠️ ffmpeg not found. Install with: brew install ffmpeg (macOS) or apt install ffmpeg (Linux)"
        return 1
    fi
    return 0
}

check_ffprobe() {
    if ! command -v "$FFPROBE" &>/dev/null; then
        log "⚠️ ffprobe not found. Install with: brew install ffmpeg (macOS) or apt install ffmpeg (Linux)"
        return 1
    fi
    return 0
}

check_exiftool() {
    if ! command -v "$EXIFTOOL" &>/dev/null; then
        log "⚠️ exiftool not found. Install with: brew install exiftool (macOS) or apt install exiftool (Linux)"
        return 1
    fi
    return 0
}

# ============================================================================
# 1. THUMBNAIL GENERATION
# ============================================================================
generate_thumbnail() {
    local input="$1"
    local output="$2"
    local size="${3:-320x240}"

    mkdir -p "$(dirname "$output")"

    if [ -f "$output" ] && [ -s "$output" ]; then
        log "⏭️ Thumbnail already exists: $output"
        return 0
    fi

    if ! check_ffmpeg; then
        log "❌ Cannot generate thumbnail without ffmpeg"
        return 1
    fi

    # For video: grab frame at 10 seconds
    local mime_type=$(file -b --mime-type "$input" 2>/dev/null || echo "")
    if [[ "$mime_type" == video/* ]]; then
        $FFMPEG -i "$input" -ss 00:00:10 -vframes 1 \
            -vf "scale=$size:force_original_aspect_ratio=decrease,pad=$size:($size-iw)/2:($size-ih)/2" \
            "$output" -y 2>/dev/null
    else
        # For images: resize
        $FFMPEG -i "$input" -vf "scale=$size:force_original_aspect_ratio=decrease,pad=$size:($size-iw)/2:($size-ih)/2" \
            "$output" -y 2>/dev/null
    fi

    if [ -f "$output" ] && [ -s "$output" ]; then
        log "✅ Thumbnail created: $output"
        return 0
    else
        log "❌ Failed to create thumbnail for $input"
        return 1
    fi
}

# ============================================================================
# 2. SCENE CHANGE DETECTION (Video keyframes)
# ============================================================================
detect_scenes() {
    local input="$1"
    local output_dir="$2"
    local max_scenes="${3:-50}"
    local threshold="${4:-0.3}"

    mkdir -p "$output_dir"

    if ! check_ffmpeg || ! check_ffprobe; then
        log "❌ Scene detection requires ffmpeg/ffprobe"
        return 1
    fi

    # Get video duration
    local duration=$($FFPROBE -v quiet -show_format -print_format json "$input" | jq -r '.format.duration // 0')
    duration=${duration%.*}
    if [ "$duration" -eq 0 ]; then
        log "❌ Could not determine video duration"
        return 1
    fi

    log "🎬 Scene detection: duration=${duration}s, max_scenes=$max_scenes"

    # Sample frames at intervals
    local interval=$((duration / max_scenes))
    [ $interval -lt 5 ] && interval=5

    local count=0
    local timestamps_file="$output_dir/timestamps.txt"
    > "$timestamps_file"

    for ((i=0; i<duration; i+=interval)); do
        echo "$i" >> "$timestamps_file"
    done

    # Extract frames
    local frame_count=0
    while read -r timestamp; do
        [ -z "$timestamp" ] && continue
        frame_count=$((frame_count + 1))
        local outfile="$output_dir/scene_$(printf "%03d" $frame_count).jpg"
        $FFMPEG -i "$input" -ss "$timestamp" -vframes 1 -vf "scale=640:-1" "$outfile" -y 2>/dev/null
        if [ -f "$outfile" ] && [ -s "$outfile" ]; then
            log "  ✅ Scene $frame_count at ${timestamp}s"
        else
            rm -f "$outfile"
        fi
    done < "$timestamps_file"

    # Generate index.json
    cat > "$output_dir/index.json" <<EOF
{
  "source": "$input",
  "duration": $duration,
  "total_scenes": $frame_count,
  "interval": $interval,
  "scenes": [
EOF

    local first=true
    for ((i=1; i<=frame_count; i++)); do
        local f="scene_$(printf "%03d" $i).jpg"
        if [ -f "$output_dir/$f" ]; then
            if [ "$first" = true ]; then
                first=false
            else
                echo "," >> "$output_dir/index.json"
            fi
            local ts=$((i * interval))
            echo "    {\"scene\": $i, \"timestamp\": $ts, \"file\": \"$f\"}" >> "$output_dir/index.json"
        fi
    done
    echo "  ]" >> "$output_dir/index.json"
    echo "}" >> "$output_dir/index.json"

    log "✅ Scene detection complete: $frame_count scenes"
    echo "$frame_count"
}

# ============================================================================
# 3. TRANSCRIPT EXTRACTION (Speech-to-text)
# ============================================================================
extract_transcript() {
    local input="$1"
    local output_prefix="$2"
    local tool="${3:-whisper}"

    mkdir -p "$(dirname "$output_prefix")"

    log "🎤 Extracting transcript using $tool..."

    case "$tool" in
        whisper)
            if ! command -v "$WHISPER_COMMAND" &>/dev/null; then
                log "❌ whisper not found. Install: pip install openai-whisper"
                return 1
            fi
            $WHISPER_COMMAND "$input" --model "$WHISPER_MODEL" \
                --output_format srt,vtt \
                --output_dir "$(dirname "$output_prefix")" 2>/dev/null
            # Rename files
            local base=$(basename "$input" | sed 's/\.[^.]*$//')
            local dir="$(dirname "$output_prefix")"
            [ -f "$dir/$base.srt" ] && mv "$dir/$base.srt" "${output_prefix}.srt"
            [ -f "$dir/$base.vtt" ] && mv "$dir/$base.vtt" "${output_prefix}.vtt"
            ;;
        whisper_cpp)
            if ! command -v whisper &>/dev/null; then
                log "❌ whisper.cpp not found"
                return 1
            fi
            whisper -m "${WHISPER_MODEL:-models/ggml-small.bin}" -f "$input" \
                -osrt -ovtt -of "$output_prefix" 2>/dev/null
            ;;
        vosk)
            if ! command -v "$VOSK_COMMAND" &>/dev/null; then
                log "❌ vosk-transcribe not found"
                return 1
            fi
            $VOSK_COMMAND -i "$input" -o "${output_prefix}.srt" --format srt 2>/dev/null
            if [ -f "${output_prefix}.srt" ]; then
                # Convert to VTT
                echo "WEBVTT" > "${output_prefix}.vtt"
                echo "" >> "${output_prefix}.vtt"
                sed 's/,/./g' "${output_prefix}.srt" >> "${output_prefix}.vtt"
            fi
            ;;
        *)
            log "❌ Unknown tool: $tool (supported: whisper, whisper_cpp, vosk)"
            return 1
            ;;
    esac

    if [ -f "${output_prefix}.srt" ] && [ -f "${output_prefix}.vtt" ]; then
        log "✅ Transcript extracted: ${output_prefix}.srt / .vtt"
        return 0
    else
        log "⚠️ Transcript extraction may have issues"
        return 1
    fi
}

# ============================================================================
# 4. METADATA EXTRACTION
# ============================================================================
video_metadata() {
    local input="$1"
    local output_json="${2:-}"
    if ! check_ffprobe; then
        log "❌ ffprobe required for video metadata"
        return 1
    fi

    local json=$($FFPROBE -v quiet -print_format json -show_format -show_streams "$input" 2>/dev/null)
    if [ -n "$output_json" ]; then
        echo "$json" > "$output_json"
    else
        echo "$json"
    fi
}

audio_metadata() {
    local input="$1"
    local output_json="${2:-}"
    if ! check_ffprobe; then
        log "❌ ffprobe required for audio metadata"
        return 1
    fi
    local json=$($FFPROBE -v quiet -print_format json -show_format -show_streams "$input" 2>/dev/null)
    if [ -n "$output_json" ]; then
        echo "$json" > "$output_json"
    else
        echo "$json"
    fi
}

image_metadata() {
    local input="$1"
    local output_json="${2:-}"
    if ! check_exiftool; then
        log "❌ exiftool required for image metadata"
        return 1
    fi
    local json=$($EXIFTOOL -j "$input" 2>/dev/null | jq -c '.[0]')
    if [ -n "$output_json" ]; then
        echo "$json" > "$output_json"
    else
        echo "$json"
    fi
}

# ============================================================================
# 5. CONVERSION (SRT to VTT)
# ============================================================================
srt_to_vtt() {
    local srt="$1"
    local vtt="$2"
    if [ ! -f "$srt" ]; then
        log "❌ SRT file not found: $srt"
        return 1
    fi
    {
        echo "WEBVTT"
        echo ""
        sed 's/,/./g' "$srt"
    } > "$vtt"
    log "✅ Converted $srt → $vtt"
}

# ============================================================================
# MAIN DISPATCHER
# ============================================================================
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    command="${1:-help}"
    shift || true

    case "$command" in
        thumbnail)
            generate_thumbnail "$@"
            ;;
        scenes)
            detect_scenes "$@"
            ;;
        transcript)
            extract_transcript "$@"
            ;;
        video_metadata)
            video_metadata "$@"
            ;;
        audio_metadata)
            audio_metadata "$@"
            ;;
        image_metadata)
            image_metadata "$@"
            ;;
        srt_to_vtt)
            srt_to_vtt "$@"
            ;;
        help|--help|-h)
            cat <<EOF
Media Tools

USAGE:
    media_tools.sh <command> <arguments>

COMMANDS:
    thumbnail <input> <output> [size]
        Generate thumbnail (size: WxH, default: 320x240)

    scenes <input> <output_dir> [max_scenes] [threshold]
        Detect scene changes and extract frames

    transcript <input> <output_prefix> [tool]
        Extract transcript (tools: whisper, whisper_cpp, vosk)

    video_metadata <input> [output_json]
        Extract video metadata (JSON)

    audio_metadata <input> [output_json]
        Extract audio metadata (JSON)

    image_metadata <input> [output_json]
        Extract image metadata (EXIF) (JSON)

    srt_to_vtt <srt_file> <vtt_file>
        Convert SRT to WebVTT

ENVIRONMENT:
    FFMPEG          Path to ffmpeg (default: ffmpeg)
    FFPROBE         Path to ffprobe (default: ffprobe)
    EXIFTOOL        Path to exiftool (default: exiftool)
    WHISPER_MODEL   Model for whisper (default: small)
    WHISPER_COMMAND Command for whisper (default: whisper)
    VOSK_COMMAND    Command for vosk-transcribe (default: vosk-transcribe)
    CACHE_DIR       Base cache directory (default: ./media_cache)
EOF
            ;;
        *)
            echo "❌ Unknown command: $command"
            echo "Use 'help' for usage"
            exit 1
            ;;
    esac
fi
