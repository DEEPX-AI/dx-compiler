#!/bin/bash
# =============================================================================
# [Step 1] Download Sample Models
#
# This script downloads sample model files (.onnx, .json) from the DEEPX SDK
# repository. It can be run standalone from a cloned dx-compiler repository
#
# Download output:
#   dx-compiler/example/sample_models/onnx/{MODEL_NAME}.onnx
#   dx-compiler/example/sample_models/json/{MODEL_NAME}.json
#
# Download cache (to avoid re-downloading on subsequent runs):
#   dx-compiler/download/
#
# Usage:
#   ./1-download_sample_models.sh
#   ./1-download_sample_models.sh --force    # Re-download even if files exist
# =============================================================================

SCRIPT_DIR=$(realpath "$(dirname "$0")")
COMPILER_DIR=$(realpath -s "${SCRIPT_DIR}/..")

# Use color env from dx-compiler/scripts/ (standalone-compatible)
source "${COMPILER_DIR}/scripts/color_env.sh"

BASE_URL="https://sdk.deepx.ai/"
SAMPLE_MODELS_DIR="${COMPILER_DIR}/dx_com/sample_models"
DOWNLOAD_CACHE_DIR="${COMPILER_DIR}/download"
FORCE_DOWNLOAD=false

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --force)
            FORCE_DOWNLOAD=true
            ;;
        -h | --help)
            echo "Usage: $(basename "$0") [--force]"
            echo "  --force   Re-download files even if they already exist"
            exit 0
            ;;
    esac
done

echo ""
echo "======== PATH INFO ========="
echo "  COMPILER_DIR    : ${COMPILER_DIR}"
echo "  SAMPLE_MODELS   : ${SAMPLE_MODELS_DIR}"
echo "  DOWNLOAD_CACHE  : ${DOWNLOAD_CACHE_DIR}"
echo "  BASE_URL        : ${BASE_URL}"
echo "============================"
echo ""

# -----------------------------------------------------------------------------
# Ensure curl is available
# -----------------------------------------------------------------------------
if ! command -v curl &>/dev/null; then
    echo "curl is not installed. Installing..."
    sudo apt update && sudo apt install -y curl
    if ! command -v curl &>/dev/null; then
        echo -e "${TAG_ERROR} Failed to install curl."
        exit 1
    fi
fi

# -----------------------------------------------------------------------------
# Create output and cache directories
# -----------------------------------------------------------------------------
mkdir -p "${SAMPLE_MODELS_DIR}/onnx"
mkdir -p "${SAMPLE_MODELS_DIR}/json"
mkdir -p "${DOWNLOAD_CACHE_DIR}"

# -----------------------------------------------------------------------------
# Helper: download a single file
#   $1 : source path relative to BASE_URL  (e.g. modelzoo/onnx/YOLOV5S-1.onnx)
#   $2 : output file path
# Returns 0 on success, 1 on failure.
# -----------------------------------------------------------------------------
download_file() {
    local src_path="$1"
    local output_path="$2"
    local url="${BASE_URL}${src_path}"

    if [ -f "${output_path}" ] && [ "${FORCE_DOWNLOAD}" = false ]; then
        echo "  [SKIP] Already exists: $(basename "${output_path}")"
        return 0
    fi

    echo "  Downloading : ${url}"
    echo "  Saving to   : ${output_path}"
    curl -fL -o "${output_path}" "${url}"
    if [ $? -ne 0 ]; then
        rm -f "${output_path}"
        echo -e "  ${TAG_ERROR} Download failed: ${url}"
        return 1
    fi
    echo "  ✅ Download OK"
    return 0
}

# -----------------------------------------------------------------------------
# Download models
# -----------------------------------------------------------------------------
MODEL_NAME_LIST=("YOLOV5S-1" "YOLOV5S_Face-1" "MobileNetV2-1")
EXT_LIST=("onnx" "json")

DOWNLOAD_SUCCESS=()
DOWNLOAD_FAILED=()

TOTAL_FILES=$(( ${#MODEL_NAME_LIST[@]} * ${#EXT_LIST[@]} ))
NUM=0

for model in "${MODEL_NAME_LIST[@]}"; do
    for ext in "${EXT_LIST[@]}"; do
        NUM=$((NUM + 1))
        echo "------------------------------------------------------------"
        echo "  [${NUM}/${TOTAL_FILES}] ${model}.${ext}"
        echo "------------------------------------------------------------"

        SRC_PATH="modelzoo/${ext}/${model}.${ext}"
        OUTPUT_PATH="${SAMPLE_MODELS_DIR}/${ext}/${model}.${ext}"

        download_file "${SRC_PATH}" "${OUTPUT_PATH}"
        if [ $? -eq 0 ]; then
            DOWNLOAD_SUCCESS+=("${model}.${ext}")
        else
            DOWNLOAD_FAILED+=("${model}.${ext}")
        fi
        echo ""
    done
done

# -----------------------------------------------------------------------------
# Completion report
# -----------------------------------------------------------------------------
echo "============================================================"
echo "  ✅ Sample model download complete"
echo "------------------------------------------------------------"
echo "  Total   : ${TOTAL_FILES} file(s)"
echo "  Success : ${#DOWNLOAD_SUCCESS[@]}"
echo "  Failed  : ${#DOWNLOAD_FAILED[@]}"
echo ""
echo "  Output directory: ${SAMPLE_MODELS_DIR}/"
echo ""

if [ ${#DOWNLOAD_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed files:"
    for f in "${DOWNLOAD_FAILED[@]}"; do
        echo "    - ${f}"
    done
    echo ""
    exit 1
fi

echo "  Next step: run ./2-download_sample_calibration_dataset.sh"
echo "============================================================"
echo ""
exit 0