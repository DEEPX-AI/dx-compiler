#!/bin/bash

# Source shared helpers (enable_rhel_extra_repos, sudo shim, etc.) so common
# logic lives in a single place and cannot drift between scripts.
SCRIPT_DIR=$(realpath "$(dirname "$0")")
source "${SCRIPT_DIR}/common_util.sh"

echo "Install dependencies..."

# Detect OS family
if [ -f /etc/os-release ]; then
    OS_ID=$(grep "^ID=" /etc/os-release | sed 's/^ID=//' | tr -d '"')
    OS_VERSION_ID=$(grep "^VERSION_ID=" /etc/os-release | sed 's/^VERSION_ID=//' | tr -d '"')
else
    echo "ERROR: /etc/os-release not found. Cannot determine OS." && exit 1
fi

echo "*** OS: ${OS_ID} ${OS_VERSION_ID} ***"

# Normalize OS_ID to a supported package-manager family. os_check() in
# common_util.sh admits RHEL/Debian derivatives via ID_LIKE (e.g. Oracle Linux
# ID=ol, ID_LIKE="rhel fedora"); without this step they would fall through to
# the unsupported '*)' branch below despite passing os_arch_check.
case "$OS_ID" in
    ubuntu|debian|fedora|rhel|centos)
        # Already a directly supported ID; no remap needed.
        ;;
    *)
        if grep -qE 'ID_LIKE=.*(rhel|fedora|centos)' /etc/os-release 2>/dev/null; then
            echo "INFO: '$OS_ID' detected as RHEL-family derivative via ID_LIKE; treating as rhel."
            OS_ID="rhel"
        elif grep -qE 'ID_LIKE=.*(debian|ubuntu)' /etc/os-release 2>/dev/null; then
            echo "INFO: '$OS_ID' detected as Debian-family derivative via ID_LIKE; treating as debian."
            OS_ID="debian"
        fi
        ;;
esac

# Determine package manager family
case "$OS_ID" in
    ubuntu|debian)
        # Debian/Ubuntu family - use apt
        UBUNTU_VERSION="${OS_VERSION_ID}"

        # Run apt non-interactively so packages like tzdata don't block on prompts
        # (e.g. the geographic area / timezone selection). 'env' is used instead of
        # an exported variable because real sudo resets the environment, and it also
        # works with the sudo shim defined above.
        APT_ENV="env DEBIAN_FRONTEND=noninteractive"

        sudo apt-get update && sudo $APT_ENV apt-get install -y software-properties-common \
            || { echo "ERROR: Failed to update apt repositories"; exit 1; }

        # 'universe' is an Ubuntu-only component; on Debian, attempting to
        # enable it via add-apt-repository fails and aborts the install.
        if [ "$OS_ID" = "ubuntu" ]; then
            sudo add-apt-repository -y universe && sudo apt-get update \
                || { echo "ERROR: Failed to add universe repository"; exit 1; }
        else
            sudo apt-get update || { echo "ERROR: Failed to update apt repositories"; exit 1; }
        fi

        # Version-specific packages
        if [ "$UBUNTU_VERSION" = "24.04" ] || [ "$UBUNTU_VERSION" = "26.04" ]; then
            # libfuse2 is safe (needed for AppImages), but 'fuse' package must be avoided
            sudo $APT_ENV apt-get install -y --no-install-recommends \
                libgl1-mesa-dev libglib2.0-0 make \
                libfuse2 \
                libncurses-dev || { echo "ERROR: Failed to install version-specific packages"; exit 1; }
        elif [ "$UBUNTU_VERSION" = "22.04" ]; then
            sudo $APT_ENV apt-get install -y --no-install-recommends \
                libgl1-mesa-dev libglib2.0-0 make \
                libfuse2 libappindicator3-1 libgconf-2-4 \
                libncurses5-dev libncursesw5-dev || { echo "ERROR: Failed to install version-specific packages"; exit 1; }
        elif [ "$UBUNTU_VERSION" = "20.04" ]; then
            sudo $APT_ENV apt-get install -y --no-install-recommends \
                libgl1-mesa-dev libgl1-mesa-glx libglib2.0-0 make \
                libfuse2 libappindicator1 libgconf-2-4 \
                libncurses5-dev libncursesw5-dev || { echo "ERROR: Failed to install version-specific packages"; exit 1; }
        elif [ "$OS_ID" = "debian" ]; then
            sudo $APT_ENV apt-get install -y --no-install-recommends \
                libgl1-mesa-dev libglib2.0-0 make \
                libfuse2 \
                libncurses-dev || { echo "ERROR: Failed to install version-specific packages"; exit 1; }
        else
            echo "Unsupported Ubuntu/Debian version: $OS_VERSION_ID" && exit 1
        fi

        # Common packages across all Debian/Ubuntu versions
        sudo $APT_ENV apt-get install -y --no-install-recommends \
            libssl-dev \
            wget \
            openssl \
            build-essential \
            zlib1g-dev \
            patchelf \
            libffi-dev \
            ca-certificates \
            libbz2-dev \
            liblzma-dev \
            libsqlite3-dev \
            tk-dev \
            libgdbm-dev \
            libc6-dev \
            libnss3-dev \
            ccache \
            libxss1 libxtst6 libnss3 \
            xdg-utils || { echo "ERROR: Failed to install common packages"; exit 1; }

        # Optional GUI helper packages (best-effort): GUI-only deps such as the
        # system tray indicator (libayatana-appindicator3-1) and the canberra GTK
        # modules are not required for build/runtime, and their availability/names
        # vary across releases (e.g. libcanberra-gtk-module is dropped on Ubuntu
        # 26.04). Install them individually and skip any without an installation
        # candidate without aborting the whole prerequisite step.
        for optional_pkg in libayatana-appindicator3-1 libcanberra-gtk-module libcanberra-gtk3-module; do
            if apt-cache show "$optional_pkg" >/dev/null 2>&1; then
                sudo $APT_ENV apt-get install -y --no-install-recommends "$optional_pkg" \
                    || echo "WARNING: Failed to install optional package '$optional_pkg', continuing..."
            else
                echo "WARNING: Optional package '$optional_pkg' is not available on this OS, skipping."
            fi
        done
        ;;

    fedora|rhel|centos)
        # Red Hat family - use dnf
        echo "Installing prerequisites for ${OS_ID} ${OS_VERSION_ID}..."

        # Enable extra repos (CRB/PowerTools + EPEL) for RHEL/CentOS so that
        # devel packages like mesa-libGL-devel, gdbm-devel, nss-devel and
        # EPEL-only packages like patchelf, ccache, xdg-utils are available.
        # Fedora ships these in its default repos, so this is a no-op there.
        # Delegated to common_util.sh's enable_rhel_extra_repos() to keep the
        # repo-enablement logic in a single place.
        enable_rhel_extra_repos

        # Pick a flag that tells dnf to keep going when some packages are
        # unavailable. dnf5 (Fedora 41+) uses --skip-unavailable; older dnf4
        # uses --skip-broken. Probe once and reuse.
        # Use an array so an empty value expands to zero arguments (an
        # unquoted scalar would still work today but is SC2086-fragile;
        # a quoted scalar would pass a literal "" to dnf).
        SKIP_FLAG=()
        # Merge stderr into stdout: some dnf variants emit (parts of) --help
        # on stderr; suppressing it could leave DNF_HELP empty and prevent us
        # from detecting --skip-unavailable / --skip-broken.
        DNF_HELP=$(dnf install --help 2>&1)
        if echo "$DNF_HELP" | grep -q -- '--skip-unavailable'; then
            SKIP_FLAG=(--skip-unavailable)
        elif echo "$DNF_HELP" | grep -q -- '--skip-broken'; then
            SKIP_FLAG=(--skip-broken)
        fi

        # Essential build/runtime headers. Verified after install (non-fatal
        # WARNING) so a missing one surfaces here, not as an opaque error during
        # the later Python source build.
        # ponytail: Fedora 40+ and RHEL/CentOS 10+ replace zlib-devel with
        # zlib-ng-compat-devel (zlib-ng-compat provides the zlib-devel capability).
        ZLIB_PKG="zlib-devel"
        OS_MAJOR_VERSION_TMP="${OS_VERSION_ID%%.*}"
        # Group the rhel/centos test with the version check so the major>=10
        # bound applies only to them, not to Fedora (all Fedora releases use
        # zlib-ng-compat-devel). Matches install_python_and_venv.sh's grouping.
        if [ "$OS_ID" = "fedora" ] \
            || { { [ "$OS_ID" = "rhel" ] || [ "$OS_ID" = "centos" ]; } \
                 && [ "${OS_MAJOR_VERSION_TMP}" -ge 10 ] 2>/dev/null; }; then
            ZLIB_PKG="zlib-ng-compat-devel"
        fi
        ESSENTIAL_RPMS=(
            mesa-libGL
            openssl-devel
            ncurses-devel
            "$ZLIB_PKG"
            libffi-devel
            bzip2-devel
            xz-devel
            sqlite-devel
            glib2
            tk-devel
            gcc
            gcc-c++
            make
            patchelf
        )

        # Auxiliary packages: not required for build/runtime and their
        # availability/names vary across releases (e.g. net-tools, iproute, lsof
        # may be absent on minimal images).
        AUXILIARY_RPMS=(
            glib2
            wget
            openssl
            ca-certificates
            glibc-devel
            nss-devel
            ccache
            libXScrnSaver libXtst nss
            xdg-utils
            findutils
            tar
            gzip
            lsof
            iproute
            net-tools
        )

        # Install essential and auxiliary packages in two separate transactions
        # so a single unavailable auxiliary package cannot abort the whole step
        # when SKIP_FLAG is empty (dnf refuses the entire transaction). Essential
        # failures are surfaced by the explicit verification below.
        sudo dnf install -y "${SKIP_FLAG[@]}" "${ESSENTIAL_RPMS[@]}" \
            || echo "WARNING: dnf reported errors installing essential packages; verifying below..."
        sudo dnf install -y "${SKIP_FLAG[@]}" "${AUXILIARY_RPMS[@]}" \
            || echo "WARNING: some auxiliary packages failed to install, continuing..."

        # Because SKIP_FLAG (--skip-unavailable/--skip-broken) lets dnf exit 0
        # even when a package has no install candidate, an essential header can
        # be silently dropped (e.g. if CRB/EPEL enablement failed). Verify the
        # essential ones explicitly and surface any miss as a WARNING so it is
        # visible here rather than as an opaque ./configure or make error during
        # a later Python source build. Non-fatal on purpose: minimal images
        # (e.g. UBI) may legitimately lack a few, and the source-build path
        # re-attempts its own dependency install.
        MISSING_RPMS=()
        for pkg in "${ESSENTIAL_RPMS[@]}"; do
            rpm -q "$pkg" >/dev/null 2>&1 || MISSING_RPMS+=("$pkg")
        done
        if [ "${#MISSING_RPMS[@]}" -gt 0 ]; then
            echo "WARNING: the following essential packages are not installed: ${MISSING_RPMS[*]}"
            echo "         They are usually provided by the CRB/PowerTools or EPEL repositories;"
            echo "         the build may fail later if any of them are genuinely required."
        fi
        ;;
    *)
        echo "Unsupported OS: $OS_ID" && exit 1
        ;;
esac

echo "Dependencies installed successfully."
