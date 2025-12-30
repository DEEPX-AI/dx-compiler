#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
PROJECT_ROOT=$(realpath "$SCRIPT_DIR")
COMPILER_PATH=$(realpath -s "${SCRIPT_DIR}")
TRON_BASE_PATH=$(realpath -s "${COMPILER_PATH}/dx_tron")

pushd "$PROJECT_ROOT" >&2

source "${COMPILER_PATH}/scripts/color_env.sh"
source "${COMPILER_PATH}/scripts/common_util.sh"

print_colored_v2 "WARNING" "DX-TRON is being run with the **'--no-sandbox'** flag because it is inside a Docker container. However, this is **not recommended** for security reasons."

main() {
    ${TRON_BASE_PATH}/dxtron*.AppImage --no-sandbox > /dev/null 2>&1
}

main

popd >&2
exit 0
