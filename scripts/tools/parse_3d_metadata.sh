#!/bin/bash
# parse_3d_metadata.sh - Extract metadata from 3D model files.
# Usage: ./parse_3d_metadata.sh <file_path>
# Output: JSON (stdout)

set -euo pipefail

# ----------------------------------------------------------------------------
# CONFIGURATION
# ----------------------------------------------------------------------------
DCMDUMP_CMD="${DCMDUMP_CMD:-dcmdump}"
GLTF_VALIDATOR_CMD="${GLTF_VALIDATOR_CMD:-gltf-validator}"
FILE_CMD="${FILE_CMD:-file}"

# ----------------------------------------------------------------------------
# HELPERS
# ----------------------------------------------------------------------------
log_error() { echo "❌ $*" >&2; }

# ----------------------------------------------------------------------------
# MAIN
# ----------------------------------------------------------------------------
if [ $# -lt 1 ]; then
    echo "Usage: $0 <3d_file_path>" >&2
    echo "Supported formats: obj, stl, ply, gltf, glb, dae, fbx, 3ds, splat, dcm, dicom" >&2
    exit 1
fi

INPUT="$1"
if [ ! -f "$INPUT" ]; then
    log_error "File not found: $INPUT"
    exit 1
fi

# Determine extension and format
EXT="${INPUT##*.}"
EXT="${EXT,,}"
BASENAME=$(basename "$INPUT")
SIZE=$(stat -c %s "$INPUT" 2>/dev/null || stat -f %z "$INPUT" 2>/dev/null || echo "0")

# ----------------------------------------------------------------------------
# FORMAT-SPECIFIC PARSING
# ----------------------------------------------------------------------------
case "$EXT" in
    obj)
        # OBJ: count vertices (v), faces (f), and objects (o)
        VERTICES=$(grep -c "^v " "$INPUT" 2>/dev/null || echo "0")
        FACES=$(grep -c "^f " "$INPUT" 2>/dev/null || echo "0")
        OBJECTS=$(grep -c "^o " "$INPUT" 2>/dev/null || echo "0")
        GROUPS=$(grep -c "^g " "$INPUT" 2>/dev/null || echo "0")
        jq -n \
            --arg format "obj" \
            --arg file "$BASENAME" \
            --arg size "$SIZE" \
            --arg vertices "$VERTICES" \
            --arg faces "$FACES" \
            --arg objects "$OBJECTS" \
            --arg groups "$GROUPS" \
            '{
                format: $format,
                file: $file,
                size_bytes: ($size | tonumber),
                vertices: ($vertices | tonumber),
                faces: ($faces | tonumber),
                objects: ($objects | tonumber),
                groups: ($groups | tonumber)
            }'
        ;;

    stl)
        # STL: detect ASCII or binary; count triangles
        if head -c 80 "$INPUT" 2>/dev/null | grep -q "solid" && ! head -c 84 "$INPUT" 2>/dev/null | grep -q "ASCII"; then
            # Could be binary with "solid" in header; check length
            FILE_SIZE=$(stat -c %s "$INPUT" 2>/dev/null || stat -f %z "$INPUT" 2>/dev/null || echo "0")
            if [ "$FILE_SIZE" -gt 84 ]; then
                # Rough estimation: binary STL header 84 bytes + 50 bytes per triangle
                TRIANGLES=$(( (FILE_SIZE - 84) / 50 ))
                FORMAT="binary"
            else
                FORMAT="ascii"
            fi
        else
            # ASCII STL: count "facet" lines
            TRIANGLES=$(grep -c "facet" "$INPUT" 2>/dev/null || echo "0")
            FORMAT="ascii"
        fi
        # If we haven't set triangles yet (binary case with no line count)
        if [ -z "${TRIANGLES:-}" ]; then
            TRIANGLES=$(( (FILE_SIZE - 84) / 50 ))
        fi
        jq -n \
            --arg format "stl" \
            --arg file "$BASENAME" \
            --arg size "$SIZE" \
            --arg triangles "$TRIANGLES" \
            --arg stl_format "$FORMAT" \
            '{
                format: $format,
                file: $file,
                size_bytes: ($size | tonumber),
                triangles: ($triangles | tonumber),
                stl_format: $stl_format
            }'
        ;;

    ply)
        # PLY: detect ASCII or binary, count vertices and faces
        if head -c 20 "$INPUT" 2>/dev/null | grep -q "ply"; then
            # Parse header
            HEADER=$(head -n 30 "$INPUT" 2>/dev/null)
            VERTICES=$(echo "$HEADER" | grep -i "element vertex" | awk '{print $3}')
            FACES=$(echo "$HEADER" | grep -i "element face" | awk '{print $3}')
            # Determine format
            if echo "$HEADER" | grep -q "format ascii"; then
                PLY_FORMAT="ascii"
            elif echo "$HEADER" | grep -q "format binary"; then
                PLY_FORMAT="binary"
            else
                PLY_FORMAT="unknown"
            fi
            VERTICES=${VERTICES:-0}
            FACES=${FACES:-0}
        else
            VERTICES=0
            FACES=0
            PLY_FORMAT="unknown"
        fi
        jq -n \
            --arg format "ply" \
            --arg file "$BASENAME" \
            --arg size "$SIZE" \
            --arg vertices "$VERTICES" \
            --arg faces "$FACES" \
            --arg ply_format "$PLY_FORMAT" \
            '{
                format: $format,
                file: $file,
                size_bytes: ($size | tonumber),
                vertices: ($vertices | tonumber),
                faces: ($faces | tonumber),
                ply_format: $ply_format
            }'
        ;;

    gltf|glb)
        # GLTF/GLB: use gltf-validator if available, otherwise basic info
        if command -v "$GLTF_VALIDATOR_CMD" &>/dev/null; then
            # Run validator and capture output
            VALID_OUTPUT=$($GLTF_VALIDATOR_CMD "$INPUT" 2>/dev/null | jq -c '.' 2>/dev/null || echo '{}')
            jq -n \
                --arg format "$EXT" \
                --arg file "$BASENAME" \
                --arg size "$SIZE" \
                --argjson valid "$VALID_OUTPUT" \
                '{
                    format: $format,
                    file: $file,
                    size_bytes: ($size | tonumber),
                    validator: $valid
                }'
        else
            # Basic info: for GLB, we can read the JSON header
            if [ "$EXT" = "glb" ]; then
                # Try to extract version and length from binary glb
                VERSION=$(dd if="$INPUT" bs=1 skip=4 count=4 2>/dev/null | xxd -p | xxd -r -p | od -An -v -t u4 | head -1)
                LENGTH=$(dd if="$INPUT" bs=1 skip=8 count=4 2>/dev/null | xxd -p | xxd -r -p | od -An -v -t u4 | head -1)
            else
                # For gltf, we can parse the JSON
                if command -v jq &>/dev/null; then
                    SCENE=$(jq -r '.scene // "unknown"' "$INPUT" 2>/dev/null)
                    ASSET=$(jq -r '.asset.version // "unknown"' "$INPUT" 2>/dev/null)
                else
                    SCENE="unknown"
                    ASSET="unknown"
                fi
            fi
            jq -n \
                --arg format "$EXT" \
                --arg file "$BASENAME" \
                --arg size "$SIZE" \
                --arg version "${VERSION:-unknown}" \
                --arg length "${LENGTH:-unknown}" \
                --arg asset "${ASSET:-unknown}" \
                --arg scene "${SCENE:-unknown}" \
                '{
                    format: $format,
                    file: $file,
                    size_bytes: ($size | tonumber),
                    version: $version,
                    length: $length,
                    asset_version: $asset,
                    scene: $scene
                }'
        fi
        ;;

    dcm|dicom)
        # DICOM: use dcmdump if available, otherwise basic info
        if command -v "$DCMDUMP_CMD" &>/dev/null; then
            # Extract some common tags
            DCM_INFO=$($DCMDUMP_CMD "$INPUT" 2>/dev/null | head -50)
            # Parse key fields (simplified)
            PATIENT_NAME=$(echo "$DCM_INFO" | grep "Patient's Name" | head -1 | sed 's/.*: //' || echo "")
            STUDY_DATE=$(echo "$DCM_INFO" | grep "Study Date" | head -1 | sed 's/.*: //' || echo "")
            MODALITY=$(echo "$DCM_INFO" | grep "Modality" | head -1 | sed 's/.*: //' || echo "")
            SERIES_DESC=$(echo "$DCM_INFO" | grep "Series Description" | head -1 | sed 's/.*: //' || echo "")
            jq -n \
                --arg format "dicom" \
                --arg file "$BASENAME" \
                --arg size "$SIZE" \
                --arg patient "$PATIENT_NAME" \
                --arg study "$STUDY_DATE" \
                --arg modality "$MODALITY" \
                --arg series "$SERIES_DESC" \
                '{
                    format: $format,
                    file: $file,
                    size_bytes: ($size | tonumber),
                    patient_name: $patient,
                    study_date: $study,
                    modality: $modality,
                    series_description: $series
                }'
        else
            jq -n \
                --arg format "dicom" \
                --arg file "$BASENAME" \
                --arg size "$SIZE" \
                --arg note "dcmdump not installed; install dcmtk for full metadata" \
                '{
                    format: $format,
                    file: $file,
                    size_bytes: ($size | tonumber),
                    note: $note
                }'
        fi
        ;;

    splat)
        # Gaussian Splat file – just basic info (size, format)
        jq -n \
            --arg format "splat" \
            --arg file "$BASENAME" \
            --arg size "$SIZE" \
            '{
                format: $format,
                file: $file,
                size_bytes: ($size | tonumber),
                type: "gaussian_splat"
            }'
        ;;

    *)
        # Fallback for other 3D formats (dae, fbx, 3ds, etc.)
        # Use `file` command for basic info
        FILE_INFO=$($FILE_CMD -b "$INPUT" 2>/dev/null || echo "3D model")
        jq -n \
            --arg format "$EXT" \
            --arg file "$BASENAME" \
            --arg size "$SIZE" \
            --arg info "$FILE_INFO" \
            '{
                format: $format,
                file: $file,
                size_bytes: ($size | tonumber),
                file_info: $info,
                note: "Unsupported format; basic info only"
            }'
        ;;
esac
