#!/bin/bash
SCRIPT_DIR=$(realpath "$(dirname "$0")")
COMPILER_PATH=$(realpath -s "${SCRIPT_DIR}")

pushd "$SCRIPT_DIR" || exit 1
# load print_colored()
#   - usage: print_colored "message contents" "type"
#      - types: ERROR FAIL INFO WARNING DEBUG RED BLUE YELLOW GREEN
source "${COMPILER_PATH}/scripts/color_env.sh"
source "${COMPILER_PATH}/scripts/common_util.sh"

# --- Initialize variables for credentials and options ---
CLI_USERNAME=""
CLI_PASSWORD=""
ARCHIVE_MODE="n"
FORCE_ARGS="" # Will be "--force" if --force is passed
VERBOSE_ARGS=""
ENABLE_DEBUG_LOGS=0   # New flag for debug logging

# Properties file path
VERSION_FILE="$SCRIPT_DIR/compiler.properties"

# Read 'COM_VERSION', 'COM_DOWNLOAD_URL' from properties file
if [[ -f "$VERSION_FILE" ]]; then
    print_colored "Loading versions and download URLs from '$VERSION_FILE'..." "INFO"
    source "$VERSION_FILE"
else
    print_colored "Version file '$VERSION_FILE' not found." "ERROR"
    popd || exit 1
    exit 1
fi

# Function to display help message
show_help() {
    print_colored "Usage: $(basename "$0") [--username=<user>] [--password=<pass>]" "YELLOW"
    print_colored "Options:" "GREEN"
    print_colored "  [--username=<user>]            : Your DEEPX Portal username/email." "GREEN"
    print_colored "  [--password=<pass>]            : Your DEEPX Portal password." "GREEN"
    print_colored "  [--archive_mode=<y|n>]         : Set archive mode (default: n)." "GREEN"
    print_colored "  [--force]                      : Force overwrite if the file already exists." "GREEN"
    print_colored "  [--verbose]                    : Enable verbose (debug) logging." "GREEN"
    print_colored "  [--help]                       : Show this help message." "GREEN"

    if [ "$1" == "error" ] && [[ -n "$2" ]]; then
        print_colored "ERROR: $2" "ERROR"
        popd || exit 1
        exit 1
    fi
    # Only exit if not an error, allowing script to continue if help is just part of args
    # For --help, we always exit after showing help.
    popd || exit 1
    exit 0
}


# --- Parse all command-line arguments in a single loop ---
while [[ $# -gt 0 ]]; do
    case "$1" in
        --username=*)
            CLI_USERNAME="${1#*=}"
            shift # Consume argument
            ;;
        --password=*)
            CLI_PASSWORD="${1#*=}"
            shift # Consume argument
            ;;
        --archive_mode=*)
            ARCHIVE_MODE="${1#*=}"
            shift # Consume argument
            ;;
        --force)
            FORCE_ARGS="--force"
            shift # Consume argument
            ;;
        --verbose)
            ENABLE_DEBUG_LOGS=1
            VERBOSE_ARGS="--verbose"
            shift # Consume argument
            ;;
        --help)
            show_help # Call help function, which will exit
            ;;
        *)
            show_help "error" "Invalid option '$1'" # Invalid option, show error and exit
            ;;
    esac
done


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
    popd || exit 1
    exit 1
fi

# --- Check and Install Python Dependencies ---
print_colored "Checking for required Python packages (requests, beautifulsoup4)..." "INFO"

install_python_package() {
    local package_name=$1
    if python3 -c "import $package_name" &> /dev/null; then
        print_colored "Python package '$package_name' is already installed." "INFO"
    else
        print_colored "Python package '$package_name' not found. Installing..." "INFO"
        pip_install_cmd="pip3 install $package_name"
        if ! eval "$pip_install_cmd"; then
            print_colored "ERROR: Failed to install Python package '$package_name'. Please ensure pip3 is installed and accessible, or install it manually." "ERROR"
            popd || exit 1
            exit 1
        fi
        print_colored "Python package '$package_name' installed successfully." "INFO"
    fi
}

install_python_package "requests"
install_python_package "bs4" # beautifulsoup4 is imported as bs4


if [ "$ARCHIVE_MODE" = "y" ]; then
    print_colored "ARCHIVE_MODE is ON." "INFO"
    ARCHIVE_MODE_ARGS="--archive_mode=y" # Pass this to install_module.sh
fi

# Install dx-com
print_colored "Installing dx-com (Version: $COM_VERSION)..." "INFO"
# Pass all relevant args to install_module.sh
INSTALL_COM_CMD="$SCRIPT_DIR/scripts/install_module.sh --module_name=dx_com --version=$COM_VERSION --download_url=$COM_DOWNLOAD_URL $ARCHIVE_MODE_ARGS $FORCE_ARGS $VERBOSE_ARGS"
print_colored "Executing: $INSTALL_COM_CMD" "DEBUG" # Debug line
$INSTALL_COM_CMD
if [ $? -ne 0 ]; then
    print_colored "Installing dx-com failed!" "ERROR"
    popd || exit 1
    exit 1
fi

popd || exit 1
print_colored "All installations completed successfully." "INFO"
exit 0
