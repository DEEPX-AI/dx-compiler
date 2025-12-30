#!/bin/bash

SCRIPT_DIR=$(realpath "$(dirname "$0")")
PROJECT_ROOT=$(realpath "$SCRIPT_DIR")
COMPILER_PATH=$(realpath -s "${SCRIPT_DIR}")
TRON_BASE_PATH=$(realpath -s "${COMPILER_PATH}/dx_tron")

pushd "$PROJECT_ROOT" >&2

source "${COMPILER_PATH}/scripts/color_env.sh"
source "${COMPILER_PATH}/scripts/common_util.sh"

# Default port
PORT=8080

# Function to display help message
show_help() {
    echo "Usage: $(basename "$0") [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --port=<port>    Specify the port to run the web server (default: 8080)"
    echo "  --help           Display this help message"
    echo ""
    echo "Example:"
    echo "  $(basename "$0")                # Run on default port 8080"
    echo "  $(basename "$0") --port=3000    # Run on port 3000"
    exit 0
}

# Parse arguments
for arg in "$@"; do
    case "$arg" in
        --port=*)
            PORT="${arg#*=}"
            ;;
        --help)
            show_help
            ;;
        *)
            print_colored "ERROR: Unknown option '$arg'" "ERROR"
            show_help
            ;;
    esac
done

# Validate port number
if ! [[ "$PORT" =~ ^[0-9]+$ ]] || [ "$PORT" -lt 1 ] || [ "$PORT" -gt 65535 ]; then
    print_colored "ERROR: Invalid port number '$PORT'. Must be between 1 and 65535." "ERROR"
    exit 1
fi

# Check if port is already in use
if command -v lsof &> /dev/null; then
    # Use lsof if available
    if lsof -i ":$PORT" -sTCP:LISTEN -t >/dev/null 2>&1; then
        print_colored "ERROR: Port $PORT is already in use." "ERROR"
        print_colored "Currently using process:" "INFO"
        lsof -i ":$PORT" -sTCP:LISTEN | tail -n +2
        print_colored "Please choose a different port using --port=<port> option." "INFO"
        exit 1
    fi
elif command -v ss &> /dev/null; then
    # Use ss if lsof is not available
    if ss -tuln | grep -q ":$PORT "; then
        print_colored "ERROR: Port $PORT is already in use." "ERROR"
        print_colored "Please choose a different port using --port=<port> option." "INFO"
        exit 1
    fi
elif command -v netstat &> /dev/null; then
    # Use netstat as fallback
    if netstat -tuln 2>/dev/null | grep -q ":$PORT "; then
        print_colored "ERROR: Port $PORT is already in use." "ERROR"
        print_colored "Please choose a different port using --port=<port> option." "INFO"
        exit 1
    fi
else
    print_colored "WARNING: Cannot check if port is in use (lsof, ss, netstat not found). Proceeding anyway..." "WARNING"
fi

# Check if dx_tron directory exists (handle both regular directory and symlink)
if [ ! -e "${COMPILER_PATH}/dx_tron" ]; then
    print_colored "ERROR: dx_tron directory not found at '${COMPILER_PATH}/dx_tron'." "ERROR"
    print_colored "Please run install.sh first to install dx_tron." "INFO"
    exit 1
fi

# Resolve dx_tron path if it's a symlink
TRON_REAL_PATH="${COMPILER_PATH}/dx_tron"
if [ -L "${COMPILER_PATH}/dx_tron" ]; then
    TRON_REAL_PATH=$(readlink -f "${COMPILER_PATH}/dx_tron")
    print_colored "INFO: dx_tron is a symlink, resolved to: $TRON_REAL_PATH" "DEBUG"
fi

# Find dxtron web directory (pattern: dxtron_*_web)
# Use -L to follow symlinks
WEB_DIR=$(find -L "$TRON_REAL_PATH" -maxdepth 1 -type d -name "dxtron_*_web" | head -n 1)

if [ -z "$WEB_DIR" ]; then
    print_colored "ERROR: No dxtron web directory found in '${COMPILER_PATH}/dx_tron'." "ERROR"
    print_colored "Expected directory pattern: dxtron_*_web" "INFO"
    exit 1
fi

print_colored "Starting DX-TRON web server..." "INFO"
print_colored "Web directory: $(basename "$WEB_DIR")" "INFO"
print_colored "Port: $PORT" "INFO"
print_colored "URL: http://localhost:$PORT" "INFO"
echo ""
print_colored "Press Ctrl+C to stop the server" "WARNING"
echo ""

# Run Python HTTP server
python3 -m http.server "$PORT" -d "$WEB_DIR"
