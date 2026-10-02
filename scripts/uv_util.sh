#!/bin/bash
# uv (Astral) detection and bootstrap for dx-compiler install.sh.
#
# Exports two variables consumed by install.sh:
#   PIP_CMD            "pip"              | "uv pip"
#   PIP_UNINSTALL_CMD  "pip uninstall -y" | "uv pip uninstall"
#
# uv pip is CLI-compatible with pip for install/uninstall, so callers just
# swap the command prefix. Two exceptions are NOT routed through here:
#   - `pip download`: uv has no equivalent. Archive mode keeps pip.
#   - `pip uninstall`: uv never prompts, so it rejects `-y`.

# Pinned so the installer never pulls an unreviewed uv release.
UV_PIN="${UV_PIN:-0.12.2}"

# Set UV_NO_BOOTSTRAP=1 to probe only (used by tests and by offline CI).
UV_NO_BOOTSTRAP="${UV_NO_BOOTSTRAP:-0}"

uv_available() {
    command -v uv >/dev/null 2>&1
}

# Where the standalone installer drops the uv binary.
UV_BOOTSTRAP_DIR="${UV_BOOTSTRAP_DIR:-${HOME}/.local/bin}"

# Make uv available. Returns non-zero on failure so the caller can fall back to
# pip instead of aborting the install.
#
# uv is fetched as a standalone binary rather than with `pip install uv`,
# because pip is not dependable at this point:
#   - Debian/Ubuntu ship PEP 668 EXTERNALLY-MANAGED markers that reject
#     `pip install` into the system Python, --user included, so on Ubuntu
#     24.04/26.04 the pip route always fails. Getting past it needs
#     --break-system-packages, which a customer-facing installer has no
#     business doing to a distro Python.
#   - Inside a virtualenv pip is usually present, but not always: a venv built
#     by `uv venv` without --seed has none, and bare `pip` then silently
#     resolves to the system pip and hits the case above.
# The standalone binary sidesteps both and touches no Python installation.
#
# The URL is pinned to UV_PIN so this never fetches an unreviewed release, and
# UV_NO_MODIFY_PATH keeps the installer out of the user's shell rc files.
bootstrap_uv() {
    if [ "${UV_NO_BOOTSTRAP}" = "1" ]; then
        return 1
    fi

    command -v curl >/dev/null 2>&1 || {
        echo "[WARNING] curl not found; cannot install uv." >&2
        return 1
    }
    mkdir -p "${UV_BOOTSTRAP_DIR}" || return 1
    echo "[INFO] Installing uv ${UV_PIN} to ${UV_BOOTSTRAP_DIR}..." >&2

    # Download first, run second, rather than `curl ... | sh`. install.sh does
    # not set `pipefail`, so a failed curl would be invisible there: the
    # pipeline reports sh's status, and sh happily "succeeds" on the empty or
    # truncated input it was handed. Downloading to a file lets curl's own exit
    # status be checked, and means a partial download is never executed.
    local uv_installer
    uv_installer=$(mktemp) || return 1
    if ! curl -LsSf "https://astral.sh/uv/${UV_PIN}/install.sh" -o "${uv_installer}"; then
        echo "[WARNING] Could not download the uv ${UV_PIN} installer." >&2
        rm -f "${uv_installer}"
        return 1
    fi
    env UV_INSTALL_DIR="${UV_BOOTSTRAP_DIR}" UV_NO_MODIFY_PATH=1 sh "${uv_installer}" >&2
    local install_rc=$?
    rm -f "${uv_installer}"
    [ ${install_rc} -eq 0 ] || return 1

    # UV_BOOTSTRAP_DIR is not necessarily on the current PATH.
    if ! command -v uv >/dev/null 2>&1; then
        PATH="${UV_BOOTSTRAP_DIR}:${PATH}"
        export PATH
    fi
    command -v uv >/dev/null 2>&1
}

# resolve_pip_cmd <use_uv:0|1> [allow_bootstrap:0|1]
# Sets PIP_CMD and PIP_UNINSTALL_CMD. Never exits; always leaves a usable
# command pair so a uv problem degrades to pip rather than failing install.
#
# allow_bootstrap decides what happens when uv is wanted but not installed, and
# it defaults to off. uv is on by default, and installing software on someone's
# machine because of a default they never chose is not this script's call: an
# install that did not ask for uv behaves exactly as it did before uv existed.
# install.sh passes 1 only when the user typed --uv=true.
resolve_pip_cmd() {
    local use_uv="${1:-0}"
    local allow_bootstrap="${2:-0}"

    PIP_CMD="pip"
    PIP_UNINSTALL_CMD="pip uninstall -y"

    if [ "${use_uv}" != "1" ]; then
        return 0
    fi

    if ! uv_available; then
        if [ "${allow_bootstrap}" != "1" ]; then
            echo "[INFO] uv is not installed; using pip. Pass --uv=true to install uv and speed this up." >&2
            return 0
        fi
        if ! bootstrap_uv; then
            echo "[WARNING] --uv was requested, but uv is not installed and could not be installed automatically." >&2
            echo "[WARNING] Continuing with pip. Install uv manually and re-run to use it." >&2
            return 0
        fi
    fi

    PIP_CMD="uv pip"
    PIP_UNINSTALL_CMD="uv pip uninstall"
    return 0
}
