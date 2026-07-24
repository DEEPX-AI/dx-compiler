#!/bin/bash

# If 'sudo' is not available (e.g., minimal containers like UBI/RHEL slim,
# distroless, or running as root in CI), provide a transparent shim so that
# 'sudo <cmd>' works either by running as root directly or by failing clearly.
# When running as root the command executes normally; when non-root, commands
# needing privileges will fail with permission errors, which is more informative
# than "sudo: command not found".
if ! command -v sudo >/dev/null 2>&1; then
    sudo() { "$@"; }
    export -f sudo 2>/dev/null || true
fi

# Function to get colored output (simplified for shell)
print_colored() {
    local message="$1"
    local level="$2" # "INFO", "DEBUG", "ERROR" etc.
    local enable_debug_logs=${ENABLE_DEBUG_LOGS:-0} # Default to 0 (false) if not provided

    # Suppress DEBUG messages unless enable_debug_logs is 1
    if [[ "$level" == "DEBUG" ]] && [[ "$enable_debug_logs" -ne 1 ]]; then
        return 0 # Do not print DEBUG message
    fi

    case "$level" in
        # TAG
        "ERROR") printf "${COLOR_BG_RED}[ERROR]${COLOR_RESET}${COLOR_BRIGHT_RED} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "SUCCESS") printf "${COLOR_BG_GREEN}[SUCCESS]${COLOR_RESET}${COLOR_BRIGHT_GREEN} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "OK") printf "${COLOR_BG_GREEN}[OK]${COLOR_RESET}${COLOR_BRIGHT_GREEN} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "FAIL") printf "${COLOR_BG_RED}[FAIL]${COLOR_RESET}${COLOR_BRIGHT_RED} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "INFO") printf "${COLOR_BG_BLUE}[INFO]${COLOR_RESET}${COLOR_BRIGHT_BLUE} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "WARNING") printf "${COLOR_BLACK_ON_YELLOW}[WARNING]${COLOR_RESET}${COLOR_BRIGHT_YELLOW} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "DEBUG") printf "${COLOR_BLACK_ON_YELLOW}[DEBUG]${COLOR_RESET}${COLOR_BRIGHT_YELLOW} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "HINT") printf "${COLOR_BG_GREEN}[HINT]${COLOR_RESET}${COLOR_BRIGHT_GREEN_ON_BLACK} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "SKIP") printf "${COLOR_WHITE_ON_GRAY}[SKIP]${COLOR_RESET}${COLOR_BRIGHT_WHITE_ON_GRAY} %s ${COLOR_RESET}\n" "$message" >&2 ;;

        # COLOR
        "RED") printf "${COLOR_BRIGHT_RED} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "BLUE") printf "${COLOR_BRIGHT_BLUE} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "YELLOW") printf "${COLOR_BRIGHT_YELLOW} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        "GREEN") printf "${COLOR_BRIGHT_GREEN} %s ${COLOR_RESET}\n" "$message" >&2 ;;
        *) printf "%s\n" "$message" >&2 ;;
    esac
}

print_colored_v2() {
    print_colored "$2" "$1"
}


check_container_mode() {
    # Check if running in a container
    if grep -qE "/docker|/lxc|/containerd" /proc/1/cgroup || [ -f /.dockerenv ]; then
        print_colored_v2 "INFO" "(container mode detected)"
        return 0
    else
        print_colored_v2 "INFO" "(host mode detected)"
        return 1
    fi
}

# Enable the CRB/PowerTools and EPEL repositories on RHEL/CentOS so that devel
# packages (e.g. gdbm-devel, tk-devel, readline-devel, mesa-libGL-devel) and
# EPEL-only packages are installable. Fedora ships these in its default repos,
# so it is skipped. Every step is best-effort ('|| true'): the repo name varies
# by distro+version and some images (e.g. minimal UBI) lack a CRB/EPEL
# definition entirely, so a failure here must never abort the caller. Callers
# that require specific packages should still verify them after installation.
# Self-contained (detects the OS internally) so it can be called from any
# dnf-based install path.
enable_rhel_extra_repos() {
    local OS_ID=""
    local OS_VERSION_ID=""
    if [ -f /etc/os-release ]; then
        OS_ID=$(grep "^ID=" /etc/os-release | sed 's/^ID=//' | tr -d '"')
        OS_VERSION_ID=$(grep "^VERSION_ID=" /etc/os-release | sed 's/^VERSION_ID=//' | tr -d '"')
    fi

    if [ "$OS_ID" != "rhel" ] && [ "$OS_ID" != "centos" ]; then
        # Fedora and non-Red-Hat families need no extra repo enablement here.
        return 0
    fi

    local OS_MAJOR_VERSION="${OS_VERSION_ID%%.*}"

    # Ensure dnf-plugins-core is available (provides 'config-manager').
    sudo dnf install -y dnf-plugins-core 2>/dev/null || true

    # Enable CodeReady Builder (CRB / PowerTools). The repo *alias* 'crb' exists
    # only on CentOS Stream / Rocky / Alma; UBI and subscribed RHEL name it
    # 'ubi-<major>-codeready-builder-rpms' / 'codeready-builder-for-rhel-<major>-*'
    # respectively, so '--set-enabled crb' is a silent no-op there. Try all the
    # known ids; each is best-effort and must never abort the caller.
    sudo dnf config-manager --set-enabled crb 2>/dev/null || true
    sudo dnf config-manager --set-enabled "ubi-${OS_MAJOR_VERSION}-codeready-builder-rpms" 2>/dev/null || true
    sudo dnf config-manager --set-enabled "codeready-builder-for-rhel-${OS_MAJOR_VERSION}-x86_64-rpms" 2>/dev/null || true

    # Enable EPEL (provides patchelf, ccache, and other extras). CentOS Stream
    # ships epel-release in its own repos; UBI/RHEL must install the EPEL release
    # RPM by URL. Best-effort: a failure here must never abort the caller.
    if ! sudo dnf install -y epel-release 2>/dev/null; then
        sudo dnf install -y \
            "https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_MAJOR_VERSION}.noarch.rpm" \
            2>/dev/null || true
    fi
}

check_virtualenv() {
    if [ -n "$VIRTUAL_ENV" ]; then
        venv_name=$(basename "$VIRTUAL_ENV")
        print_colored_v2 "info" "✅ Virtual environment '$venv_name' is currently active."
        return 0
    else
        print_colored_v2 "info" "❌ No virtual environment is currently active."
        return 1
    fi
}


# Handle command failure with user confirmation and suggested action
handle_cmd_failure() {
    local error_message=$1
    local hint_message=$2
    local origin_cmd=$3
    local suggested_action_cmd=$4
    local suggested_action_message="Would you like to perform the suggested action now?"
    local message_type="ERROR"

    handle_cmd_interactive "$error_message" "$hint_message" "$origin_cmd" "$suggested_action_cmd" "$suggested_action_message" "$message_type"
}

# Interactive command handler with user confirmation
handle_cmd_interactive() {
    local message=$1
    local hint_message=$2
    local origin_cmd=$3
    local suggested_action_cmd=$4
    local suggested_action_message=$5
    local message_type=$6
    local default_input=${7:-Y}
    
    print_colored_v2 "${message_type}" "${message}"
    print_colored_v2 "HINT" "${hint_message}"
    print_colored_v2 "YELLOW" "${suggested_action_message} [y/n] (Default is '${default_input}' after 10 seconds of no input. This process will be aborted if you enter 'n')"
    read -t 10 -p ">> " user_input
    user_input=${user_input:-$default_input}
    if [[ "${user_input,,}" == "n" ]]; then
        print_colored_v2 "INFO" "This process aborted by user."
        return 5
    else
        if [ -n "$suggested_action_cmd" ]; then
            print_colored_v2 "INFO" "Suggested action will be performed."
            eval "$suggested_action_cmd" || {
                print_colored_v2 "ERROR" "Failed to perform suggested action."
                exit 1
            }
        fi

        if [ -n "$origin_cmd" ]; then
            eval "$origin_cmd" || {
                print_colored_v2 "ERROR" "${message}"
                exit 1
            }
        fi
    fi

    return 0
}

# OS Check function
# Usage: os_check "supported_os_names" "ubuntu_versions" "debian_versions" "fedora_versions" "rhel_versions" "centos_versions"
# Example: os_check "ubuntu debian fedora rhel centos" "20.04 22.04 24.04 26.04" "11 12" "42 43 44 45" "9 10" "9 10"
os_check() {
    print_colored "--- OS Check..... ---" "INFO"
    
    # Parse function arguments with default values
    local supported_os_names="${1}"
    local supported_ubuntu_versions="${2}"
    local supported_debian_versions="${3}"
    local supported_fedora_versions="${4}"
    local supported_rhel_versions="${5}"
    local supported_centos_versions="${6}"

    print_colored "supported_os_names: $supported_os_names" "DEBUG"
    print_colored "supported_ubuntu_versions: $supported_ubuntu_versions" "DEBUG"
    print_colored "supported_debian_versions: $supported_debian_versions" "DEBUG"
    print_colored "supported_fedora_versions: $supported_fedora_versions" "DEBUG"
    print_colored "supported_rhel_versions: $supported_rhel_versions" "DEBUG"
    print_colored "supported_centos_versions: $supported_centos_versions" "DEBUG"
    
    # Check if /etc/os-release exists
    if [ ! -f /etc/os-release ]; then
        print_colored "/etc/os-release file not found. Cannot determine OS information." "ERROR"
        return 1
    fi
    
    # Get OS information from /etc/os-release using grep and sed
    local OS_ID=""
    local OS_VERSION_ID=""
    
    # Extract OS information without sourcing the file
    OS_ID=$(grep "^ID=" /etc/os-release | sed 's/^ID=//' | tr -d '"')
    OS_VERSION_ID=$(grep "^VERSION_ID=" /etc/os-release | sed 's/^VERSION_ID=//' | tr -d '"')
    
    print_colored "Detected OS: $OS_ID $OS_VERSION_ID" "INFO"
    
    # Check if OS is supported using supported_os_names parameter
    local os_supported=false
    local detected_os=""
    
    # Loop through supported OS names and check compatibility.
    # Pass 1: prefer an exact ID= match so that derivatives whose ID_LIKE
    # mentions another supported OS (e.g. RHEL has ID_LIKE="fedora") are
    # correctly identified as themselves, not as the ID_LIKE target.
    for supported_os in $supported_os_names; do
        if [ "$OS_ID" = "$supported_os" ]; then
            os_supported=true
            detected_os="$supported_os"
            print_colored "Detected $supported_os (exact ID match)" "DEBUG"
            break
        fi
    done

    # Explicitly reject RHEL derivatives that are not officially supported.
    # Without this check, distributions like AlmaLinux/Rocky Linux would be
    # misidentified via ID_LIKE (which contains "fedora rhel centos") in Pass 2
    # and then fail the version check with a confusing error.
    #
    # NOTE: This block is intentionally independent of the supported_os_names
    # argument. If AlmaLinux/Rocky are officially qualified in the future,
    # remove their IDs from this case AND add them to the supported_os_names
    # list at the call site (os_arch_check in install.sh).
    #
    # No diagnostic is printed here: the caller (os_arch_check) decides whether
    # to emit a user-facing error based on its print_message_mode argument,
    # so emitting one here would leak output in "silent" mode (e.g. probing
    # whether to skip dx_tron on AlmaLinux during the 'all' install flow).
    case "$OS_ID" in
        almalinux|rocky)
            return 1
            ;;
    esac

    # Pass 2: fall back to ID_LIKE-based compatibility detection.
    #
    # Iterate using a deliberate priority order instead of the caller's
    # supported_os_names order. RHEL-family derivatives (e.g. Oracle Linux)
    # commonly carry an ID_LIKE that mentions both "fedora" and "rhel"/"centos"
    # while using RHEL-style major versions (9, 10). If "fedora" were matched
    # first, the version check would use an exact Fedora match (42-45) and
    # wrongly reject them, so rhel/centos must take precedence over fedora here.
    # This mirrors how install.sh / install_prerequisites.sh normalize such
    # derivatives to the redhat family via ID_LIKE. Only OS names actually
    # present in supported_os_names are considered.
    if [ "$os_supported" = false ]; then
        for supported_os in ubuntu debian rhel centos fedora; do
            case " $supported_os_names " in
                *" $supported_os "*) ;;
                *) continue ;;
            esac
            if grep -q "ID_LIKE=.*${supported_os}" /etc/os-release; then
                os_supported=true
                detected_os="$supported_os"
                print_colored "Detected $supported_os-compatible OS via ID_LIKE" "DEBUG"
                break
            fi
        done
    fi
    
    # detected_os will be used directly for version checking
    
    if [ "$os_supported" = false ]; then
        print_colored "Unsupported operating system: $OS_ID" "ERROR"
        print_colored "Supported operating systems: $supported_os_names and their compatible distributions" "HINT"
        return 1
    fi
    
    # Check OS version support based on detected OS
    local version_supported=false
    local supported_versions=""
    
    case "$detected_os" in
        ubuntu)
            supported_versions="$supported_ubuntu_versions"
            for version in $supported_ubuntu_versions; do
                if [ "$OS_VERSION_ID" = "$version" ]; then
                    version_supported=true
                    break
                fi
            done
            ;;
        debian)
            supported_versions="$supported_debian_versions"
            for version in $supported_debian_versions; do
                if [ "$OS_VERSION_ID" = "$version" ]; then
                    version_supported=true
                    break
                fi
            done
            ;;
        fedora)
            supported_versions="$supported_fedora_versions"
            for version in $supported_fedora_versions; do
                if [ "$OS_VERSION_ID" = "$version" ]; then
                    version_supported=true
                    break
                fi
            done
            ;;
        rhel)
            supported_versions="$supported_rhel_versions"
            # For RHEL, compare major version only (e.g., 9.x matches 9)
            local OS_MAJOR_VERSION="${OS_VERSION_ID%%.*}"
            for version in $supported_rhel_versions; do
                if [ "$OS_MAJOR_VERSION" = "$version" ]; then
                    version_supported=true
                    break
                fi
            done
            ;;
        centos)
            supported_versions="$supported_centos_versions"
            local OS_MAJOR_VERSION="${OS_VERSION_ID%%.*}"
            for version in $supported_centos_versions; do
                if [ "$OS_MAJOR_VERSION" = "$version" ]; then
                    version_supported=true
                    break
                fi
            done
            ;;
        *)
            print_colored "Internal error: Unsupported OS in version check" "ERROR"
            return 1
            ;;
    esac
    
    if [ "$version_supported" = false ]; then
        print_colored "Current $detected_os version $OS_VERSION_ID is not officially supported." "ERROR"
        print_colored "Officially supported $detected_os versions: $supported_versions" "HINT"
        
        # Determine if current version is newer or older than supported versions
        local is_newer_version=false
        local max_supported_version=""
        
        # Find the maximum supported version
        for version in $supported_versions; do
            if [ -z "$max_supported_version" ]; then
                max_supported_version="$version"
            else
                # Compare versions using sort -V (version sort)
                local higher_version=$(printf "%s\n%s" "$max_supported_version" "$version" | sort -V | tail -n1)
                if [ "$higher_version" = "$version" ]; then
                    max_supported_version="$version"
                fi
            fi
        done
        
        # Check if current version is newer than maximum supported version
        if [ -n "$OS_VERSION_ID" ] && [ -n "$max_supported_version" ]; then
            local higher_version=$(printf "%s\n%s" "$max_supported_version" "$OS_VERSION_ID" | sort -V | tail -n1)
            if [ "$higher_version" = "$OS_VERSION_ID" ] && [ "$OS_VERSION_ID" != "$max_supported_version" ]; then
                is_newer_version=true
            fi
        fi
        
        # Provide appropriate guidance based on version comparison
        if [ "$is_newer_version" = true ]; then
            print_colored "Please use one of the officially supported $detected_os versions listed above." "HINT"
        else
            print_colored "Please upgrade to one of the officially supported $detected_os versions listed above." "HINT"
        fi
        
        return 1
    fi
    
    print_colored "$detected_os $OS_VERSION_ID is supported." "INFO"
    print_colored "[OK] OS check completed successfully." "INFO"
    return 0
}

# Architecture Check function
# Usage: arch_check "supported_arch_names"
# Example: 
#   only x86: arch_check "amd64 x86_64"
#   only ARM: arch_check "arm64 aarch64 arm64 armv7l"
#   both ARM and x86: arch_check "amd64 x86_64 arm64 aarch64 armv7l"
arch_check() {
    print_colored "--- Arch Check..... ---" "INFO"
    local supported_arch_names="${1}"

    print_colored "supported_arch_names: $supported_arch_names" "DEBUG"
    
    # Note: amd64 and x86_64 are treated as compatible (both represent 64-bit x86 architecture)
    # - amd64: Debian/Ubuntu package architecture naming convention
    # - x86_64: Kernel/System architecture naming convention
    
    # Get system architecture using uname -m (POSIX standard, available on all Linux systems)
    local SYSTEM_ARCH=""
    SYSTEM_ARCH=$(uname -m 2>/dev/null)
    
    if [ -z "$SYSTEM_ARCH" ]; then
        print_colored "Failed to determine system architecture using uname -m" "ERROR"
        return 1
    fi
    
    print_colored "Detected architecture: $SYSTEM_ARCH" "INFO"
    
    # Check if architecture is supported
    local arch_supported=false
    
    # Loop through supported architecture names
    for supported_arch in $supported_arch_names; do
        # Direct match
        if [ "$SYSTEM_ARCH" = "$supported_arch" ]; then
            arch_supported=true
            print_colored "Architecture $SYSTEM_ARCH is supported" "DEBUG"
            break
        fi
    done
    
    if [ "$arch_supported" = false ]; then
        print_colored "Unsupported architecture: $SYSTEM_ARCH" "ERROR"
        print_colored "Supported architectures: $supported_arch_names" "HINT"
        return 1
    fi
    
    print_colored "Architecture $SYSTEM_ARCH is supported." "INFO"
    print_colored "[OK] Architecture check completed successfully." "INFO"

    return 0
}

delete_dir() {
    local path="$1"
    
    # Use shell globbing to expand wildcards
    # This will handle patterns like "build_*", "*.log", etc.
    for expanded_path in $path; do
        if [ -e "$expanded_path" ] || [ -L "$expanded_path" ]; then
            print_colored_v2 "INFO" "Deleting path: $expanded_path"
            
            # First attempt: try to delete without sudo
            rm -rf "$expanded_path" 2>&1
            local exit_code=$?
            
            if [ $exit_code -ne 0 ]; then
                # Check if it's a permission denied error
                if [[ "$(rm -rf "$expanded_path" 2>&1)" == *"Permission denied"* ]] || [ $exit_code -eq 1 ]; then
                    print_colored_v2 "WARNING" "Permission denied when deleting: $expanded_path"
                    print_colored_v2 "INFO" "Retrying with sudo..."
                    
                    # Second attempt: try to delete with sudo
                    sudo rm -rf "$expanded_path" 2>&1
                    local sudo_exit_code=$?
                    
                    if [ $sudo_exit_code -eq 0 ]; then
                        print_colored_v2 "SUCCESS" "Successfully deleted with sudo: $expanded_path"
                    else
                        print_colored_v2 "ERROR" "Failed to delete even with sudo: $expanded_path"
                        exit 1
                    fi
                else
                    print_colored_v2 "ERROR" "Failed to delete: $expanded_path (exit code: $exit_code)"
                    exit 1
                fi
            fi
        else
            print_colored_v2 "DEBUG" "Skip to delete path, because it does not exist: $expanded_path"
        fi
    done
    
    # If no files matched the pattern, show appropriate message
    if [ ! -e "$path" ] && [ ! -L "$path" ] && [[ "$path" == *"*"* ]]; then
        print_colored_v2 "DEBUG" "No paths found matching pattern: $path"
    fi
}

delete_path() {
    delete_dir "$1"
}

# Function to delete symlinks and their target files
delete_symlinks() {
    local dir="$1"
    for symlink in "$dir"/*; do
        if [ -L "$symlink" ]; then  # Check if the file is a symbolic link
            real_file=$(readlink -f "$symlink")  # Get the actual file path the symlink points to

            # If the original file exists, delete it
            if [ -e "$real_file" ]; then
                print_colored_v2 "INFO" "Deleting original file: $real_file"
                
                # First attempt: try to delete without sudo
                rm -rf "$real_file" 2>&1
                local exit_code=$?
                
                if [ $exit_code -ne 0 ]; then
                    # Check if it's a permission denied error
                    if [[ "$(rm -rf "$real_file" 2>&1)" == *"Permission denied"* ]] || [ $exit_code -eq 1 ]; then
                        print_colored_v2 "WARNING" "Permission denied when deleting original file: $real_file"
                        print_colored_v2 "INFO" "Retrying with sudo..."
                        
                        # Second attempt: try to delete with sudo
                        sudo rm -rf "$real_file" 2>&1
                        local sudo_exit_code=$?
                        
                        if [ $sudo_exit_code -eq 0 ]; then
                            print_colored_v2 "SUCCESS" "Successfully deleted original file with sudo: $real_file"
                        else
                            print_colored_v2 "ERROR" "Failed to delete original file even with sudo: $real_file"
                            exit 1
                        fi
                    else
                        print_colored_v2 "ERROR" "Failed to delete original file: $real_file (exit code: $exit_code)"
                        exit 1
                    fi
                fi
            fi

            # Delete the symbolic link
            print_colored_v2 "INFO" "Deleting symlink: $symlink"
            
            # First attempt: try to delete without sudo
            rm -rf "$symlink" 2>&1
            local exit_code=$?
            
            if [ $exit_code -ne 0 ]; then
                # Check if it's a permission denied error
                if [[ "$(rm -rf "$symlink" 2>&1)" == *"Permission denied"* ]] || [ $exit_code -eq 1 ]; then
                    print_colored_v2 "WARNING" "Permission denied when deleting symlink: $symlink"
                    print_colored_v2 "INFO" "Retrying with sudo..."
                    
                    # Second attempt: try to delete with sudo
                    sudo rm -rf "$symlink" 2>&1
                    local sudo_exit_code=$?
                    
                    if [ $sudo_exit_code -eq 0 ]; then
                        print_colored_v2 "SUCCESS" "Successfully deleted symlink with sudo: $symlink"
                    else
                        print_colored_v2 "ERROR" "Failed to delete symlink even with sudo: $symlink"
                        exit 1
                    fi
                else
                    print_colored_v2 "ERROR" "Failed to delete symlink: $symlink (exit code: $exit_code)"
                    exit 1
                fi
            fi
        else
            print_colored_v2 "DEBUG" "Skip to delete symlink, because it is not a symlink: $symlink"
        fi
    done
}

check_docker_compose() {
    if command -v docker &> /dev/null; then
        if docker compose version &> /dev/null; then
            echo "✅ The 'docker compose' command works properly."
            return 0
        else
            echo "⚠️ 'docker' is installed, but the 'compose' command is not available."
            return 1
        fi
    else
        echo "❌ 'docker' is not installed on the system."
        return 1
    fi
}
