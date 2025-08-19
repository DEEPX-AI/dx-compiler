#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
PROJECT_ROOT=$(realpath "$SCRIPT_DIR")
COMPILER_PATH=$(realpath -s "${SCRIPT_DIR}")

pushd "$PROJECT_ROOT" >&2
# load print_colored()
#   - usage: print_colored "message contents" "type"
#      - types: ERROR FAIL INFO WARNING DEBUG RED BLUE YELLOW GREEN
source "${COMPILER_PATH}/scripts/color_env.sh"
source "${COMPILER_PATH}/scripts/common_util.sh"

# --- Initialize variables for credentials and options ---
PROJECT_NAME="dx-compiler"
CLI_USERNAME=""
CLI_PASSWORD=""
ARCHIVE_MODE="n"
FORCE_ARGS="" # Will be "--force" if --force is passed
VERBOSE_ARGS=""
ENABLE_DEBUG_LOGS=0   # New flag for debug logging
DOCKER_VOLUME_PATH=${DOCKER_VOLUME_PATH}
USE_FORCE=0
REUSE_VENV=1
FORCE_REMOVE_VENV=0
VENV_SYSTEM_SITE_PACKAGES_ARGS=""

# Global variables for script configuration
PYTHON_VERSION=""
MIN_PY_VERSION="3.8.0"
# VENV_PATH and VENV_SYMLINK_TARGET_PATH will be set dynamically in install_python_and_venv()
VENV_PATH=""
VENV_SYMLINK_TARGET_PATH=""
# User override options
VENV_PATH_OVERRIDE=""
VENV_SYMLINK_TARGET_PATH_OVERRIDE=""

# Properties file path
VERSION_FILE="$PROJECT_ROOT/compiler.properties"

# Read 'COM_VERSION', 'COM_DOWNLOAD_URL' from properties file
if [[ -f "$VERSION_FILE" ]]; then
    print_colored "Loading versions and download URLs from '$VERSION_FILE'..." "INFO"
    source "$VERSION_FILE"
else
    print_colored "Version file '$VERSION_FILE' not found." "ERROR"
    popd >&2
    exit 1
fi

# Function to display help message
show_help() {
    echo -e "Usage: ${COLOR_CYAN}$(basename "$0") [--username=<user>] [--password=<pass>] [OPTIONS]${COLOR_RESET}"
    echo -e ""
    echo -e "Options:"
    echo -e "  ${COLOR_GREEN}[--username=<user>]${COLOR_RESET}                   Your DEEPX Portal username/email."
    echo -e "  ${COLOR_GREEN}[--password=<pass>]${COLOR_RESET}                   Your DEEPX Portal password."
    echo -e "  ${COLOR_GREEN}[--archive_mode=<y|n>]${COLOR_RESET}                Set archive mode (default: n)."
    echo -e ""
    echo -e "  ${COLOR_GREEN}[--docker_volume_path=<path>]${COLOR_RESET}         Set Docker volume path (required in container mode)"
    echo -e ""
    echo -e "  ${COLOR_GREEN}[--venv_path=<path>]${COLOR_RESET}                  Set virtual environment path (default: PROJECT_ROOT/venv-${PROJECT_NAME})"
    echo -e "  ${COLOR_GREEN}[--venv_symlink_target_path=<dir>]${COLOR_RESET}    Set symlink target path for venv (ex: PROJECT_ROOT/../workspace/venv/${PROJECT_NAME})"
    echo -e ""
    echo -e "  ${COLOR_GREEN}[--system-site-packages]${COLOR_RESET}              Set venv '--system-site-packages' option."    
    echo -e "                                          - This option is applied only when venv is created. If you use '-venv-reuse', it is ignored. "
    echo -e ""
    echo -e "  ${COLOR_GREEN}[-f | --venv-force-remove]${COLOR_RESET}            If specified, force remove existing virtual environment at --venv_path before creation."
    echo -e "  ${COLOR_GREEN}[-r | --venv-reuse]${COLOR_RESET}                   If specified, reuse existing virtual environment at --venv_path if it's valid, skipping creation."
    echo -e ""
    echo -e "  ${COLOR_GREEN}[--force]${COLOR_RESET}                             Force overwrite if the file already exists"
    echo -e "                                          - This option is applied. --venv-force-remove option is enabled automatically."
    echo -e ""
    echo -e "  ${COLOR_GREEN}[--verbose]${COLOR_RESET}                           Enable verbose (debug) logging."
    echo -e "  ${COLOR_GREEN}[--help]${COLOR_RESET}                              Display this help message and exit."
    echo -e ""
    echo -e "${COLOR_BOLD}Examples:${COLOR_RESET}"
    echo -e "  export DX_USERNAME=username; export DX_PASSWORD=password; ${COLOR_YELLOW}$0"
    echo -e "  ${COLOR_YELLOW}$0 --username=username --password=password"
    echo -e "  ${COLOR_YELLOW}$0 --docker_volume_path=/path/to/docker/volume${COLOR_RESET}"
    echo -e ""
    echo -e "  ${COLOR_YELLOW}$0 --venv_path=./my_venv # Installs default Python, creates venv${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --venv_path=./existing_venv --venv-reuse # Reuse existing venv${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --venv_path=./old_venv --venv-force-remove # Force remove and recreate venv${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --venv_path=./my_venv --venv_symlink_target_path=/tmp/actual_venv # Create venv at /tmp with symlink${COLOR_RESET}"
    echo -e ""

    if [ "$1" == "error" ] && [[ ! -n "$2" ]]; then
        print_colored_v2 "ERROR" "Invalid or missing arguments."
        popd >&2
        exit 1
    elif [ "$1" == "error" ] && [[ -n "$2" ]]; then
        print_colored_v2 "ERROR" "$2"
        popd >&2
        exit 1
    elif [[ "$1" == "warn" ]] && [[ -n "$2" ]]; then
        print_colored_v2 "WARNING" "$2"
        popd >&2
        return 0
    fi
    popd >&2
    exit 0
}

validate_environment() {
    echo -e "=== validate_environment() ${TAG_START} ==="

    # Handle --venv-force-remove and --venv-reuse conflicts
    if [ ${FORCE_REMOVE_VENV} -eq 1 ] && [ ${REUSE_VENV} -eq 1 ]; then
        show_help "error" "Cannot use both --venv-force-remove and --venv-reuse simultaneously. Please choose one." "ERROR" >&2
    fi

    # --- Determine DEEPX Portal Credentials based on priority ---
    DX_USERNAME_FINAL=""
    DX_PASSWORD_FINAL=""

    if [[ -n "$CLI_USERNAME" ]] && [[ -n "$CLI_PASSWORD" ]]; then
        # 1st priority: Command-line arguments
        DX_USERNAME_FINAL="$CLI_USERNAME"
        DX_PASSWORD_FINAL="$CLI_PASSWORD"
        print_colored "Using DEEPX credentials from command-line arguments." "INFO"
    elif [[ -n "$DX_USERNAME" ]] && [[ -n "$DX_PASSWORD" ]]; then
        # 2nd priority: Environment variables
        DX_USERNAME_FINAL="$DX_USERNAME"
        DX_PASSWORD_FINAL="$DX_PASSWORD"
        print_colored "Using DEEPX credentials from environment variables." "INFO"
    else
        # 3rd priority: Interactive prompt
        print_colored "Please enter your DEEPX Developers' Portal credentials." "INFO"
        read -r -p "Username (email or id): " DX_USERNAME_FINAL
        read -r -s -p "Password: " DX_PASSWORD_FINAL # -s for silent input
        echo "" # Newline after password input
    fi

    # Export final credentials as environment variables for child processes
    export DX_USERNAME="$DX_USERNAME_FINAL"
    export DX_PASSWORD="$DX_PASSWORD_FINAL"

    # Usage check for required properties (must exist in compiler.properties)
    if [ -z "$COM_VERSION" ] || [ -z "$COM_DOWNLOAD_URL" ]; then
        print_colored "COM_VERSION or COM_DOWNLOAD_URL not defined in '$VERSION_FILE'." "ERROR"
        popd >&2
        exit 1
    fi

    echo -e "=== validate_environment() ${TAG_DONE} ==="
}

install_python_and_venv() {
    print_colored "--- Install Python and Create Virtual environment..... ---" "INFO"

    # Check if running in a container and set appropriate paths
    local CONTAINER_MODE=false
    
    # Check if running in a container
    if check_container_mode; then
        CONTAINER_MODE=true
        print_colored_v2 "INFO" "(container mode detected)"

        if [ -z "$DOCKER_VOLUME_PATH" ]; then
            show_help "error" "--docker_volume_path must be provided in container mode."
            exit 1
        fi

        # In container mode, use symlink to docker volume
        VENV_SYMLINK_TARGET_PATH="${DOCKER_VOLUME_PATH}/venv/${PROJECT_NAME}"
        VENV_PATH="${PROJECT_ROOT}/venv-${PROJECT_NAME}"
    else
        print_colored_v2 "INFO" "(host mode detected)"
        # In host mode, use local venv without symlink
        VENV_PATH="${PROJECT_ROOT}/venv-${PROJECT_NAME}-local"
        VENV_SYMLINK_TARGET_PATH=""
    fi

    # Override with user-specified options if provided
    if [ -n "${VENV_PATH_OVERRIDE}" ]; then
        VENV_PATH="${VENV_PATH_OVERRIDE}"
        print_colored_v2 "INFO" "Using user-specified VENV_PATH: ${VENV_PATH}"
    else
        print_colored_v2 "INFO" "Auto-detected VENV_PATH: ${VENV_PATH}"
    fi
    
    if [ -n "${VENV_SYMLINK_TARGET_PATH_OVERRIDE}" ]; then
        VENV_SYMLINK_TARGET_PATH="${VENV_SYMLINK_TARGET_PATH_OVERRIDE}"
        print_colored_v2 "INFO" "Using user-specified VENV_SYMLINK_TARGET_PATH: ${VENV_SYMLINK_TARGET_PATH}"
    elif [ -n "${VENV_SYMLINK_TARGET_PATH}" ]; then
        print_colored_v2 "INFO" "Auto-detected VENV_SYMLINK_TARGET_PATH: ${VENV_SYMLINK_TARGET_PATH}"
    fi

    local install_py_cmd_args=""

    if [ -n "${PYTHON_VERSION}" ]; then
        install_py_cmd_args+=" --python_version=$PYTHON_VERSION"
    fi

    if [ -n "${MIN_PY_VERSION}" ]; then
        install_py_cmd_args+=" --min_py_version=$MIN_PY_VERSION"
    fi

    if [ -n "${VENV_PATH}" ]; then
        install_py_cmd_args+=" --venv_path=$VENV_PATH"
    fi

    if [ -n "${VENV_SYMLINK_TARGET_PATH}" ]; then
        install_py_cmd_args+=" --symlink_target_path=$VENV_SYMLINK_TARGET_PATH"
    fi

    if [ ${USE_FORCE} -eq 1 ] || [ ${FORCE_REMOVE_VENV} -eq 1 ]; then
        install_py_cmd_args+=" --venv-force-remove"
    fi

    if [ ${REUSE_VENV} -eq 1 ]; then
        install_py_cmd_args+=" --venv-reuse"
    fi

    if [ -n "${VENV_SYSTEM_SITE_PACKAGES_ARGS}" ]; then
        install_py_cmd_args+=" ${VENV_SYSTEM_SITE_PACKAGES_ARGS}"
    fi

    # Pass the determined VENV_PATH and new options to install_python_and_venv.sh
    local install_py_cmd="${PROJECT_ROOT}/scripts/install_python_and_venv.sh ${install_py_cmd_args}"
    echo "CMD: ${install_py_cmd}"
    ${install_py_cmd} || {
        print_colored "Failed to Install Python and Create Virtual environment. Exiting." "ERROR"
        exit 1
    }

    print_colored "[OK] Completed to Install Python and Create Virtual environment." "INFO"
}

activate_venv() {
    echo -e "=== activate_venv() ${TAG_START} ==="

    # activate venv
    source ${VENV_PATH}/bin/activate
    if [ $? -ne 0 ]; then
        print_colored_v2 "ERROR" "Activate Virtual environment(${VENV_PATH}) failed! Please try installing again with the '--force' option. "
        print_colored_v2 "HINT" "Please run 'setup.sh --force' to set up and activate the environment first."
        exit 1
    fi

    echo -e "=== activate_venv() ${TAG_DONE} ==="
}

install_python_package() {
    local package_name=$1
    if python3 -c "import $package_name" &> /dev/null; then
        print_colored "Python package '$package_name' is already installed." "INFO"
    else
        print_colored "Python package '$package_name' not found. Installing..." "INFO"
        pip_install_cmd="pip3 install $package_name"
        if ! eval "$pip_install_cmd"; then
            print_colored "ERROR: Failed to install Python package '$package_name'. Please ensure pip3 is installed and accessible, or install it manually." "ERROR"
            popd >&2
            exit 1
        fi
        print_colored "Python package '$package_name' installed successfully." "INFO"
    fi
}

install_pip_packages() {
    # --- Check and Install Python Dependencies ---
    print_colored "Checking for required Python packages (requests, beautifulsoup4)..." "INFO"

    install_python_package "requests"
    install_python_package "bs4" # beautifulsoup4 is imported as bs4

    print_colored "All required Python packages are installed." "INFO"
}

setup_project() {
    echo -e "=== setup_${PROJECT_NAME}() ${TAG_START} ==="

    if check_virtualenv; then
        install_pip_packages
    else
        if [ -d "$VENV_PATH" ]; then
            activate_venv
            install_pip_packages
        else
            print_colored_v2 "ERROR" "Virtual environment '${VENV_PATH}' is not exist."
            popd >&2
            exit 1
        fi
    fi

    echo -e "=== setup_${PROJECT_NAME}() ${TAG_DONE} ==="
}

install_dx_com() {
    echo -e "=== install_dx_com() ${TAG_START} ==="

    # Check if archive mode is enabled
    if [ "$ARCHIVE_MODE" = "y" ]; then
        print_colored "ARCHIVE_MODE is ON." "INFO"
        ARCHIVE_MODE_ARGS="--archive_mode=y" # Pass this to install_module.sh
    fi

    # Install dx-com
    print_colored "Installing dx-com (Version: $COM_VERSION)..." "INFO"
    # Pass all relevant args to install_module.sh
    INSTALL_COM_CMD="$PROJECT_ROOT/scripts/install_module.sh --module_name=dx_com --version=$COM_VERSION --download_url=$COM_DOWNLOAD_URL $ARCHIVE_MODE_ARGS $FORCE_ARGS $VERBOSE_ARGS"
    print_colored "Executing: $INSTALL_COM_CMD" "DEBUG" # Debug line
    $INSTALL_COM_CMD
    if [ $? -ne 0 ]; then
        print_colored "Installing dx-com failed!" "ERROR"
        popd >&2
        exit 1
    fi

    echo -e "=== install_dx_com() ${TAG_DONE} ==="
}



main() {
    validate_environment
    install_python_and_venv
    setup_project
    install_dx_com

    print_colored "All installations completed successfully." "INFO"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --username=*)
            CLI_USERNAME="${1#*=}"
            ;;
        --password=*)
            CLI_PASSWORD="${1#*=}"
            ;;
        --archive_mode=*)
            ARCHIVE_MODE="${1#*=}"
            ;;
        --docker_volume_path=*)
            DOCKER_VOLUME_PATH="${1#*=}"
            ;;
        --venv_path=*)
            VENV_PATH_OVERRIDE="${1#*=}"
            ;;
        --venv_symlink_target_path=*)
            VENV_SYMLINK_TARGET_PATH_OVERRIDE="${1#*=}"
            ;;
        -f|--venv-force-remove)
            FORCE_REMOVE_VENV=1
            REUSE_VENV=0
            ;;
        -r|--venv-reuse)
            REUSE_VENV=1
            ;;
        --system-site-packages)
            VENV_SYSTEM_SITE_PACKAGES_ARGS="--system-site-packages"
            ;;
        --force)
            USE_FORCE=1
            FORCE_REMOVE_VENV=1
            REUSE_VENV=0
            FORCE_ARGS="--force"
            ;;
        --verbose)
            ENABLE_DEBUG_LOGS=1
            VERBOSE_ARGS="--verbose"
            ;;
        --help)
            show_help
            ;;
        *)
            show_help "error" "Unknown option: $1"
            ;;
    esac
    shift
done

main

popd >&2
exit 0
