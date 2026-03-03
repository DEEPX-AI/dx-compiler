#!/bin/bash
# =============================================================================
# [Step 3] Compile Sample Models
#
# This script compiles the sample models using the dxcom compiler.
# It can be run standalone from a cloned dx-compiler repository
# without requiring dx-all-suite or getting-started scripts.
#
# Prerequisites:
#   1. ./1-download_sample_models.sh completed
#      -> dx-compiler/example/sample_models/onnx/ and json/ exist
#   2. ./2-download_sample_calibration_dataset.sh completed
#      -> dx-compiler/example/calibration_dataset/ exists
#
# Compilation inputs:
#   - Model  : dx-compiler/example/sample_models/onnx/{MODEL}.onnx
#   - Config : dx-compiler/example/sample_models/json/{MODEL}.json
#   - Dataset: dx-compiler/example/calibration_dataset/
#
# Compilation output:
#   - dx-compiler/example/output/{MODEL}.dxnn
#
# Usage:
#   ./3-compile_sample_models.sh
#   ./3-compile_sample_models.sh --force-install    # Force reinstall dx-compiler
# =============================================================================

SCRIPT_DIR=$(realpath "$(dirname "$0")")
COMPILER_DIR=$(realpath -s "${SCRIPT_DIR}/..")

# Use scripts from dx-compiler/scripts/ (standalone-compatible)
source "${COMPILER_DIR}/scripts/color_env.sh"
source "${COMPILER_DIR}/scripts/common_util.sh"

SAMPLE_MODELS_DIR="${COMPILER_DIR}/dx_com/sample_models"
CALIBRATION_DATASET_DIR="${COMPILER_DIR}/dx_com/calibration_dataset"
OUTPUT_DIR="${COMPILER_DIR}/dx_com/output"
PROJECT_NAME="dx-compiler"

# List of sample models to compile
MODEL_NAME_LIST=("YOLOV5S-1" "YOLOV5S_Face-1" "MobileNetV2-1")

# Arrays to track results
COMPILE_SUCCESS=()
COMPILE_FAILED=()

# Parse arguments
FORCE_INSTALL=false
for arg in "$@"; do
    case "$arg" in
        --force-install)
            FORCE_INSTALL=true
            ;;
        -h | --help)
            echo "Usage: $(basename "$0") [--force-install]"
            echo "  --force-install   Force reinstall dx-compiler even if dxcom is working"
            exit 0
            ;;
    esac
done

echo ""
echo "======== PATH INFO ========="
echo "  COMPILER_DIR    : ${COMPILER_DIR}"
echo "  SAMPLE_MODELS   : ${SAMPLE_MODELS_DIR}"
echo "  CALIBRATION DS  : ${CALIBRATION_DATASET_DIR}"
echo "  OUTPUT          : ${OUTPUT_DIR}"
echo "============================"
echo ""

# -----------------------------------------------------------------------------
# [Pre-check] Verify prerequisites
# -----------------------------------------------------------------------------
echo "[Pre-check] Verifying required paths..."

if [ ! -d "${SAMPLE_MODELS_DIR}/onnx" ] || [ ! -d "${SAMPLE_MODELS_DIR}/json" ]; then
    echo -e "${TAG_ERROR} Sample models not found: ${SAMPLE_MODELS_DIR}"
    echo "        Please run ./1-download_sample_models.sh first."
    exit 1
fi
echo "  ✅ Sample models path OK: ${SAMPLE_MODELS_DIR}"

if [ ! -d "${CALIBRATION_DATASET_DIR}" ]; then
    echo -e "${TAG_ERROR} Calibration dataset not found: ${CALIBRATION_DATASET_DIR}"
    echo "        Please run ./2-download_sample_calibration_dataset.sh first."
    exit 1
fi
echo "  ✅ Calibration dataset path OK: ${CALIBRATION_DATASET_DIR}"
echo ""

# -----------------------------------------------------------------------------
# [Step 1] Check and install dx-compiler if needed (standalone)
#
#   In standalone mode, we call dx-compiler/install.sh directly.
#   If dxcom is already available and --force-install is not set, skip.
# -----------------------------------------------------------------------------
echo "[Step 1] Checking dx-compiler (dxcom) installation..."

_is_dxcom_available() {
    # 1st check: dxcom available in current PATH
    if command -v dxcom &>/dev/null; then
        print_colored_v2 "INFO" "dxcom is already available in PATH."
        dxcom -v
        return 0
    fi

    # 2nd check: activate venv and check again
    print_colored_v2 "INFO" "dxcom not found in PATH. Checking venv..."
    local venv_path
    if check_container_mode; then
        venv_path="${COMPILER_DIR}/venv-${PROJECT_NAME}"
    else
        venv_path="${COMPILER_DIR}/venv-${PROJECT_NAME}-local"
    fi

    if [ -f "${venv_path}/bin/activate" ]; then
        print_colored_v2 "INFO" "Activating venv: ${venv_path}"
        source "${venv_path}/bin/activate"
        if command -v dxcom &>/dev/null; then
            print_colored_v2 "INFO" "dxcom is available in venv."
            dxcom -v
            return 0
        fi
    fi

    return 1
}

if [ "${FORCE_INSTALL}" = false ] && _is_dxcom_available; then
    echo "[Step 1] dxcom already installed. Skipping installation."
else
    echo "[Step 1] Installing dx-compiler..."
    echo "         Script: ${COMPILER_DIR}/install.sh"
    echo ""
    pushd "${COMPILER_DIR}" >/dev/null
    ./install.sh
    INSTALL_EXIT=$?
    popd >/dev/null
    if [ ${INSTALL_EXIT} -ne 0 ]; then
        echo -e "${TAG_ERROR} dx-compiler installation failed."
        exit 1
    fi
    echo "[Step 1] dx-compiler installation complete."
fi
echo ""

# -----------------------------------------------------------------------------
# [Step 2] Activate the dxcom virtual environment
# -----------------------------------------------------------------------------
echo "[Step 2] Activating dxcom virtual environment..."

if check_container_mode; then
    VENV_PATH="${COMPILER_DIR}/venv-${PROJECT_NAME}"
else
    VENV_PATH="${COMPILER_DIR}/venv-${PROJECT_NAME}-local"
fi

if [ ! -f "${VENV_PATH}/bin/activate" ]; then
    echo -e "${TAG_ERROR} Virtual environment not found: ${VENV_PATH}"
    echo "        Please verify that ${COMPILER_DIR}/install.sh ran successfully."
    exit 1
fi

source "${VENV_PATH}/bin/activate"
echo "  ✅ Virtual environment activated: ${VENV_PATH}"
echo "  dxcom version:"
dxcom -v 2>&1 | sed 's/^/    /'
echo ""

# -----------------------------------------------------------------------------
# [Step 3] Create output directory
# -----------------------------------------------------------------------------
echo "[Step 3] Creating output directory..."
mkdir -p "${OUTPUT_DIR}"
echo "  ✅ Output directory: ${OUTPUT_DIR}"
echo ""

# -----------------------------------------------------------------------------
# [Step 4] Compile sample models
#
#   dxcom is run from SCRIPT_DIR so that "./calibration_dataset" in the JSON
#   config resolves to dx-compiler/example/calibration_dataset/.
# -----------------------------------------------------------------------------
echo "[Step 4] Starting model compilation..."
echo "         Models to compile: ${#MODEL_NAME_LIST[@]}"
echo ""

cd "${COMPILER_DIR}/dx_com"

TOTAL=${#MODEL_NAME_LIST[@]}
for i in "${!MODEL_NAME_LIST[@]}"; do
    MODEL_NAME="${MODEL_NAME_LIST[$i]}"
    NUM=$((i + 1))

    ONNX_FILE="${SAMPLE_MODELS_DIR}/onnx/${MODEL_NAME}.onnx"
    JSON_FILE="${SAMPLE_MODELS_DIR}/json/${MODEL_NAME}.json"

    echo "------------------------------------------------------------"
    echo "  [${NUM}/${TOTAL}] Compiling: ${MODEL_NAME}"
    echo "------------------------------------------------------------"
    echo "  Model  : ${ONNX_FILE}"
    echo "  Config : ${JSON_FILE}"
    echo "  Output : ${OUTPUT_DIR}/"
    echo ""

    if [ ! -f "${ONNX_FILE}" ]; then
        echo "  [WARNING] ONNX file not found: ${ONNX_FILE}. Skipping."
        COMPILE_FAILED+=("${MODEL_NAME} (file not found)")
        echo ""
        continue
    fi
    if [ ! -f "${JSON_FILE}" ]; then
        echo "  [WARNING] JSON config not found: ${JSON_FILE}. Skipping."
        COMPILE_FAILED+=("${MODEL_NAME} (file not found)")
        echo ""
        continue
    fi

    COMPILE_CMD="dxcom -m ${ONNX_FILE} -c ${JSON_FILE} -o ${OUTPUT_DIR}/"
    echo "  Command: ${COMPILE_CMD}"
    echo ""

    ${COMPILE_CMD}

    if [ $? -eq 0 ]; then
        echo ""
        echo "  ✅ [${NUM}/${TOTAL}] ${MODEL_NAME} compiled successfully"
        COMPILE_SUCCESS+=("${MODEL_NAME}")
    else
        echo ""
        echo "  ❌ [${NUM}/${TOTAL}] ${MODEL_NAME} compilation failed"
        COMPILE_FAILED+=("${MODEL_NAME}")
    fi
    echo ""
done

# -----------------------------------------------------------------------------
# Completion report
# -----------------------------------------------------------------------------
echo "============================================================"
echo "  📋 Compilation Result Report"
echo "------------------------------------------------------------"
echo "  Total   : ${TOTAL}"
echo "  Success : ${#COMPILE_SUCCESS[@]}"
echo "  Failed  : ${#COMPILE_FAILED[@]}"
echo ""

if [ ${#COMPILE_SUCCESS[@]} -gt 0 ]; then
    echo "  ✅ Successfully compiled:"
    for m in "${COMPILE_SUCCESS[@]}"; do
        DXNN_FILE="${OUTPUT_DIR}/${m}.dxnn"
        if [ -f "${DXNN_FILE}" ]; then
            FILESIZE=$(du -h "${DXNN_FILE}" | cut -f1)
            echo "    - ${m}  ->  ${DXNN_FILE}  (${FILESIZE})"
        else
            echo "    - ${m}  ->  ${DXNN_FILE}"
        fi
    done
    echo ""
fi

if [ ${#COMPILE_FAILED[@]} -gt 0 ]; then
    echo "  ❌ Failed to compile:"
    for m in "${COMPILE_FAILED[@]}"; do
        echo "    - ${m}"
    done
    echo ""
fi

echo "  Output directory: ${OUTPUT_DIR}/"
echo "============================================================"
echo ""

[ ${#COMPILE_FAILED[@]} -gt 0 ] && exit 1
exit 0