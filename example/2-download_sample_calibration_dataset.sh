#!/bin/bash
# =============================================================================
# [Step 2] Download Sample Calibration Dataset
#
# This script downloads the calibration dataset required for INT8 quantization
# compilation and extracts it to dx-compiler/example/calibration_dataset/.
# It also patches the "dataset_path" field in the sample model JSON configs.
#
# This script can be run standalone from a cloned dx-compiler repository
# without requiring dx-all-suite or getting-started scripts.
#
# Prerequisites:
#   ./1-download_sample_models.sh must be run first so that the JSON config
#   files exist in dx-compiler/example/sample_models/json/.
#
# Download output:
#   dx-compiler/example/calibration_dataset/   (extracted dataset images)
#
# Download cache:
#   dx-compiler/download/calibration_dataset.tar.gz
#
# Usage:
#   ./2-download_sample_calibration_dataset.sh
#   ./2-download_sample_calibration_dataset.sh --force    # Re-download and re-extract
# =============================================================================

SCRIPT_DIR=$(realpath "$(dirname "$0")")
COMPILER_DIR=$(realpath -s "${SCRIPT_DIR}/..")

# Use color env from dx-compiler/scripts/ (standalone-compatible)
source "${COMPILER_DIR}/scripts/color_env.sh"

BASE_URL="https://sdk.deepx.ai/"
CALIBRATION_DATASET_DIR="${COMPILER_DIR}/dx_com/calibration_dataset"
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
            echo "  --force   Re-download and re-extract even if files already exist"
            exit 0
            ;;
    esac
done

echo ""
echo "======== PATH INFO ========="
echo "  COMPILER_DIR             : ${COMPILER_DIR}"
echo "  CALIBRATION_DATASET_DIR  : ${CALIBRATION_DATASET_DIR}"
echo "  SAMPLE_MODELS_DIR        : ${SAMPLE_MODELS_DIR}"
echo "  DOWNLOAD_CACHE_DIR       : ${DOWNLOAD_CACHE_DIR}"
echo "  BASE_URL                 : ${BASE_URL}"
echo "============================"
echo ""

# Ensure curl is available
if ! command -v curl &>/dev/null; then
    echo "curl is not installed. Installing..."
    sudo apt update && sudo apt install -y curl
    if ! command -v curl &>/dev/null; then
        echo -e "${TAG_ERROR} Failed to install curl."
        exit 1
    fi
fi

mkdir -p "${DOWNLOAD_CACHE_DIR}"

# -----------------------------------------------------------------------------
# [Step 1] Download calibration_dataset.tar.gz (with cache)
# -----------------------------------------------------------------------------
SRC_PATH="dataset/calibration_dataset.tar.gz"
FILENAME="calibration_dataset.tar.gz"
CACHED_TAR="${DOWNLOAD_CACHE_DIR}/${FILENAME}"
URL="${BASE_URL}${SRC_PATH}"

echo "[Step 1] Downloading calibration dataset archive..."
if [ -f "${CACHED_TAR}" ] && [ "${FORCE_DOWNLOAD}" = false ]; then
    echo "  [SKIP] Cached archive already exists: ${CACHED_TAR}"
else
    echo "  Downloading : ${URL}"
    echo "  Saving to   : ${CACHED_TAR}"
    curl -fL -o "${CACHED_TAR}" "${URL}"
    if [ $? -ne 0 ]; then
        rm -f "${CACHED_TAR}"
        echo -e "${TAG_ERROR} Download failed: ${URL}"
        exit 1
    fi
    echo "  ✅ Download OK"
fi
echo ""

# -----------------------------------------------------------------------------
# [Step 2] Extract calibration_dataset.tar.gz
# -----------------------------------------------------------------------------
echo "[Step 2] Extracting calibration dataset..."
if [ -d "${CALIBRATION_DATASET_DIR}" ] && [ "${FORCE_DOWNLOAD}" = false ]; then
    echo "  [SKIP] Already extracted: ${CALIBRATION_DATASET_DIR}"
else
    rm -rf "${CALIBRATION_DATASET_DIR}"
    mkdir -p "${CALIBRATION_DATASET_DIR}"
    echo "  Extracting ${FILENAME} to ${CALIBRATION_DATASET_DIR}..."

    # Auto-detect whether the tar has a top-level directory and strip it
    FIRST_ENTRY=$(tar tf "${CACHED_TAR}" 2>/dev/null | head -n 1)
    if [[ "${FIRST_ENTRY}" == */* ]]; then
        tar xfz "${CACHED_TAR}" --strip-components=1 -C "${CALIBRATION_DATASET_DIR}"
    else
        tar xfz "${CACHED_TAR}" -C "${CALIBRATION_DATASET_DIR}"
    fi

    if [ $? -ne 0 ]; then
        echo -e "${TAG_ERROR} Extraction failed."
        exit 1
    fi
    echo "  ✅ Extraction OK"
fi
echo ""

# -----------------------------------------------------------------------------
# [Step 3] Patch "dataset_path" in sample model JSON config files
#
#   The JSON config files reference "dataset_path" which must point to the
#   calibration dataset directory relative to the compile working directory.
#   This step sets it to "./calibration_dataset" so that dxcom finds the
#   dataset when run from dx-compiler/example/.
# -----------------------------------------------------------------------------
echo "[Step 3] Patching dataset_path in JSON config files..."

MODEL_NAME_LIST=("YOLOV5S-1" "YOLOV5S_Face-1" "MobileNetV2-1")
PATCH_SUCCESS=0
PATCH_SKIP=0
PATCH_WARN=0

for model in "${MODEL_NAME_LIST[@]}"; do
    TARGET_FILE="${SAMPLE_MODELS_DIR}/json/${model}.json"
    ORIGIN_FILE="${TARGET_FILE}.bak"

    if [ ! -f "${TARGET_FILE}" ]; then
        echo "  [WARNING] JSON config not found: ${TARGET_FILE}"
        echo "            Run ./1-download_sample_models.sh first."
        PATCH_WARN=$((PATCH_WARN + 1))
        continue
    fi

    if [ -f "${ORIGIN_FILE}" ] && [ "${FORCE_DOWNLOAD}" = false ]; then
        echo "  [SKIP] Already patched: ${model}.json"
        PATCH_SKIP=$((PATCH_SKIP + 1))
        continue
    fi

    cp "${TARGET_FILE}" "${ORIGIN_FILE}"
    sed -i 's|"dataset_path"[[:space:]]*:[[:space:]]*".*"|"dataset_path": "./calibration_dataset"|g' "${TARGET_FILE}"
    if [ $? -ne 0 ]; then
        echo -e "  ${TAG_ERROR} Failed to patch dataset_path in ${TARGET_FILE}"
        exit 1
    fi
    echo "  ✅ Patched dataset_path in ${model}.json"
    PATCH_SUCCESS=$((PATCH_SUCCESS + 1))
done
echo ""

# -----------------------------------------------------------------------------
# Completion report
# -----------------------------------------------------------------------------
FILE_COUNT=$(find "${CALIBRATION_DATASET_DIR}" -type f 2>/dev/null | wc -l)

echo "============================================================"
echo "  ✅ Calibration dataset ready"
echo "------------------------------------------------------------"
echo "  Archive cache            : ${CACHED_TAR}"
echo "  Extracted to             : ${CALIBRATION_DATASET_DIR}"
echo "  Dataset file count       : ${FILE_COUNT} file(s)"
echo ""
echo "  JSON patch summary:"
echo "    Patched : ${PATCH_SUCCESS}"
echo "    Skipped : ${PATCH_SKIP}"
echo "    Warning : ${PATCH_WARN}"
echo ""
echo "  Next step: run ./3-compile_sample_models.sh"
echo "============================================================"
echo ""
exit 0