#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
COMPILER_PATH=$(realpath -s "${SCRIPT_DIR}/..")
DX_AS_PATH=$(realpath -s "${COMPILER_PATH}/..")

echo -e "======== PATH INFO ========="
echo "COMPILER_PATH($COMPILER_PATH)"
echo "DX_AS_PATH($DX_AS_PATH)"
echo -e "============================"

MODULE_NAME=""
FORCE_ARGS=""

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo "Options:"
    echo "  [--force]                    : Force overwrite if the file already exists"
    echo "  [--help]                     : Show this help message"

    if [ "$1" == "error" ] && [[ ! -n "$2" ]]; then
        echo -e "${TAG_ERROR} Invalid or missing arguments."
        exit 1
    elif [ "$1" == "error" ] && [[ -n "$2" ]]; then
        echo -e "${TAG_ERROR} $2"
        exit 1
    elif [[ "$1" == "warn" ]] && [[ -n "$2" ]]; then
        echo -e "${TAG_WARN} $2"
        return 0
    fi
    exit 0
}

# parse args
for i in "$@"; do
    case "$1" in
        --force)
            FORCE_ARGS="--force"
            ;;
        --help)
            show_help
            ;;
        *)
            show_help "error" "Invalid option '$1'"
            ;;
    esac
    shift
done

# usage
BASE_URL="https://sdk.deepx.ai/"

# default value
SOURCE_PATH="res/onnx/onnx-20250407-01.tar.gz"
OUTPUT_DIR="${COMPILER_PATH}/dx_com/res_onnx_archives"
EXTRACT_ARGS="--extract"

SYMLINK_TARGET_PATH="${DX_AS_PATH}/workspace/res/onnx"
SYMLINK_ARGS="--symlink_target_path=$SYMLINK_TARGET_PATH"

GET_RES_CMD="${DX_AS_PATH}/scripts/get_resource.sh --src_path=$SOURCE_PATH --output=$OUTPUT_DIR $EXTRACT_ARGS $SYMLINK_ARGS $FORCE_ARGS"
echo "Get Resources from remote server ..."
echo "$GET_RES_CMD"

$GET_RES_CMD
if [ $? -ne 0 ]; then
    echo "Get ${SOURCE_PATH} failed!"
    exit 1
fi

exit 0
