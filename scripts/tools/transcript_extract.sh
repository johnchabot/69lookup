#!/bin/bash
# transcript_extract.sh - Extract transcripts from audio/video files.
# Usage: ./transcript_extract.sh <input_file> [output_base] [tool] [model_or_options]
#
# Output: output_base.srt and output_base.vtt
# Default output_base: media_cache/<md5>/<md5>

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================
MEDIA_CACHE_DIR="${MEDIA_CACHE_DIR:-./media_cache}"
WHISPER_MODEL="${WHISPER_MODEL:-small}"
WHISPER_COMMAND="${WHISPER_COMMAND:-whisper}"
WHISPER_CPP_MODEL="${WHISPER_CPP_MODEL:-models/ggml-small.bin}"
VOSK_COMMAND="${VOSK_COMMAND:-vosk-transcribe}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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
# Helper: Logging
# ----------------------------------------------------------------------------
log_info()    { echo -e "${BLUE}ℹ${NC} $*"; }
log_warn()    { echo -e "${YELLOW}⚠${NC} $*"; }
log_error()   { echo -e "${RED}✗${NC} $*"; }
log_success() { echo -e "${GREEN}✓${NC} $*"; }

# ============================================================================
# MAIN SCRIPT
# ============================================================================
if [ $# -lt 1 ]; then
    cat <<EOF
Usage: $0 <input_file> [output_base] [tool] [model_or_options]

Arguments:
  input_file          Path to audio or video file.
  output_base         Output base path (without extension). Default: media_cache/<md5>/<md5>
  tool                Transcription tool to use: whisper, whisper_cpp, vosk. Default: auto-detect.
  model_or_options    Model name (whisper) or model path (whisper_cpp). Default: small / models/ggml-small.bin

Tools:
  whisper      OpenAI Whisper (pip install openai-whisper)
  whisper_cpp  Whisper.cpp (faster, CPU)
  vosk         Vosk offline (pip install vosk-transcribe)

Examples:
  # Auto-detect best tool
  $0 ~/Videos/movie.mp4

  # Use OpenAI Whisper with medium model
  $0 ~/Videos/movie.mp4 ./output/transcript whisper medium

  # Use Whisper.cpp with custom model
  $0 ~/Videos/movie.mp4 ./output/transcript whisper_cpp models/ggml-base.bin

  # Use Vosk
  $0 ~/Videos/movie.mp4 ./output/transcript vosk

Environment:
  WHISPER_MODEL         Default model for whisper (default: small)
  WHISPER_COMMAND       Command for whisper (default: whisper)
  WHISPER_CPP_MODEL     Default model path for whisper_cpp (default: models/ggml-small.bin)
  VOSK_COMMAND          Command for vosk (default: vosk-transcribe)
  MEDIA_CACHE_DIR       Base cache dir (default: ./media_cache)

EOF
    exit 1
fi

INPUT="$1"
OUTPUT_BASE="${2:-}"
TOOL="${3:-auto}"
MODEL_OR_OPTS="${4:-}"

# ----------------------------------------------------------------------------
# Step 1: Validate input
# ----------------------------------------------------------------------------
if [ ! -f "$INPUT" ]; then
    log_error "Input file not found: $INPUT"
    exit 1
fi

# ----------------------------------------------------------------------------
# Step 2: Determine output base path
# ----------------------------------------------------------------------------
if [ -z "$OUTPUT_BASE" ]; then
    MD5=$(get_md5 "$INPUT")
    if [ -z "$MD5" ]; then
        log_error "Failed to compute MD5 for $INPUT"
        exit 1
    fi
    OUTPUT_BASE="$MEDIA_CACHE_DIR/transcripts/$MD5/$MD5"
fi

# Create output directory
OUTPUT_DIR=$(dirname "$OUTPUT_BASE")
mkdir -p "$OUTPUT_DIR"

log_info "Input file: $INPUT"
log_info "Output base: $OUTPUT_BASE"

# ----------------------------------------------------------------------------
# Step 3: Auto-detect tool (if not specified)
# ----------------------------------------------------------------------------
if [ "$TOOL" = "auto" ]; then
    if command -v "$WHISPER_COMMAND" &>/dev/null; then
        # Check if it's OpenAI whisper or whisper.cpp
        if "$WHISPER_COMMAND" --help 2>&1 | grep -q "whisper.cpp"; then
            TOOL="whisper_cpp"
        else
            TOOL="whisper"
        fi
    elif command -v whisper &>/dev/null; then
        # Fallback whisper command (might be cpp)
        if whisper --help 2>&1 | grep -q "whisper.cpp"; then
            TOOL="whisper_cpp"
        else
            TOOL="whisper"
        fi
    elif command -v "$VOSK_COMMAND" &>/dev/null; then
        TOOL="vosk"
    else
        log_error "No transcription tool found. Please install whisper, whisper.cpp, or vosk."
        exit 1
    fi
    log_info "Auto-detected tool: $TOOL"
fi

# ----------------------------------------------------------------------------
# Step 4: Set model if not provided
# ----------------------------------------------------------------------------
if [ -z "$MODEL_OR_OPTS" ]; then
    case "$TOOL" in
        whisper)       MODEL_OR_OPTS="$WHISPER_MODEL" ;;
        whisper_cpp)   MODEL_OR_OPTS="$WHISPER_CPP_MODEL" ;;
        vosk)          MODEL_OR_OPTS="" ;;
        *)             MODEL_OR_OPTS="" ;;
    esac
fi

# ----------------------------------------------------------------------------
# Step 5: Run the chosen tool
# ----------------------------------------------------------------------------
case "$TOOL" in
    whisper)
        log_info "Using OpenAI Whisper (model: $MODEL_OR_OPTS)"
        if ! command -v "$WHISPER_COMMAND" &>/dev/null; then
            log_error "whisper not found. Install: pip install openai-whisper"
            exit 1
        fi

        # Run whisper
        $WHISPER_COMMAND "$INPUT" \
            --model "$MODEL_OR_OPTS" \
            --language auto \
            --output_format srt,vtt \
            --output_dir "$OUTPUT_DIR" \
            2>/dev/null

        # Whisper names files by the input basename, so we need to rename
        BASENAME=$(basename "$INPUT" | sed 's/\.[^.]*$//')
        SRT_TEMP="$OUTPUT_DIR/$BASENAME.srt"
        VTT_TEMP="$OUTPUT_DIR/$BASENAME.vtt"

        if [ -f "$SRT_TEMP" ]; then
            mv "$SRT_TEMP" "${OUTPUT_BASE}.srt"
            log_success "SRT: ${OUTPUT_BASE}.srt"
        else
            log_warn "SRT file not generated at expected path: $SRT_TEMP"
        fi

        if [ -f "$VTT_TEMP" ]; then
            mv "$VTT_TEMP" "${OUTPUT_BASE}.vtt"
            log_success "VTT: ${OUTPUT_BASE}.vtt"
        else
            log_warn "VTT file not generated at expected path: $VTT_TEMP"
        fi
        ;;

    whisper_cpp)
        log_info "Using Whisper.cpp (model: $MODEL_OR_OPTS)"
        if ! command -v whisper &>/dev/null; then
            log_error "whisper (cpp) not found. Build from https://github.com/ggerganov/whisper.cpp"
            exit 1
        fi

        if [ ! -f "$MODEL_OR_OPTS" ]; then
            log_error "Model not found: $MODEL_OR_OPTS"
            log_info "Download a model: https://github.com/ggerganov/whisper.cpp#models"
            exit 1
        fi

        whisper -m "$MODEL_OR_OPTS" -f "$INPUT" \
            -osrt -ovtt -of "$OUTPUT_BASE" \
            2>/dev/null

        if [ -f "${OUTPUT_BASE}.srt" ]; then
            log_success "SRT: ${OUTPUT_BASE}.srt"
        else
            log_warn "SRT not generated (whisper_cpp may have failed)"
        fi

        if [ -f "${OUTPUT_BASE}.vtt" ]; then
            log_success "VTT: ${OUTPUT_BASE}.vtt"
        else
            log_warn "VTT not generated (whisper_cpp may have failed)"
        fi
        ;;

    vosk)
        log_info "Using Vosk"
        if ! command -v "$VOSK_COMMAND" &>/dev/null; then
            log_error "vosk-transcribe not found. Install: pip install vosk-transcribe"
            exit 1
        fi

        # Vosk outputs SRT directly
        $VOSK_COMMAND -i "$INPUT" -o "${OUTPUT_BASE}.srt" --format srt 2>/dev/null

        if [ -f "${OUTPUT_BASE}.srt" ]; then
            # Convert SRT to VTT (add header, swap commas to periods)
            {
                echo "WEBVTT"
                echo ""
                sed 's/,/./g' "${OUTPUT_BASE}.srt"
            } > "${OUTPUT_BASE}.vtt"
            log_success "SRT: ${OUTPUT_BASE}.srt"
            log_success "VTT: ${OUTPUT_BASE}.vtt"
        else
            log_error "Vosk transcription failed"
            exit 1
        fi
        ;;

    *)
        log_error "Unknown tool: $TOOL (supported: whisper, whisper_cpp, vosk)"
        exit 1
        ;;
esac

# ----------------------------------------------------------------------------
# Step 6: Verify and report
# ----------------------------------------------------------------------------
if [ -f "${OUTPUT_BASE}.srt" ] && [ -f "${OUTPUT_BASE}.vtt" ]; then
    log_success "✅ Transcript extraction complete!"
    echo "  SRT: ${OUTPUT_BASE}.srt"
    echo "  VTT: ${OUTPUT_BASE}.vtt"
    exit 0
else
    log_warn "Transcript extraction completed with partial results."
    [ -f "${OUTPUT_BASE}.srt" ] && echo "  SRT: ${OUTPUT_BASE}.srt (OK)"
    [ -f "${OUTPUT_BASE}.vtt" ] && echo "  VTT: ${OUTPUT_BASE}.vtt (OK)"
    exit 1
fi
