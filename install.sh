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
ARCHIVE_MODE="n"
FORCE_ARGS="--force"
VERBOSE_ARGS=""
ENABLE_DEBUG_LOGS=0   # New flag for debug logging
DOCKER_VOLUME_PATH=${DOCKER_VOLUME_PATH}
USE_FORCE=1
REUSE_VENV=0
FORCE_REMOVE_VENV=1
VENV_SYSTEM_SITE_PACKAGES_ARGS=""
USE_PYPI=1

# Global variables for script configuration
PYTHON_VERSION=""
MIN_PY_VERSION="3.8.0"
# Python version compatibility settings
# Supported Python versions list (space-separated)
SUPPORTED_PYTHON_VERSIONS="3.8 3.9 3.10 3.11 3.12 3.13 3.14"
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
DX_TRON_WEB_ONLY=0

# Properties file path
VERSION_FILE="$PROJECT_ROOT/compiler.properties"

# Read version properties from file
if [[ -f "$VERSION_FILE" ]]; then
    print_colored "Loading version properties from '$VERSION_FILE'..." "INFO"
    source "$VERSION_FILE"
else
    print_colored "Version file '$VERSION_FILE' not found." "ERROR"
    popd >&2
    exit 1
fi

# Function to display help message
show_help() {
    echo -e "Usage: ${COLOR_CYAN}$(basename "$0") [OPTIONS]${COLOR_RESET}"
    echo -e ""
    echo -e "Options:"
    echo -e "  ${COLOR_GREEN}[--target=<module_name>]${COLOR_RESET}              Install specific module (dx_com | dx_tron | all) (default: all)"
    echo -e "  ${COLOR_GREEN}[--archive_mode=<y|n>]${COLOR_RESET}                Set archive mode (default: n)."
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
    echo -e "  ${COLOR_YELLOW}${0}${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --target=all${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --target=dx_com${COLOR_RESET}"
    echo -e "  ${COLOR_YELLOW}$0 --target=dx_tron${COLOR_RESET}"
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

    # Usage check for required properties (must exist in compiler.properties)
    # Check COM_VERSION
    if [ -z "$COM_VERSION" ]; then
        print_colored "COM_VERSION not defined in '$VERSION_FILE'." "ERROR"
        popd >&2
        exit 1
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

# Installs the OS default Python 3 using the system package manager
# (apt for Debian/Ubuntu, dnf for the Red Hat family). No specific version is
# requested, so whatever python3 the OS ships with is installed.
install_os_default_python3() {
    local OS_ID=""
    local OS_VERSION_ID=""
    if [ -f /etc/os-release ]; then
        OS_ID=$(grep "^ID=" /etc/os-release | sed 's/^ID=//' | tr -d '"')
        OS_VERSION_ID=$(grep "^VERSION_ID=" /etc/os-release | sed 's/^VERSION_ID=//' | tr -d '"')
    fi

    print_colored "Installing the OS default Python 3..." "INFO"

    # Normalize ID_LIKE derivatives (e.g. Oracle Linux ID=ol, ID_LIKE="rhel
    # fedora") to a supported family, matching os_check()/install_prerequisites.sh;
    # otherwise they pass os_arch_check but fall through to the unsupported '*)'
    # branch here.
    case "$OS_ID" in
        ubuntu|debian|fedora|rhel|centos)
            ;;
        *)
            if grep -qE 'ID_LIKE=.*(rhel|fedora|centos)' /etc/os-release 2>/dev/null; then
                OS_ID="rhel"
            elif grep -qE 'ID_LIKE=.*(debian|ubuntu)' /etc/os-release 2>/dev/null; then
                OS_ID="debian"
            fi
            ;;
    esac

    case "$OS_ID" in
        ubuntu|debian)
            sudo apt-get update
            sudo env DEBIAN_FRONTEND=noninteractive apt-get install -y tzdata
            sudo apt-get install -y python3 python3-venv python3-dev
            ;;
        fedora|rhel|centos)
            # On Fedora, check whether the default python3 package maps to an
            # unsupported version before installing it.  Fedora 45 ships
            # python3.15 as its default, which is not yet in SUPPORTED_PYTHON_VERSIONS.
            # In that case, emit an INFO notice and install the latest supported
            # Python version instead so the rest of the install can proceed.
            local DEFAULT_FEDORA_PY_VER=""
            if [ "$OS_ID" = "fedora" ]; then
                # Resolve the version that 'python3' would pull in without installing.
                DEFAULT_FEDORA_PY_VER=$(dnf repoquery --quiet --qf '%{version}' python3 2>/dev/null \
                    | grep -E '^[0-9]+\.[0-9]+' | sort -V | tail -1)
                # Strip patch component if present (e.g. "3.15.0" -> "3.15").
                DEFAULT_FEDORA_PY_VER="${DEFAULT_FEDORA_PY_VER%.*}"
            fi

            local IS_DEFAULT_SUPPORTED=false
            if [ -n "$DEFAULT_FEDORA_PY_VER" ]; then
                for _sv in $SUPPORTED_PYTHON_VERSIONS; do
                    if [ "$DEFAULT_FEDORA_PY_VER" = "$_sv" ]; then
                        IS_DEFAULT_SUPPORTED=true
                        break
                    fi
                done
            else
                # Could not probe: assume it's fine and let the post-install
                # version check below catch any mismatch.
                IS_DEFAULT_SUPPORTED=true
            fi

            if [ "$IS_DEFAULT_SUPPORTED" = false ]; then
                # Determine the latest entry in SUPPORTED_PYTHON_VERSIONS.
                local LATEST_SUPPORTED_PY=""
                for _sv in $SUPPORTED_PYTHON_VERSIONS; do
                    LATEST_SUPPORTED_PY="$_sv"
                done
                print_colored "Fedora ${OS_VERSION_ID:-} OS Default python3 version is ${DEFAULT_FEDORA_PY_VER} which is not supported. Installing python${LATEST_SUPPORTED_PY}." "INFO"
                PYTHON_VERSION="$LATEST_SUPPORTED_PY"
                # Return early: install_python_and_venv() will handle the
                # actual installation of the chosen version via its normal path.
                echo -e "=== install_os_default_python3() redirected to python${LATEST_SUPPORTED_PY} ==="
                return 0
            fi

            sudo dnf install -y python3 python3-devel
            ;;
        *)
            print_colored "Unsupported OS '${OS_ID}' for automatic Python installation. Please install Python 3 manually." "ERROR"
            popd >&2
            exit 1
            ;;
    esac

    if ! command -v python3 >/dev/null 2>&1; then
        print_colored "Failed to install the OS default Python 3. Exiting." "ERROR"
        popd >&2
        exit 1
    fi

    local INSTALLED_PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)
    print_colored "[OK] Installed OS default Python ${INSTALLED_PY_VERSION}." "INFO"
}

check_python_version_compatibility() {
    echo -e "=== check_python_version_compatibility() ${TAG_START} ==="

    # In container mode --docker_volume_path is required. Validate up front so we
    # fail fast before the Python install prompt below. install_python_and_venv()
    # re-validates for the dx_tron path which skips this function.
    if check_container_mode && [ -z "$DOCKER_VOLUME_PATH" ]; then
        show_help "error" "--docker_volume_path must be provided in container mode."
        exit 1
    fi

    # Get current Python version
    local CURRENT_PY_VERSION=$(python3 -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null)

    if [ -z "$CURRENT_PY_VERSION" ]; then
        local SUPPORTED_VERSIONS=$(echo "$SUPPORTED_PYTHON_VERSIONS" | sed 's/ /, /g')
        echo ""
        print_colored_v2 "WARNING" "===================================================================="
        print_colored_v2 "WARNING" "  Python 3 is not installed or could not be detected."
        print_colored_v2 "WARNING" "  Supported Python versions: ${SUPPORTED_VERSIONS}"
        print_colored_v2 "WARNING" "===================================================================="
        echo ""

        # If a Python version was explicitly requested via --python_version, skip
        # the interactive prompts entirely and let install_python_and_venv.sh
        # install the requested version.
        if [ -n "$PYTHON_VERSION" ]; then
            print_colored "Installing user-specified Python ${PYTHON_VERSION} (interactive prompts skipped)." "INFO"
            echo -e "=== check_python_version_compatibility() ${TAG_DONE} ==="
            return 0
        fi

        # Prompt 1: whether to install Python 3 at all.
        print_colored "Do you want to install Python 3? (y/n)" "WARNING"
        print_colored "(Will proceed with installation on the OS default Python 3 in 10 seconds if no response)" "WARNING"

        local USER_RESPONSE=""
        if read -t 10 -r USER_RESPONSE; then
            # An empty response (bare Enter) means "use the default", matching the
            # prompt's promise to proceed on the OS default Python 3. Only an
            # explicit non-yes answer (e.g. n) aborts.
            if [ -n "$USER_RESPONSE" ] && [[ ! "$USER_RESPONSE" =~ ^[Yy]$ ]]; then
                print_colored "Installation aborted by user." "ERROR"
                popd >&2
                exit 1
            fi

            # Prompt 2: which Python version to install.
            echo ""
            print_colored "Please enter the Python version you want to install (e.g., 3.11, 3.12):" "INFO"
            print_colored "Supported versions: ${SUPPORTED_VERSIONS}" "INFO"
            print_colored "(Will proceed with installation on the OS default Python 3 in 10 seconds if no response)" "WARNING"

            local CHOSEN_PY_VERSION=""
            if read -t 10 -r CHOSEN_PY_VERSION && [ -n "$CHOSEN_PY_VERSION" ]; then
                # Reject versions that are not in the supported list.
                local CHOSEN_IS_SUPPORTED=false
                for supported_ver in $SUPPORTED_PYTHON_VERSIONS; do
                    if [ "$CHOSEN_PY_VERSION" = "$supported_ver" ]; then
                        CHOSEN_IS_SUPPORTED=true
                        break
                    fi
                done
                if [ "$CHOSEN_IS_SUPPORTED" = false ]; then
                    echo ""
                    print_colored_v2 "ERROR" "===================================================================="
                    print_colored_v2 "ERROR" "  Unsupported Python version entered: ${CHOSEN_PY_VERSION}"
                    print_colored_v2 "ERROR" "  Supported Python versions: ${SUPPORTED_VERSIONS}"
                    print_colored_v2 "ERROR" "  Aborting installation."
                    print_colored_v2 "ERROR" "===================================================================="
                    echo ""
                    popd >&2
                    exit 1
                fi
                PYTHON_VERSION="$CHOSEN_PY_VERSION"
                print_colored "Will install user-selected Python ${PYTHON_VERSION}." "INFO"
                echo -e "=== check_python_version_compatibility() ${TAG_DONE} ==="
                return 0
            fi

            echo ""
            print_colored "No version entered. Proceeding with the OS default Python 3." "INFO"
        else
            echo ""
            print_colored "No response received within 10 seconds. Proceeding with the OS default Python 3." "INFO"
        fi

        install_os_default_python3
        echo -e "=== check_python_version_compatibility() ${TAG_DONE} ==="
        return 0
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

    # Detected version is not in the supported list.
    local SUPPORTED_VERSIONS=$(echo "$SUPPORTED_PYTHON_VERSIONS" | sed 's/ /, /g')

    # Enforce the lower bound (MIN_PY_VERSION). The upper bound of the supported
    # list is relaxed (newer-than-supported versions only warn and continue), but
    # versions older than MIN_PY_VERSION are not usable and must abort here to
    # avoid opaque failures in later dx-com install/runtime steps.
    local MIN_PY_MAJOR="${MIN_PY_VERSION%%.*}"
    local MIN_PY_MINOR=$(echo "$MIN_PY_VERSION" | cut -d. -f2)
    local CUR_PY_MAJOR="${CURRENT_PY_VERSION%%.*}"
    local CUR_PY_MINOR=$(echo "$CURRENT_PY_VERSION" | cut -d. -f2)

    if [ "$CUR_PY_MAJOR" -lt "$MIN_PY_MAJOR" ] || { [ "$CUR_PY_MAJOR" -eq "$MIN_PY_MAJOR" ] && [ "$CUR_PY_MINOR" -lt "$MIN_PY_MINOR" ]; }; then
        echo ""
        print_colored_v2 "ERROR" "===================================================================="
        print_colored_v2 "ERROR" "  Python version compatibility check failed!"
        print_colored_v2 "ERROR" "  Detected Python version: ${CURRENT_PY_VERSION}"
        print_colored_v2 "ERROR" "  Minimum required Python version: ${MIN_PY_VERSION}"
        print_colored_v2 "ERROR" "  Supported Python versions: ${SUPPORTED_VERSIONS}"
        print_colored_v2 "ERROR" "  Aborting: the detected Python version is too old to continue."
        print_colored_v2 "ERROR" "===================================================================="
        echo ""
        popd >&2
        exit 1
    fi

    # Version is at or above the minimum but not in the supported list (e.g.
    # python3.15 on Fedora 45). If no explicit --python_version was given, redirect
    # to the latest supported version so the installer does not silently use an
    # untested interpreter.  When the user has explicitly pinned a version via
    # --python_version we honour that choice and only warn.
    if [ -n "$PYTHON_VERSION" ]; then
        # Explicit user request: warn but respect it.
        echo ""
        print_colored_v2 "WARNING" "===================================================================="
        print_colored_v2 "WARNING" "  Detected Python version is newer than the supported list."
        print_colored_v2 "WARNING" "  Detected Python version: ${CURRENT_PY_VERSION}"
        print_colored_v2 "WARNING" "  Supported Python versions: ${SUPPORTED_VERSIONS}"
        print_colored_v2 "WARNING" "  Proceeding with user-specified Python ${PYTHON_VERSION}."
        print_colored_v2 "WARNING" "===================================================================="
        echo ""
    else
        # No explicit request: redirect to the latest supported version.
        local LATEST_SUPPORTED_PY=""
        for _sv in $SUPPORTED_PYTHON_VERSIONS; do
            LATEST_SUPPORTED_PY="$_sv"
        done
        echo ""
        print_colored_v2 "WARNING" "===================================================================="
        print_colored_v2 "WARNING" "  Detected Python version is newer than the supported list."
        print_colored_v2 "WARNING" "  Detected Python version: ${CURRENT_PY_VERSION}"
        print_colored_v2 "WARNING" "  Supported Python versions: ${SUPPORTED_VERSIONS}"
        print_colored_v2 "WARNING" "  Redirecting to Python ${LATEST_SUPPORTED_PY} (latest supported)."
        print_colored_v2 "WARNING" "===================================================================="
        echo ""
        PYTHON_VERSION="$LATEST_SUPPORTED_PY"
    fi

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

download_sample_data() {
    echo ""
    echo -e "=== download_sample_data() ${TAG_START} ==="
    print_colored_v2 "INFO" "Running sample data download steps..."

    local EXAMPLE_DIR="${PROJECT_ROOT}/example"

    echo ""
    print_colored_v2 "INFO" "[1/2] Downloading sample models..."
    "${EXAMPLE_DIR}/1-download_sample_models.sh"
    if [ $? -ne 0 ]; then
        print_colored_v2 "WARNING" "Sample model download failed. You can run it manually:"
        print_colored_v2 "HINT"    "  ${EXAMPLE_DIR}/1-download_sample_models.sh"
    fi

    echo ""
    print_colored_v2 "INFO" "[2/2] Downloading sample calibration dataset..."
    "${EXAMPLE_DIR}/2-download_sample_calibration_dataset.sh"
    if [ $? -ne 0 ]; then
        print_colored_v2 "WARNING" "Calibration dataset download failed. You can run it manually:"
        print_colored_v2 "HINT"    "  ${EXAMPLE_DIR}/2-download_sample_calibration_dataset.sh"
    fi

    echo ""
    echo -e "=== download_sample_data() ${TAG_DONE} ==="
}

show_installation_complete_message() {
    if [ "$ARCHIVE_MODE" != "y" ]; then
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
            if [ $DX_TRON_WEB_ONLY -eq 1 ]; then
                print_colored_v2 "HINT" "  dxtron (CLI/desktop) is supported only on Debian/Ubuntu family."
                print_colored_v2 "HINT" "  On Red Hat family (Fedora/RHEL/CentOS), only the web variant is installed."
                print_colored_v2 "HINT" ""
                print_colored_v2 "HINT" "  To start the dxtron web server:"
                print_colored_v2 "HINT" "    $ ./run_dxtron_web.sh --port=8080"
                print_colored_v2 "HINT" ""
            else
                print_colored_v2 "HINT" "  To run dxtron (no virtual environment required):"
                print_colored_v2 "HINT" "    $ dxtron"
                print_colored_v2 "HINT" ""
                print_colored_v2 "HINT" "  Or use the convenience script to start the web server:"
                print_colored_v2 "HINT" "    $ ./run_dxtron_web.sh --port=8080"
                print_colored_v2 "HINT" ""
                print_colored_v2 "HINT" "  Note: the 'dxtron' CLI/desktop binary is supported only on Debian/Ubuntu family."
                print_colored_v2 "HINT" ""
            fi
        fi

        print_colored_v2 "HINT" "===================================================================="
        echo ""
    fi
}

install_dx_com() {
    echo -e "=== install_dx_com() ${TAG_START} ==="

    local DX_AS_PATH
    DX_AS_PATH=$(realpath -s "${PROJECT_ROOT}/..")

    # Detect Python version tag for onnxruntime workaround
    local PYTHON_VERSION_TAG=""
    if [ -n "$PYTHON_VERSION" ]; then
        PYTHON_VERSION_TAG="cp${PYTHON_VERSION//./}"
    else
        PYTHON_VERSION_TAG=$(python3 -c "import sys; print(f'cp{sys.version_info.major}{sys.version_info.minor}')" 2>/dev/null)
        if [ -z "$PYTHON_VERSION_TAG" ]; then
            print_colored "Failed to detect Python version." "ERROR"
            popd >&2
            exit 1
        fi
    fi
    if [ -n "$PYTHON_VERSION" ]; then
        print_colored "Using user-specified Python version tag: ${PYTHON_VERSION_TAG}" "INFO"
    else
        print_colored "Detected Python version tag: ${PYTHON_VERSION_TAG}" "INFO"
    fi

    # Archive mode: download wheel to DX_AS_PATH/archives without installing
    if [ "$ARCHIVE_MODE" = "y" ]; then
        local ARCHIVE_DIR="${DX_AS_PATH}/archives"
        mkdir -p "$ARCHIVE_DIR"
        print_colored "ARCHIVE_MODE is ON. Downloading dx-com to ${ARCHIVE_DIR}..." "INFO"

        local PIP_DOWNLOAD_ARGS=(
            "--dest" "$ARCHIVE_DIR"
            "--no-deps"
            "--only-binary=:all:"
            "--python-version" "${PYTHON_VERSION_TAG#cp}"
        )

        local ARCHIVED_COM_FILE
        if [ "$USE_PYPI" -eq 1 ]; then
            # PyPI: download the latest dx-com (no version pin).
            pip download "${PIP_DOWNLOAD_ARGS[@]}" "dx-com" || { print_colored "Failed to download dx-com for archiving." "ERROR"; popd >&2; exit 1; }
            # Match the Python tag: archives/ may hold stale wheels for other
            # Python versions from prior runs, and picking the wrong tag bakes a
            # mismatched wheel into the image (forcing an in-container Python rebuild).
            ARCHIVED_COM_FILE=$(find "$ARCHIVE_DIR" -name "dx_com-*-${PYTHON_VERSION_TAG}-*.whl" -type f | head -1)
        else
            local COM_FIND_LINKS="https://sdk.deepx.ai/release/dxcom/v${COM_VERSION}/index.html"
            # DEEPX release index: pin the exact version from compiler.properties.
            # --no-index disables PyPI so that only the DEEPX find-links source is used.
            # Safe here because PIP_DOWNLOAD_ARGS includes --no-deps (no transitive deps to resolve).
            pip download "${PIP_DOWNLOAD_ARGS[@]}" "dx-com==${COM_VERSION}" --no-index -f "$COM_FIND_LINKS" || { print_colored "Failed to download dx-com for archiving." "ERROR"; popd >&2; exit 1; }
            # Pin both version and Python tag: archives/ may hold stale wheels for
            # other Python versions from prior runs, and picking the wrong tag bakes
            # a mismatched wheel into the image (forcing an in-container Python rebuild).
            ARCHIVED_COM_FILE=$(find "$ARCHIVE_DIR" -name "dx_com-${COM_VERSION}-${PYTHON_VERSION_TAG}-*.whl" -type f | head -1)
        fi
        if [ -n "$ARCHIVED_COM_FILE" ] && [ -n "$ARCHIVE_OUTPUT_FILE" ]; then
            echo "ARCHIVED_COM_FILE=${ARCHIVED_COM_FILE}" >> "$ARCHIVE_OUTPUT_FILE"
        fi
        print_colored "dx-com archived: ${ARCHIVED_COM_FILE}" "INFO"
        if [ -z "$ARCHIVED_COM_FILE" ]; then
            print_colored "Warning: Downloaded wheel not found in ${ARCHIVE_DIR}. Archive registration skipped." "WARNING"
        fi

        echo -e "=== install_dx_com() ${TAG_DONE} ==="
        DX_COM_INSTALLED=1
        return
    fi

    # For Python 3.8, manually install onnxruntime 1.18.0 from direct URL (PyPI doesn't support it)
    if [ "${PYTHON_VERSION_TAG}" = "cp38" ]; then
        print_colored "Python 3.8 detected: Upgrading pip and installing onnxruntime 1.18.0 from direct URL..." "INFO"
        pip install --upgrade pip || print_colored "Warning: Failed to upgrade pip. Continuing..." "WARNING"
        if pip install https://files.pythonhosted.org/packages/1b/74/02cb1f6fcbadc094c98c49aff8571e7c576bdb4015c01507c385285b5bed/onnxruntime-1.18.0-cp38-cp38-manylinux_2_27_x86_64.manylinux_2_28_x86_64.whl; then
            print_colored "onnxruntime 1.18.0 installed successfully for Python 3.8!" "INFO"
        else
            print_colored "Failed to install onnxruntime 1.18.0 for Python 3.8." "ERROR"
            popd >&2
            exit 1
        fi
    fi

    # Install dx-com via pip
    if [ "$USE_PYPI" -eq 1 ]; then
        # PyPI path installs the latest published dx-com (no version pin), so
        # COM_VERSION from compiler.properties does not apply here.
        print_colored "Installing dx-com (latest from PyPI)..." "INFO"
    else
        print_colored "Installing dx-com (Version: $COM_VERSION)..." "INFO"
    fi

    # If force mode is enabled, uninstall existing dx-com first
    if [ -n "$FORCE_ARGS" ]; then
        print_colored "Force mode: uninstalling existing dx-com before reinstall..." "INFO"
        pip uninstall -y dx-com 2>/dev/null || true
    fi

    if [ "$USE_PYPI" -eq 1 ]; then
        print_colored "Installing dx-com from PyPI..." "INFO"
        if pip install "dx-com"; then
            print_colored "dx-com installed successfully from PyPI!" "INFO"
        else
            print_colored "Failed to install dx-com from PyPI." "ERROR"
            popd >&2
            exit 1
        fi
    else
        local COM_FIND_LINKS="https://sdk.deepx.ai/release/dxcom/v${COM_VERSION}/index.html"
        print_colored "Installing dx-com from ${COM_FIND_LINKS}..." "INFO"
        if pip install "dx-com==${COM_VERSION}" -f "$COM_FIND_LINKS"; then
            print_colored "dx-com installed successfully!" "INFO"
        else
            print_colored "Failed to install dx-com." "ERROR"
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

    # --- Package Installation (Non-archive mode only) ---
    if [ "$ARCHIVE_MODE" != "y" ]; then
        local DX_TRON_DIR="${PROJECT_ROOT}/dx_tron"
        
        # Detect OS family to determine package format
        local INSTALL_OS_ID=""
        local INSTALL_OS_FAMILY="debian"  # default: Debian/Ubuntu DEB path
        if [ -f /etc/os-release ]; then
            INSTALL_OS_ID=$(grep "^ID=" /etc/os-release | sed 's/^ID=//' | tr -d '"')
        fi
        # Resolve OS family: prefer exact ID match, then fall back to ID_LIKE so
        # that RHEL-family derivatives detected via os_check Pass 2 (e.g. Oracle
        # Linux ID=ol, ID_LIKE=fedora) land in the redhat branch instead of the
        # default DEB path.
        case "$INSTALL_OS_ID" in
            fedora|rhel|centos)
                INSTALL_OS_FAMILY="redhat"
                ;;
            *)
                if grep -qE 'ID_LIKE=.*(fedora|rhel|centos)' /etc/os-release 2>/dev/null; then
                    INSTALL_OS_FAMILY="redhat"
                fi
                ;;
        esac

        case "$INSTALL_OS_FAMILY" in
            redhat)
                # Red Hat family - install web variant only.
                # The 'dxtron' CLI/desktop binary (AppImage) is intentionally NOT
                # installed here: AppImage requires FUSE and is not officially
                # supported on Red Hat family by this installer. The web variant
                # (dxtron_*_web) shipped in the dx_tron tarball is sufficient and
                # can be launched via run_dxtron_web.sh.
                print_colored "INFO: Red Hat family detected - installing dx_tron web variant only." "INFO"
                print_colored "INFO: (dxtron CLI/desktop AppImage is supported only on Debian/Ubuntu family.)" "INFO"

                # Verify the web variant exists in the extracted tarball.
                local WEB_DIR=$(find -L "${DX_TRON_DIR}" -name "*_web" -print -quit 2>/dev/null)
                if [ -z "$WEB_DIR" ]; then
                    # Also accept a file named *_web (in case packaging changes)
                    WEB_DIR=$(find -L "${DX_TRON_DIR}" -name "*_web*" -print -quit 2>/dev/null)
                fi
                if [ -z "$WEB_DIR" ]; then
                    print_colored "ERROR: dx_tron web variant not found under '${DX_TRON_DIR}'." "ERROR"
                    popd >&2
                    exit 1
                fi
                print_colored "INFO: Found dx_tron web variant: $(basename "$WEB_DIR")" "INFO"

                DX_TRON_WEB_ONLY=1
                ;;
            debian)
                # Debian/Ubuntu family - use DEB packages
                local ARCH=$(uname -m)
                case "$ARCH" in
                    x86_64) ARCH="amd64" ;;
                    aarch64) ARCH="arm64" ;;
                    armv7l) ARCH="armhf" ;;
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
                ;;
        esac
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
    local fedora_versions=""
    local rhel_versions=""
    local centos_versions=""
    local supported_arch_names=""
    local os_check_error_message=""
    local arch_check_error_message=""

    local os_check_hint_message="For other OS versions, please refer to the manual installation guide at https://github.com/DEEPX-AI/dx-compiler/blob/main/source/docs/02_01_System_Requirements_of_DX-COM.md"
    local arch_check_hint_message="For other architectures, please refer to the manual installation guide at https://github.com/DEEPX-AI/dx-compiler/blob/main/source/docs/02_01_System_Requirements_of_DX-COM.md"

    if [ "$target" == "dx_com" ]; then
        os_names="ubuntu fedora rhel centos"
        ubuntu_versions="20.04 22.04 24.04 26.04"
        debian_versions=""
        fedora_versions="42 43 44 45"
        rhel_versions="9 10"
        centos_versions="9 10"
        supported_arch_names="amd64 x86_64"

        os_check_error_message="This installer supports only Ubuntu 20.04, 22.04, 24.04, 26.04 / Fedora 42-45 / RHEL 9-10 / CentOS 9-10."
        arch_check_error_message="This installer supports only x86_64/amd64 architecture."
    elif [ "$target" == "dx_tron" ]; then
        os_names="ubuntu debian fedora rhel centos"
        ubuntu_versions="20.04 22.04 24.04 26.04"
        debian_versions="11 12 13"
        fedora_versions="42 43 44 45"
        rhel_versions="9 10"
        centos_versions="9 10"
        supported_arch_names="amd64 x86_64 arm64 aarch64 armv7l"

        os_check_error_message="This installer supports only Ubuntu 20.04, 22.04, 24.04, 26.04 / Debian 11-13 / Fedora 42-45 / RHEL 9-10 / CentOS 9-10."
        arch_check_error_message="This installer supports only x86_64/amd64 and arm64/aarch64/armv7l architecture."
    else
        print_colored_v2 "ERROR" "$1 is not supported target."
        popd >&2
        exit 1
    fi
    
    # this function is defined in scripts/common_util.sh
    # Usage: os_check "supported_os_names" "ubuntu_versions" "debian_versions" "fedora_versions" "rhel_versions" "centos_versions"
    os_check "$os_names" "$ubuntu_versions" "$debian_versions" "$fedora_versions" "$rhel_versions" "$centos_versions" || {
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
            check_python_version_compatibility
            install_python_and_venv
            setup_project

            install_prerequisites
            install_dx_com
            download_sample_data

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
            install_python_and_venv
            setup_project

            install_dx_tron

            print_colored "[OK] Installing dx-tron completed successfully." "INFO"

            show_installation_complete_message
            ;;
        all)
            print_colored "Installing all compiler modules..." "INFO"
            validate_environment

            # In archive mode, skip OS checks - just download all modules
            # (the target Docker image OS differs from the host OS)
            local WILL_INSTALL_DX_COM=0
            local WILL_INSTALL_DX_TRON=0
            if [ "$ARCHIVE_MODE" = "y" ]; then
                WILL_INSTALL_DX_COM=1
                WILL_INSTALL_DX_TRON=1
            else
                os_arch_check "dx_com" "silent" && WILL_INSTALL_DX_COM=1
                os_arch_check "dx_tron" "silent" && WILL_INSTALL_DX_TRON=1
            fi

            # If neither module is supported, abort before installing Python/venv
            # so we don't leave that as a side effect and falsely report success.
            if [ $WILL_INSTALL_DX_COM -eq 0 ] && [ $WILL_INSTALL_DX_TRON -eq 0 ]; then
                print_colored_v2 "ERROR" "Neither dx-com nor dx-tron is supported on this OS/Architecture. Nothing to install."
                popd >&2
                exit 1
            fi

            # If dx_com will be installed, check Python version compatibility first
            # This ensures venv is created with a compatible Python version for both modules
            if [ $WILL_INSTALL_DX_COM -eq 1 ]; then
                check_python_version_compatibility
            fi

            install_python_and_venv
            setup_project

            if [ $WILL_INSTALL_DX_TRON -eq 1 ]; then
                install_dx_tron
            else
                print_colored_v2 "SKIP" "dx-tron is not supported on this OS/Architecture. Skipping dx-tron installation."
            fi

            if [ $WILL_INSTALL_DX_COM -eq 1 ]; then
                install_prerequisites
                install_dx_com   
                [ $DX_COM_INSTALLED -eq 1 ] && download_sample_data
            else
                print_colored_v2 "SKIP" "dx-com is not supported on this OS/Architecture. Skipping dx-com installation."
            fi
            
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
        --archive_mode=*)
            ARCHIVE_MODE="${1#*=}"
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
        --pypi=*)
            PYPI_VALUE="${1#*=}"
            if [ "$PYPI_VALUE" = "true" ]; then
                USE_PYPI=1
            elif [ "$PYPI_VALUE" = "false" ]; then
                USE_PYPI=0
            else
                show_help "error" "Invalid value for --pypi: '$PYPI_VALUE'. Use 'true' or 'false'."
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
