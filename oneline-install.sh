#!/bin/sh
# DEEPX dx-compiler one-line installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/DEEPX-AI/dx-compiler/main/oneline-install.sh | sh
#
# Env overrides:
#   DX_VERSION=X.Y.Z      pin the dx-com release (default: newest on PyPI)
#   DX_INSTALL_DIR=<dir>  install root (default: ~/deepx)
#   DX_BIN_DIR=<dir>      where the dxcom launcher is linked (default: ~/.local/bin)
#   DX_NO_UV=1            skip uv and install with pip
#   UV_PIN=X.Y.Z          uv release to bootstrap (default below)
#
# Installs the dx-com compiler from PyPI into its own virtualenv. dx-com declares
# its own dependencies (onnx, onnxruntime, torch, ...), so pip resolves everything;
# expect a multi-GB download on a first install.
set -eu

INSTALL_ROOT="${DX_INSTALL_DIR:-$HOME/deepx}"
VENV="$INSTALL_ROOT/venv-dx-compiler"
BIN_DIR="${DX_BIN_DIR:-$HOME/.local/bin}"

log()  { printf '\033[1;34m[dx-compiler]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[dx-compiler][WARN]\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31m[dx-compiler][ERROR]\033[0m %s\n' "$1" >&2; exit 1; }

# Pinned so a run never pulls an unreviewed uv release.
UV_PIN="${UV_PIN:-0.12.2}"
UV_BOOTSTRAP_DIR="${UV_BOOTSTRAP_DIR:-$HOME/.local/bin}"

# Make uv available, or return non-zero so the caller falls back to pip. uv is
# fetched as a standalone binary rather than with `pip install uv`: Debian and
# Ubuntu mark their system Python PEP 668 externally-managed, which rejects
# `pip install` even with --user, and getting past that needs
# --break-system-packages, which an installer has no business doing to a distro
# Python. The standalone binary touches no Python installation at all.
ensure_uv() {
    command -v uv >/dev/null 2>&1 && return 0
    command -v curl >/dev/null 2>&1 || return 1

    log "Installing uv ${UV_PIN} to ${UV_BOOTSTRAP_DIR}"
    mkdir -p "$UV_BOOTSTRAP_DIR" || return 1
    # Download, then run — not `curl | sh`. A pipeline reports the last
    # command's status, so a failed download would be handed to sh as empty
    # input and "succeed". A file lets curl's own exit status be checked, and
    # a partial download is never executed.
    _inst="$(mktemp)" || return 1
    # Cleared below; the trap only covers an interrupt between here and the rm.
    trap 'rm -f "$_inst"' EXIT INT TERM HUP
    if ! curl -LsSf "https://astral.sh/uv/${UV_PIN}/install.sh" -o "$_inst"; then
        rm -f "$_inst"; trap - EXIT INT TERM HUP; return 1
    fi
    # UV_NO_MODIFY_PATH keeps the installer out of the user's shell rc files.
    # The installer's own progress goes to stderr so it stays separate from this
    # script's stdout, which a caller may be capturing or piping.
    env UV_INSTALL_DIR="$UV_BOOTSTRAP_DIR" UV_NO_MODIFY_PATH=1 sh "$_inst" >&2
    _rc=$?
    rm -f "$_inst"; trap - EXIT INT TERM HUP
    [ "$_rc" -eq 0 ] || return 1

    command -v uv >/dev/null 2>&1 && return 0
    PATH="$UV_BOOTSTRAP_DIR:$PATH"; export PATH
    command -v uv >/dev/null 2>&1
}

main() {
    command -v python3 >/dev/null 2>&1 || die "python3 is required"

    # dx-com publishes wheels for CPython 3.8 through 3.14 only.
    python3 -c 'import sys; raise SystemExit(0 if (3,8) <= sys.version_info[:2] < (3,15) else 1)' \
        || die "unsupported Python $(python3 -V 2>&1 | cut -d' ' -f2); dx-com requires >=3.8,<3.15"

    REQ="dx-com"
    if [ -n "${DX_VERSION:-}" ]; then
        # Spliced into a pip requirement string; keep it to a plain version.
        case "$DX_VERSION" in
            *[!0-9A-Za-z.-]*) die "invalid DX_VERSION: $DX_VERSION" ;;
        esac
        REQ="dx-com==$DX_VERSION"
    fi

    # dx-com depends on opencv-python, whose cv2 extension links against X and GL
    # system libraries. The repo's install_prerequisites.sh apt-installs these; pip
    # cannot, so without them dxcom crashes on import with
    # "libxcb.so.1: cannot open shared object file".
    PREREQ="libgl1-mesa-dev libglib2.0-0"
    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        command -v sudo >/dev/null 2>&1 \
            || die "need root to install system packages. Run as root, or install them yourself and re-run: apt-get install -y $PREREQ"
        SUDO="sudo"
    fi
    command -v apt-get >/dev/null 2>&1 \
        || die "this installer expects Debian/Ubuntu. Install the equivalents of '$PREREQ' for your distribution, then re-run."
    log "Installing system prerequisites ($PREREQ)"
    # Non-fatal: the install below reports its own failure if the index is the
    # reason a package cannot be resolved.
    $SUDO apt-get update -qq || warn "apt-get update failed; proceeding with the existing package index"
    # shellcheck disable=SC2086 # PREREQ is a deliberate multi-package word list
    $SUDO apt-get install -y --no-install-recommends $PREREQ \
        || die "failed to install system prerequisites: $PREREQ"

    # Test for a usable interpreter rather than a directory, so a venv left
    # half-created by an interrupted run reports something actionable.
    if [ -d "$VENV" ] && [ ! -x "$VENV/bin/python" ]; then
        die "$VENV exists but is not a usable venv — remove it and re-run: rm -rf '$VENV'"
    fi
    # uv resolves and downloads wheels far faster than pip, which matters here
    # because dx-com drags in torch and the CUDA runtime. A uv problem degrades
    # to pip rather than failing the install — both paths install the same
    # packages into the same venv, so the outcome does not depend on which ran.
    if [ "${DX_NO_UV:-0}" = "1" ]; then
        INSTALLER="pip"
    elif ensure_uv; then
        INSTALLER="uv"
    else
        INSTALLER="pip"
        warn "uv unavailable; falling back to pip (slower)"
    fi

    if [ ! -e "$VENV/bin/python" ]; then
        log "Creating venv at $VENV"
        mkdir -p "$INSTALL_ROOT"
        if [ "$INSTALLER" = "uv" ]; then
            # --seed puts pip inside the venv; uv omits it otherwise, and users
            # expect to be able to pip install into their own environment later.
            uv venv --seed --python python3 "$VENV" \
                || die "uv venv failed at $VENV"
        else
            python3 -m venv "$VENV" \
                || die "venv creation failed — install it first: sudo apt-get install python3-venv"
        fi
    fi

    log "Installing ${REQ} with ${INSTALLER} (this pulls torch and friends, so it takes a while)"
    if [ "$INSTALLER" = "uv" ]; then
        uv pip install --python "$VENV/bin/python" "$REQ" \
            || die "uv pip install failed for ${REQ}"
    else
        # set -e would otherwise abort the whole install because pip could not
        # upgrade itself, which says nothing about whether dx-com can be installed.
        "$VENV/bin/pip" install --upgrade pip >/dev/null \
            || warn "pip self-upgrade failed; continuing with the existing pip"
        "$VENV/bin/pip" install "$REQ" || die "pip install failed for ${REQ}"
    fi

    [ -x "$VENV/bin/dxcom" ] || die "dx-com installed but the dxcom launcher is missing"
    # Run the launcher rather than importing dx_com: cv2 is reached through
    # dx_com.cli, not dx_com itself, so an import check still passes when the X/GL
    # system libraries are absent and dxcom would die on its first real use.
    if ! _out="$("$VENV/bin/dxcom" --help 2>&1)"; then
        printf '%s\n' "$_out" >&2
        die "dx-com installed but 'dxcom --help' failed — see the output above"
    fi

    # Link the launcher onto PATH so the compiler is usable without knowing the
    # venv exists. A non-writable BIN_DIR is a warning, not a failure: the venv
    # itself is complete either way.
    if [ -e "$BIN_DIR/dxcom" ] && [ ! -L "$BIN_DIR/dxcom" ]; then
        warn "$BIN_DIR/dxcom already exists and is not a symlink; replacing it"
    fi
    if mkdir -p "$BIN_DIR" 2>/dev/null && ln -sf "$VENV/bin/dxcom" "$BIN_DIR/dxcom" 2>/dev/null; then
        log "Linked dxcom -> $BIN_DIR/dxcom"
        case ":$PATH:" in
            *":$BIN_DIR:"*) ;;
            *) warn "$BIN_DIR is not on PATH; add it, or call $VENV/bin/dxcom directly" ;;
        esac
    else
        warn "could not link into $BIN_DIR; call $VENV/bin/dxcom directly"
    fi

    _ver="$("$VENV/bin/python" -c 'import importlib.metadata as m; print(m.version("dx-com"))' 2>/dev/null || echo unknown)"
    log "Done. dx-com ${_ver} installed at $VENV"
    log "Run 'dxcom --help', or activate the venv with:  . $VENV/bin/activate"
}

main "$@"
