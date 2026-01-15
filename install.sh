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
LEGACY_MODE="n"
FORCE_ARGS="--force"
VERBOSE_ARGS=""
ENABLE_DEBUG_LOGS=0   # New flag for debug logging
DOCKER_VOLUME_PATH=${DOCKER_VOLUME_PATH}
USE_FORCE=1
REUSE_VENV=0
FORCE_REMOVE_VENV=1
VENV_SYSTEM_SITE_PACKAGES_ARGS=""

# Global variables for script configuration
PYTHON_VERSION=""
MIN_PY_VERSION="3.8.0"
# Python version compatibility settings
# Supported Python versions list (space-separated)
SUPPORTED_PYTHON_VERSIONS="3.8 3.9 3.10 3.11 3.12"
# VENV_PATH and VENV_SYMLINK_TARGET_PATH will be set dynamically in install_python_and_venv()
VENV_PATH=""
VENV_SYMLINK_TARGET_PATH=""
# User override options
VENV_PATH_OVERRIDE=""
VENV_SYMLINK_TARGET_PATH_OVERRIDE=""
# Target package for installation
TARGET_PKG="all"
# Installation status flags
DX_COM_INSTALLED=0
DX_TRON_INSTALLED=0

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
    echo -e "  ${COLOR_GREEN}[--target=<module_name>]${COLOR_RESET}              Install specific module (dx_com | dx_tron | all) (default: all)"
    echo -e "  ${COLOR_GREEN}[--username=<user>]${COLOR_RESET}                   Your DEEPX Portal username/email."
    echo -e "  ${COLOR_GREEN}[--password=<pass>]${COLOR_RESET}                   Your DEEPX Portal password."
    echo -e "                                            ${COLOR_YELLOW}Note: If password contains special characters like '!' or '$',"
    echo -e "                                            use single quotes: --password='pass!word'${COLOR_RESET}"
    echo -e "  ${COLOR_GREEN}[--archive_mode=<y|n>]${COLOR_RESET}                Set archive mode (default: n)."
    echo -e "  ${COLOR_GREEN}[--legacy]${COLOR_RESET}                            Use legacy mode: downloads executable files and extracts them."
    echo -e "                                            (default: No(wheel mode) - downloads Python packages, extracts and installs to venv)"
    echo -e ""
    echo -e "  ${COLOR_GREEN}[--docker_volume_path=<path>]${COLOR_RESET}         Set Docker volume path (required in container mode)"
    echo -e "  ${COLOR_GREEN}[--python_version=<version>]${COLOR_RESET}          Specify Python version to install (e.g., 3.11, 3.12)"
    echo -e ""
    echo -e "  ${COLOR_GREEN}[--verbose]${COLOR_RESET}                           Enable verbose (debug) logging."
    echo -e "  ${COLOR_GREEN}[--force=<true|false>]${COLOR_RESET}                Force reinstall modules (dx_com, dx_tron) even if already installed (default: true)"
    echo -e "  ${COLOR_GREEN}[--help]${COLOR_RESET}                              Display this help message and exit."
    echo -e ""
    echo -e "Virtual Environment Options:"
    echo -e "  ${COLOR_GREEN}[--venv_path=<path>]${COLOR_RESET}                  Set virtual environment path (default: PROJECT_ROOT/venv-${PROJECT_NAME})"
    echo -e "  ${COLOR_GREEN}[--venv_symlink_target_path=<dir>]${COLOR_RESET}    Set symlink target path for venv (ex: PROJECT_ROOT/../workspace/venv/${PROJECT_NAME})"
    echo -e ""
    echo -e "Virtual Environment Sub-Options:"
    echo -e "  ${COLOR_GREEN}  [--system-site-packages]${COLOR_RESET}              Set venv '--system-site-packages' option."
    echo -e "                                            - This option is applied only when venv is created. If you use '-venv-reuse', it is ignored. "
    echo -e "  ${COLOR_GREEN}  [-f | --venv-force-remove]${COLOR_RESET}            (Default ON) Force remove and recreate virtual environment (venv related only)"
    echo -e "  ${COLOR_GREEN}  [-r | --venv-reuse]${COLOR_RESET}                   (Default OFF) Reuse existing virtual environment at --venv_path if it's valid, skipping creation."
    echo -e ""
    echo -e "${COLOR_BOLD}Examples:${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}${COLOR_BOLD}export DX_USERNAME=username; export DX_PASSWORD=password; ${COLOR_RESET}${COLOR_YELLOW}${0}${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}${0}${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --target=all --username=username --password=password${COLOR_RESET}"

    echo -e "  ${COLOR_YELLOW}$0 --target=dx_com --username=username --password=password${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --target=dx_tron --username=username --password=password${COLOR_RESET}"
    echo -e ""
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

    # Debug: Verify credentials are exported (without showing password)
    print_colored "DEBUG: DX_USERNAME exported for child processes: ${DX_USERNAME:+SET}" "DEBUG"
    print_colored "DEBUG: DX_PASSWORD exported for child processes: ${DX_PASSWORD:+SET}" "DEBUG"

    # Usage check for required properties (must exist in compiler.properties)
    # Check COM_VERSION
    if [ -z "$COM_VERSION" ]; then
        print_colored "COM_VERSION not defined in '$VERSION_FILE'." "ERROR"
        popd >&2
        exit 1
    fi

    # Check download URLs based on mode
    if [ "$LEGACY_MODE" = "y" ]; then
        # Legacy mode: check COM_DOWNLOAD_LEGACY_URL
        if [ -z "$COM_DOWNLOAD_LEGACY_URL" ]; then
            print_colored "COM_DOWNLOAD_LEGACY_URL not defined in '$VERSION_FILE' (required for --legacy mode)." "ERROR"
            popd >&2
            exit 1
        fi
    else
        # Wheel mode: check that all COM_CPXX_DOWNLOAD_URLs are defined
        local MISSING_URLS=""
        for py_ver in 38 39 310 311 312; do
            local url_var="COM_CP${py_ver}_DOWNLOAD_URL"
            if [ -z "${!url_var}" ]; then
                MISSING_URLS+=" COM_CP${py_ver}_DOWNLOAD_URL"
            fi
        done
        if [ -n "$MISSING_URLS" ]; then
            print_colored "Missing COM_CPXX_DOWNLOAD_URL(s) in '$VERSION_FILE':${MISSING_URLS}" "ERROR"
            popd >&2
            exit 1
        fi
    fi

    if [ -z "$TRON_VERSION" ] || [ -z "$TRON_DOWNLOAD_URL" ]; then
        print_colored "TRON_VERSION or TRON_DOWNLOAD_URL not defined in '$VERSION_FILE'." "ERROR"
        popd >&2
        exit 1
    fi

    echo -e "=== validate_environment() ${TAG_DONE} ==="
}

install_prerequisites() {
    print_colored "--- Install Prerequisites..... ---" "INFO"

    local install_prerequisites_cmd="${PROJECT_ROOT}/scripts/install_prerequisites.sh"
    echo "CMD: ${install_prerequisites_cmd}"
    ${install_prerequisites_cmd} || {
        print_colored "Failed to Install Prerequisites. Exiting." "ERROR"
        exit 1
    }

    print_colored "[OK] Completed to Install Prerequisites." "INFO"
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

check_python_version_compatibility() {
    echo -e "=== check_python_version_compatibility() ${TAG_START} ==="

    # Get current Python version
    local CURRENT_PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)

    if [ -z "$CURRENT_PY_VERSION" ]; then
        print_colored "ERROR: Failed to detect Python version." "ERROR"
        popd >&2
        exit 1
    fi

    print_colored "Detected Python version: ${CURRENT_PY_VERSION}" "INFO"

    # Check if version is in supported list
    local IS_COMPATIBLE=1
    for supported_ver in $SUPPORTED_PYTHON_VERSIONS; do
        if [ "$CURRENT_PY_VERSION" = "$supported_ver" ]; then
            IS_COMPATIBLE=0
            break
        fi
    done

    if [ $IS_COMPATIBLE -eq 0 ]; then
        print_colored "Python version ${CURRENT_PY_VERSION} is compatible. Proceeding..." "INFO"
        echo -e "=== check_python_version_compatibility() ${TAG_DONE} ==="
        return 0
    fi

    # Version is not compatible
    # Format supported versions list for display
    local SUPPORTED_VERSIONS=$(echo "$SUPPORTED_PYTHON_VERSIONS" | sed 's/ /, /g')

    echo ""
    print_colored_v2 "WARNING" "===================================================================="
    print_colored_v2 "WARNING" "  Python version compatibility check failed!"
    print_colored_v2 "WARNING" "  Detected Python version: ${CURRENT_PY_VERSION}"
    print_colored_v2 "WARNING" "  Supported Python versions: ${SUPPORTED_VERSIONS}"
    print_colored_v2 "WARNING" "===================================================================="
    echo ""

    # Prompt with timeout
    print_colored "Do you want to continue and install a compatible Python version? (y/n)" "WARNING"
    print_colored "(Will abort in 10 seconds if no response)" "WARNING"

    local USER_RESPONSE=""
    if read -t 10 -r USER_RESPONSE; then
        if [[ ! "$USER_RESPONSE" =~ ^[Yy]$ ]]; then
            print_colored "Installation aborted by user." "ERROR"
            popd >&2
            exit 1
        fi
    else
        echo ""
        print_colored "No response received within 10 seconds. Aborting installation." "ERROR"
        popd >&2
        exit 1
    fi

    # Ask for Python version to install
    echo ""
    print_colored "Please enter the Python version you want to install (e.g., 3.11, 3.12):" "INFO"
    print_colored "Supported versions: ${SUPPORTED_VERSIONS}" "INFO"

    local NEW_PY_VERSION=""
    read -r -p "Python version: " NEW_PY_VERSION

    # Validate input - check if version is in supported list
    local VERSION_FOUND=0
    for supported_ver in $SUPPORTED_PYTHON_VERSIONS; do
        if [ "$NEW_PY_VERSION" = "$supported_ver" ]; then
            VERSION_FOUND=1
            break
        fi
    done

    if [ $VERSION_FOUND -eq 0 ]; then
        print_colored "ERROR: Invalid Python version '${NEW_PY_VERSION}'. Supported versions: ${SUPPORTED_VERSIONS}" "ERROR"
        popd >&2
        exit 1
    fi

    # Update PYTHON_VERSION and reinstall Python environment
    PYTHON_VERSION="$NEW_PY_VERSION"
    print_colored "Will install Python ${PYTHON_VERSION}..." "INFO"

    echo -e "=== check_python_version_compatibility() ${TAG_DONE} ==="
}

activate_venv() {
    echo -e "=== activate_venv() ${TAG_START} ==="

    # activate venv
    source ${VENV_PATH}/bin/activate
    if [ $? -ne 0 ]; then
        print_colored_v2 "ERROR" "Activate Virtual environment(${VENV_PATH}) failed! Please try installing again with the '--force' option. "
        print_colored_v2 "HINT" "Please run 'insatll.sh --force' to set up and activate the environment first."
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

show_installation_complete_message() {
    # Only show message for non-legacy mode
    if [ "$LEGACY_MODE" != "y" ] && [ "$ARCHIVE_MODE" != "y" ]; then
        # Combined message for all installations
        local MODULE_NAMES=""
        local COMMAND_NAMES=""

        if [ $DX_COM_INSTALLED -eq 1 ] && [ $DX_TRON_INSTALLED -eq 1 ]; then
            MODULE_NAMES="dx_com and dx_tron"
        elif [ $DX_COM_INSTALLED -eq 1 ]; then
            MODULE_NAMES="dx_com"
        elif [ $DX_TRON_INSTALLED -eq 1 ]; then
            MODULE_NAMES="dx_tron"
        else
            return  # Nothing installed
        fi

        echo ""
        print_colored_v2 "HINT" "===================================================================="
        print_colored_v2 "HINT" "  ${MODULE_NAMES} installation completed!"
        print_colored_v2 "HINT" ""

        if [ $DX_COM_INSTALLED -eq 1 ]; then
            print_colored_v2 "HINT" "  To use dx_com, activate the virtual environment first:"
            print_colored_v2 "HINT" "    $ source ${VENV_PATH}/bin/activate"
            print_colored_v2 "HINT" ""
            print_colored_v2 "HINT" "  Then you can run dxcom:"
            print_colored_v2 "HINT" "    $ dxcom -h"
            print_colored_v2 "HINT" ""
        fi

        if [ $DX_TRON_INSTALLED -eq 1 ]; then
            print_colored_v2 "HINT" "  To run dxtron (no virtual environment required):"
            print_colored_v2 "HINT" "    $ dxtron"
            print_colored_v2 "HINT" ""
            print_colored_v2 "HINT" "  Or use the convenience script to start the web server:"
            print_colored_v2 "HINT" "    $ ./run_dxtron_web.sh --port=8080"
            print_colored_v2 "HINT" ""
        fi

        print_colored_v2 "HINT" "===================================================================="
        echo ""
    fi
}

install_dx_com() {
    echo -e "=== install_dx_com() ${TAG_START} ==="

    # Check if archive mode is enabled
    if [ "$ARCHIVE_MODE" = "y" ]; then
        print_colored "ARCHIVE_MODE is ON." "INFO"
        ARCHIVE_MODE_ARGS="--archive_mode=y" # Pass this to install_module.sh
    fi

    # Select download URL based on legacy mode and Python version
    local SELECTED_COM_URL="$COM_DOWNLOAD_URL"
    if [ "$LEGACY_MODE" = "y" ]; then
        print_colored "LEGACY_MODE is ON." "INFO"
        SELECTED_COM_URL="$COM_DOWNLOAD_LEGACY_URL"
        print_colored "Using legacy download URL: $SELECTED_COM_URL" "INFO"
    else
        # Detect Python version and select appropriate URL
        local PYTHON_VERSION_TAG=""
        if [ -n "$PYTHON_VERSION" ]; then
            # Use user-specified Python version
            PYTHON_VERSION_TAG="cp${PYTHON_VERSION//./}"
            print_colored "Using user-specified Python version: ${PYTHON_VERSION} (${PYTHON_VERSION_TAG})" "INFO"
        else
            # Detect current Python version
            PYTHON_VERSION_TAG=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')" 2>/dev/null)
            if [ -z "$PYTHON_VERSION_TAG" ]; then
                print_colored "ERROR: Failed to detect Python version." "ERROR"
                popd >&2
                exit 1
            fi
            print_colored "Detected Python version tag: ${PYTHON_VERSION_TAG}" "INFO"
        fi

        # Select URL based on Python version
        local VERSION_URL_VAR="COM_${PYTHON_VERSION_TAG^^}_DOWNLOAD_URL"
        local VERSION_SPECIFIC_URL="${!VERSION_URL_VAR}"

        if [ -n "$VERSION_SPECIFIC_URL" ]; then
            SELECTED_COM_URL="$VERSION_SPECIFIC_URL"
            print_colored "Using Python ${PYTHON_VERSION_TAG} specific wheel download URL: $SELECTED_COM_URL" "INFO"
        else
            print_colored "ERROR: No download URL found for Python ${PYTHON_VERSION_TAG}." "ERROR"
            print_colored "Please ensure ${VERSION_URL_VAR} is defined in compiler.properties." "ERROR"
            popd >&2
            exit 1
        fi
    fi

    # Install dx-com
    print_colored "Installing dx-com (Version: $COM_VERSION)..." "INFO"
    # Pass all relevant args to install_module.sh
    INSTALL_COM_CMD="$PROJECT_ROOT/scripts/install_module.sh --module_name=dx_com --version=$COM_VERSION --download_url=$SELECTED_COM_URL $ARCHIVE_MODE_ARGS $FORCE_ARGS $VERBOSE_ARGS"
    print_colored "Executing: $INSTALL_COM_CMD" "DEBUG" # Debug line
    # Use direct execution to properly pass environment variables with real-time output
    COM_OUTPUT_FILE=$(mktemp)
    eval "$INSTALL_COM_CMD" 2>&1 | tee "$COM_OUTPUT_FILE"
    COM_INSTALL_EXIT_CODE=${PIPESTATUS[0]}
    COM_OUTPUT=$(cat "$COM_OUTPUT_FILE")
    rm -f "$COM_OUTPUT_FILE"
    if [ $COM_INSTALL_EXIT_CODE -ne 0 ]; then
        print_colored "Installing dx-com failed!" "ERROR"
        popd >&2
        exit 1
    fi

    # Extract archived file path from output if in archive mode
    if [ "$ARCHIVE_MODE" = "y" ]; then
        ARCHIVED_COM_FILE=$(echo "$COM_OUTPUT" | grep "^ARCHIVED_FILE_PATH=" | tail -1 | cut -d'=' -f2)
        if [ -n "$ARCHIVED_COM_FILE" ] && [ -n "$ARCHIVE_OUTPUT_FILE" ]; then
            echo "ARCHIVED_COM_FILE=${ARCHIVED_COM_FILE}" >> "$ARCHIVE_OUTPUT_FILE"
        fi
    fi

    # --- Wheel Installation (Non-legacy mode only, dx_com only) ---
    if [ "$LEGACY_MODE" != "y" ] && [ "$ARCHIVE_MODE" != "y" ]; then
        print_colored "INFO: Checking for wheel package installation..." "INFO"

        # Determine the dx_com directory (OUTPUT_DIR equivalent)
        local DX_COM_DIR="${PROJECT_ROOT}/dx_com"

        # Get current Python version tag (e.g., cp312, cp311)
        local PYTHON_VERSION_TAG=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')" 2>/dev/null)
        if [ -z "$PYTHON_VERSION_TAG" ]; then
            print_colored "ERROR: Failed to detect Python version." "ERROR"
            popd >&2
            exit 1
        fi
        print_colored "INFO: Detected Python version tag: ${PYTHON_VERSION_TAG}" "INFO"

        # Scan for .whl files matching the current Python version
        local MATCHING_WHEEL=""
        local ALL_WHEEL_FILES=()

        # Collect all wheel files
        for whl_file in "${DX_COM_DIR}"/*.whl; do
            if [ -e "$whl_file" ]; then
                ALL_WHEEL_FILES+=("$whl_file")
                # Check if this wheel matches the current Python version
                if [[ "$(basename "$whl_file")" == *"-${PYTHON_VERSION_TAG}-"* ]]; then
                    MATCHING_WHEEL="$whl_file"
                fi
            fi
        done

        # Check if any wheel files exist
        if [ ${#ALL_WHEEL_FILES[@]} -eq 0 ]; then
            print_colored "ERROR: No wheel file found in '${DX_COM_DIR}'." "ERROR"
            popd >&2
            exit 1
        fi

        # Check if a matching wheel was found
        if [ -z "$MATCHING_WHEEL" ]; then
            print_colored "ERROR: No wheel file compatible with Python ${PYTHON_VERSION_TAG} found in '${DX_COM_DIR}'." "ERROR"
            print_colored "Available wheel files:" "ERROR"
            for whl in "${ALL_WHEEL_FILES[@]}"; do
                print_colored "  - $(basename "$whl")" "ERROR"
            done
            print_colored "Please ensure a wheel file for ${PYTHON_VERSION_TAG} is available." "ERROR"
            popd >&2
            exit 1
        fi

        # Install the matching wheel
        print_colored "INFO: Found compatible wheel file: $(basename "$MATCHING_WHEEL")" "INFO"

        # For Python 3.8, manually install onnxruntime 1.18.0 from direct URL (PyPI doesn't support it)
        # Note: pip upgrade is required to recognize manylinux_2_27/manylinux_2_28 platform tags
        if [ "${PYTHON_VERSION_TAG}" = "cp38" ]; then
            print_colored "INFO: Python 3.8 detected: Upgrading pip and installing onnxruntime 1.18.0 from direct URL..." "INFO"
            pip3 install --upgrade pip
            if pip3 install https://files.pythonhosted.org/packages/1b/74/02cb1f6fcbadc094c98c49aff8571e7c576bdb4015c01507c385285b5bed/onnxruntime-1.18.0-cp38-cp38-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl; then
                print_colored "INFO: onnxruntime 1.18.0 installed successfully for Python 3.8!" "INFO"
            else
                print_colored "ERROR: Failed to install onnxruntime 1.18.0 for Python 3.8." "ERROR"
                popd >&2
                exit 1
            fi
        fi

        print_colored "INFO: Installing wheel package with pip..." "INFO"

        if pip3 install "$MATCHING_WHEEL"; then
            print_colored "INFO: Wheel package installed successfully!" "INFO"
        else
            print_colored "ERROR: Failed to install wheel package '$(basename "$MATCHING_WHEEL")'." "ERROR"
            popd >&2
            exit 1
        fi
    fi

    echo -e "=== install_dx_com() ${TAG_DONE} ==="

    # Set installation flag
    DX_COM_INSTALLED=1
}

install_dx_tron() {
    echo -e "=== install_dx_tron() ${TAG_START} ==="

    # Check if archive mode is enabled
    if [ "$ARCHIVE_MODE" = "y" ]; then
        print_colored "ARCHIVE_MODE is ON." "INFO"
        ARCHIVE_MODE_ARGS="--archive_mode=y" # Pass this to install_module.sh
    fi

    # Install dx-tron
    print_colored "Installing dx-tron (Version: $TRON_VERSION)..." "INFO"
    # Pass all relevant args to install_module.sh
    INSTALL_TRON_CMD="$PROJECT_ROOT/scripts/install_module.sh --module_name=dx_tron --version=$TRON_VERSION --download_url=$TRON_DOWNLOAD_URL $ARCHIVE_MODE_ARGS $FORCE_ARGS $VERBOSE_ARGS"
    print_colored "Executing: $INSTALL_TRON_CMD" "DEBUG" # Debug line
    # Use direct execution to properly pass environment variables with real-time output
    TRON_OUTPUT_FILE=$(mktemp)
    eval "$INSTALL_TRON_CMD" 2>&1 | tee "$TRON_OUTPUT_FILE"
    TRON_INSTALL_EXIT_CODE=${PIPESTATUS[0]}
    TRON_OUTPUT=$(cat "$TRON_OUTPUT_FILE")
    rm -f "$TRON_OUTPUT_FILE"
    if [ $TRON_INSTALL_EXIT_CODE -ne 0 ]; then
        print_colored "Installing dx-tron failed!" "ERROR"
        popd >&2
        exit 1
    fi

    # Extract archived file path from output if in archive mode
    if [ "$ARCHIVE_MODE" = "y" ]; then
        ARCHIVED_TRON_FILE=$(echo "$TRON_OUTPUT" | grep "^ARCHIVED_FILE_PATH=" | tail -1 | cut -d'=' -f2)
        if [ -n "$ARCHIVED_TRON_FILE" ] && [ -n "$ARCHIVE_OUTPUT_FILE" ]; then
            echo "ARCHIVED_TRON_FILE=${ARCHIVED_TRON_FILE}" >> "$ARCHIVE_OUTPUT_FILE"
        fi
    fi

    # --- DEB Package Installation (Non-archive mode only) ---
    if [ "$ARCHIVE_MODE" != "y" ]; then
        local DX_TRON_DIR="${PROJECT_ROOT}/dx_tron"
        
        # Detect architecture and select appropriate deb file
        local ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
        case "$ARCH" in
            amd64|x86_64) ARCH="amd64" ;;
            arm64|aarch64) ARCH="arm64" ;;
        esac
        
        # Use -L to follow symlinks when searching
        local DEB_FILE=$(find -L "${DX_TRON_DIR}" -name "*_${ARCH}.deb" -print -quit 2>/dev/null)
        
        # Fallback to any .deb if architecture-specific not found
        if [ -z "$DEB_FILE" ]; then
            DEB_FILE=$(find -L "${DX_TRON_DIR}" -name "*.deb" -print -quit 2>/dev/null)
        fi

        if [ -n "$DEB_FILE" ] && [ -f "$DEB_FILE" ]; then
            print_colored "INFO: Found DEB package: $(basename "$DEB_FILE")" "INFO"
            print_colored "INFO: Installing DX-Tron DEB package..." "INFO"

            # Update apt and install dependencies, then install deb package
            if sudo apt-get update && sudo apt-get install -y "$DEB_FILE"; then
                print_colored "INFO: DX-Tron DEB package installed successfully!" "INFO"
            else
                print_colored "ERROR: Failed to install DX-Tron DEB package '$(basename "$DEB_FILE")'." "ERROR"
                popd >&2
                exit 1
            fi
        else
            print_colored "ERROR: No DEB package found in '${DX_TRON_DIR}'." "ERROR"
            popd >&2
            exit 1
        fi
    fi

    echo -e "=== install_dx_tron() ${TAG_DONE} ==="

    # Set installation flag
    DX_TRON_INSTALLED=1
}

os_arch_check() {
    local target=$1
    local print_message_mode=$2

    local os_names=""
    local ubuntu_versions=""
    local debian_versions=""
    local supported_arch_names=""
    local os_check_error_message=""
    local arch_check_error_message=""

    local os_check_hint_message="For other OS versions, please refer to the manual installation guide at https://github.com/DEEPX-AI/dx-compiler/blob/main/source/docs/02_01_System_Requirements_of_DX-COM.md"
    local arch_check_hint_message="For other architectures, please refer to the manual installation guide at https://github.com/DEEPX-AI/dx-compiler/blob/main/source/docs/02_01_System_Requirements_of_DX-COM.md"

    if [ "$target" == "dx_com" ]; then
        os_names="ubuntu"
        ubuntu_versions="20.04 22.04 24.04"
        debian_versions=""
        supported_arch_names="amd64 x86_64"

        os_check_error_message="This installer supports only Ubuntu 20.04, 22.04, and 24.04."
        arch_check_error_message="This installer supports only x86_64/amd64 architecture."
    elif [ "$target" == "dx_tron" ]; then
        os_names="ubuntu debian"
        ubuntu_versions="20.04 22.04 24.04"
        debian_versions="11 12 13"
        supported_arch_names="amd64 x86_64 arm64 aarch64 armv7l"

        os_check_error_message="This installer supports only Ubuntu 20.04, 22.04, and 24.04 / Debian 11 12 and 13."
        arch_check_error_message="This installer supports only x86_64/amd64 and arm64/aarch64/armv7l architecture."
    else
        print_colored_v2 "ERROR" "$1 is not supported target."
        popd >&2
        exit 1
    fi
    
    # this function is defined in scripts/common_util.sh
    # Usage: os_check "supported_os_names" "ubuntu_versions" "debian_versions"
    os_check "$os_names" "$ubuntu_versions" "$debian_versions" || {
        if [ "$print_message_mode" == "silent" ] ; then
            return 1
        else
            print_colored_v2 "ERROR" "$os_check_error_message"
            print_colored_v2 "HINT" "$os_check_hint_message"
            return 1
        fi
    }

    # this function is defined in scripts/common_util.sh
    # Usage: arch_check "supported_arch_names"
    arch_check "$supported_arch_names" || {
        if [ "$print_message_mode" == "silent" ] ; then
            return 1
        else
            print_colored_v2 "ERROR" "$arch_check_error_message"
            print_colored_v2 "HINT" "$arch_check_hint_message"
            return 1
        fi
    }
}

main() {
    case $TARGET_PKG in
        dx_com)
            print_colored "Installing dx-com..." "INFO"
            os_arch_check "dx_com" || {
                popd >&2
                exit 1
            }
            validate_environment
            install_prerequisites
            check_python_version_compatibility
            install_python_and_venv
            setup_project
            install_dx_com
            print_colored "[OK] Installing dx-com completed successfully." "INFO"
            show_installation_complete_message
            ;;
        dx_tron)
            print_colored "Installing dx-tron..." "INFO"
            os_arch_check "dx_tron" || {
                popd >&2
                exit 1
            }
            validate_environment
            install_prerequisites
            check_python_version_compatibility
            install_python_and_venv
            setup_project
            install_dx_tron
            print_colored "[OK] Installing dx-tron completed successfully." "INFO"

            show_installation_complete_message
            ;;
        all)
            print_colored "Installing all compiler modules..." "INFO"
            
            validate_environment
            install_prerequisites
            check_python_version_compatibility
            install_python_and_venv
            setup_project
            
            os_arch_check "dx_tron" "silent" && {
                install_dx_tron
            } || {
                print_colored_v2 "SKIP" "dx-tron is not supported on this OS/Architecture. Skipping dx-tron installation."
            }
            
            os_arch_check "dx_com" "silent" && {
                install_dx_com    
            } || {
                print_colored_v2 "SKIP" "dx-com is not supported on this OS/Architecture. Skipping dx-com installation."
            }
            
            print_colored "[OK] Installing all compiler modules completed successfully." "INFO"

            show_installation_complete_message
            ;;
        *)
            show_help "error" "Invalid target '$TARGET_PKG'. Valid targets are: dx_com, dx_tron, all"
            ;;
    esac
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --target=*)
            TARGET_PKG="${1#*=}"
            ;;
        --username=*)
            CLI_USERNAME="${1#*=}"
            ;;
        --password=*)
            CLI_PASSWORD="${1#*=}"
            ;;
        --archive_mode=*)
            ARCHIVE_MODE="${1#*=}"
            ;;
        --legacy)
            LEGACY_MODE="y"
            ;;
        --docker_volume_path=*)
            DOCKER_VOLUME_PATH="${1#*=}"
            ;;
        --python_version=*)
            PYTHON_VERSION="${1#*=}"
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
        --verbose)
            ENABLE_DEBUG_LOGS=1
            VERBOSE_ARGS="--verbose"
            ;;
        --force)
            FORCE_ARGS="--force"
            ;;
        --force=*)
            FORCE_VALUE="${1#*=}"
            if [ "$FORCE_VALUE" = "false" ]; then
                FORCE_ARGS=""
            else
                FORCE_ARGS="--force"
            fi
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
