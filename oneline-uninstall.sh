#!/bin/sh
# DEEPX dx-compiler one-line uninstaller
#
# Removes what oneline-install.sh created:
#   curl -fsSL https://raw.githubusercontent.com/DEEPX-AI/dx-compiler/main/oneline-uninstall.sh | sh
#
# Env overrides (must match the values used at install time):
#   DX_INSTALL_DIR=<dir>  install root (default: ~/deepx)
#   DX_BIN_DIR=<dir>      where the dxcom launcher was linked (default: ~/.local/bin)
#
# Left alone on purpose, because this installer is not their only owner: the uv
# binary in ~/.local/bin, and the libgl1-mesa-dev / libglib2.0-0 system packages.
# Both are reported at the end so they can be removed by hand if wanted.
set -eu

INSTALL_ROOT="${DX_INSTALL_DIR:-$HOME/deepx}"
VENV="$INSTALL_ROOT/venv-dx-compiler"
BIN_DIR="${DX_BIN_DIR:-$HOME/.local/bin}"
UV_BOOTSTRAP_DIR="${UV_BOOTSTRAP_DIR:-$HOME/.local/bin}"

log()  { printf '\033[1;34m[dx-compiler]\033[0m %s\n' "$1"; }
warn() { printf '\033[1;33m[dx-compiler][WARN]\033[0m %s\n' "$1" >&2; }
die()  { printf '\033[1;31m[dx-compiler][ERROR]\033[0m %s\n' "$1" >&2; exit 1; }

main() {
    REMOVED=0

    # Remove the launcher first, and only when it still points into the venv we
    # are about to delete. A dxcom that some other install owns must survive, and
    # removing it before the venv means an interrupted run never leaves a link
    # dangling into a deleted directory.
    if [ -L "$BIN_DIR/dxcom" ]; then
        _target="$(readlink -f "$BIN_DIR/dxcom" 2>/dev/null || true)"
        case "$_target" in
            "$VENV"/*)
                rm -f "$BIN_DIR/dxcom"
                log "Removed launcher $BIN_DIR/dxcom"
                REMOVED=1
                ;;
            *)
                warn "$BIN_DIR/dxcom points outside $VENV; leaving it alone"
                ;;
        esac
    elif [ -e "$BIN_DIR/dxcom" ]; then
        warn "$BIN_DIR/dxcom is not a symlink; leaving it alone"
    fi

    if [ -d "$VENV" ]; then
        # Delete only something that really is a virtualenv. DX_INSTALL_DIR is
        # caller-supplied and ends up in an rm -rf, so a wrong value must fail
        # loudly rather than take a directory with it.
        [ -f "$VENV/pyvenv.cfg" ] \
            || die "$VENV exists but has no pyvenv.cfg, so it does not look like a virtualenv — remove it by hand if that is what you meant"
        rm -rf "$VENV"
        log "Removed venv $VENV"
        REMOVED=1
        # Drop the install root too, but only if this was the only thing in it.
        rmdir "$INSTALL_ROOT" 2>/dev/null && log "Removed empty $INSTALL_ROOT" || true
    fi

    if [ "$REMOVED" -eq 0 ]; then
        log "Nothing to remove: no venv at $VENV and no launcher at $BIN_DIR/dxcom"
        log "If you installed elsewhere, re-run with the same DX_INSTALL_DIR and DX_BIN_DIR"
        return 0
    fi

    log "dx-compiler removed."
    # Check the bootstrap directory as well as PATH: the installer deliberately
    # does not touch shell rc files, so uv is often present but not on PATH here,
    # and this notice would silently never appear.
    _uv="$(command -v uv 2>/dev/null || true)"
    [ -n "$_uv" ] || { [ -x "$UV_BOOTSTRAP_DIR/uv" ] && _uv="$UV_BOOTSTRAP_DIR/uv"; }
    if [ -n "$_uv" ]; then
        log "uv is still installed at $_uv — left in place, since it is a general-purpose tool"
    fi
    log "System packages libgl1-mesa-dev and libglib2.0-0 were left installed; other software may need them"
}

main "$@"
