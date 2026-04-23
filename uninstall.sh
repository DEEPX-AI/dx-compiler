#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
PROJECT_ROOT=$(realpath "$SCRIPT_DIR")
DOWNLOAD_DIR="$SCRIPT_DIR/download"
PROJECT_NAME=$(basename "$SCRIPT_DIR")
VENV_PATH="$PROJECT_ROOT/venv-$PROJECT_NAME"

pushd "$PROJECT_ROOT" >&2

# color env settings
source ${PROJECT_ROOT}/scripts/color_env.sh
source ${PROJECT_ROOT}/scripts/common_util.sh

ENABLE_DEBUG_LOGS=0
TARGET_PKG="all"

show_help() {
    echo -e "Usage: ${COLOR_CYAN}$(basename "$0") [OPTIONS]${COLOR_RESET}"
    echo -e ""
    echo -e "Options:"
    echo -e "  ${COLOR_GREEN}[--target=<module_name>]${COLOR_RESET}              Uninstall specific module (dx_com | dx_tron | all) (default: all)"
    echo -e "  ${COLOR_GREEN}[-v|--verbose]${COLOR_RESET}                        Enable verbose (debug) logging"
    echo -e "  ${COLOR_GREEN}[-h|--help]${COLOR_RESET}                           Display this help message and exit"
    echo -e ""
    
    if [ "$1" == "error" ] && [[ ! -n "$2" ]]; then
        print_colored_v2 "ERROR" "Invalid or missing arguments."
        exit 1
    elif [ "$1" == "error" ] && [[ -n "$2" ]]; then
        print_colored_v2 "ERROR" "$2"
        exit 1
    elif [[ "$1" == "warn" ]] && [[ -n "$2" ]]; then
        print_colored_v2 "WARNING" "$2"
        return 0
    fi
    exit 0
}

uninstall_common_files() {
    delete_symlinks "$DOWNLOAD_DIR"
    delete_symlinks "$PROJECT_ROOT"
    delete_symlinks "${VENV_PATH}"
    delete_symlinks "${VENV_PATH}-local"
    delete_dir "${VENV_PATH}"
    delete_dir "${VENV_PATH}-local"
    delete_dir "${DOWNLOAD_DIR}"
}

uninstall_dx_com_files() {
    delete_dir "${PROJECT_ROOT}/dx_com"
}

uninstall_dx_tron_files() {
    delete_dir "${PROJECT_ROOT}/dx_tron"
}

uninstall_dx_com() {
    print_colored_v2 "INFO" "Uninstalling dx_com Python package..."

    local pip_cmd=""
    if [ -f "${VENV_PATH}-local/bin/pip3" ]; then
        pip_cmd="${VENV_PATH}-local/bin/pip3"
    elif [ -f "${VENV_PATH}/bin/pip3" ]; then
        pip_cmd="${VENV_PATH}/bin/pip3"
    fi

    if [ -n "$pip_cmd" ]; then
        if "$pip_cmd" uninstall -y dx_com 2>/dev/null; then
            print_colored_v2 "INFO" "dx_com uninstalled successfully."
        else
            print_colored_v2 "WARNING" "dx_com was not installed or already removed."
        fi
    else
        print_colored_v2 "WARNING" "No virtual environment found. Skipping pip uninstall of dx_com."
    fi
}

uninstall_dx_tron() {
    print_colored_v2 "INFO" "Uninstalling dxtron DEB package..."

    if dpkg -l dxtron &>/dev/null; then
        if sudo apt-get remove -y dxtron; then
            print_colored_v2 "INFO" "dxtron uninstalled successfully."
        else
            print_colored_v2 "WARNING" "Failed to uninstall dxtron. You may need to remove it manually."
        fi
    else
        print_colored_v2 "WARNING" "dxtron is not installed. Skipping."
    fi
}

main() {
    echo "Uninstalling ${PROJECT_NAME} ..."

    case $TARGET_PKG in
        dx_com)
            uninstall_dx_com
            uninstall_dx_com_files
            uninstall_common_files
            ;;
        dx_tron)
            uninstall_dx_tron
            uninstall_dx_tron_files
            ;;
        all)
            uninstall_dx_com
            uninstall_dx_tron
            uninstall_dx_com_files
            uninstall_dx_tron_files
            uninstall_common_files
            ;;
        *)
            show_help "error" "Invalid target '$TARGET_PKG'. Valid targets are: dx_com, dx_tron, all"
            ;;
    esac

    echo "Uninstalling ${PROJECT_NAME} done"
}

# parse args
for i in "$@"; do
    case "$1" in
        --target=*)
            TARGET_PKG="${1#*=}"
            ;;
        -v|--verbose)
            ENABLE_DEBUG_LOGS=1
            ;;
        -h|--help)
            show_help
            ;;
        *)
            show_help "error" "Invalid option '$1'"
            ;;
    esac
    shift
done

main

popd >&2

exit 0
