#!/bin/sh
# Install sonos-announce so it can be run from any directory.
#
#   From a clone:   ./install.sh
#   Without one:    curl -fsSL https://raw.githubusercontent.com/guilhermechapiewski/sonos-announcer/main/install.sh | sh
#
# Options (or environment variables):
#   --dir DIR    install into DIR              (BIN_DIR=DIR)
#   --link       symlink instead of copying, so `git pull` updates it (from a clone only)
#   --uninstall  remove the installed command (add --purge to also delete ~/.sonos-announce)
set -eu

NAME="sonos-announce"
REPO_RAW="https://raw.githubusercontent.com/guilhermechapiewski/sonos-announcer/main"
BIN_DIR="${BIN_DIR:-}"
LINK=0
UNINSTALL=0
PURGE=0

say()  { printf '%s\n' "$*"; }
warn() { printf '%s\n' "$*" >&2; }
die()  { warn "error: $*"; exit 1; }

while [ $# -gt 0 ]; do
    case "$1" in
        --dir)       [ $# -ge 2 ] || die "--dir needs a directory"; BIN_DIR="$2"; shift 2 ;;
        --dir=*)     BIN_DIR="${1#--dir=}"; shift ;;
        --link)      LINK=1; shift ;;
        --uninstall) UNINSTALL=1; shift ;;
        --purge)     PURGE=1; shift ;;
        -h|--help)   sed -n '2,/^set /p' "$0" | grep '^#' | sed 's/^# \{0,1\}//'; exit 0 ;;
        *)           die "unknown option: $1 (see --help)" ;;
    esac
done

in_path() {
    case ":$PATH:" in *":$1:"*) return 0 ;; *) return 1 ;; esac
}

# Pick the install directory: the first of these that is already on PATH and
# writable without sudo, else ~/.local/bin (which we then explain how to add).
choose_dir() {
    for d in /opt/homebrew/bin /usr/local/bin "$HOME/.local/bin" "$HOME/bin"; do
        if in_path "$d" && [ -d "$d" ] && [ -w "$d" ]; then
            printf '%s\n' "$d"
            return
        fi
    done
    printf '%s\n' "$HOME/.local/bin"
}

if [ "$UNINSTALL" = 1 ]; then
    if [ -n "$BIN_DIR" ]; then
        dirs="$BIN_DIR"
    else
        dirs="/opt/homebrew/bin /usr/local/bin $HOME/.local/bin $HOME/bin"
    fi
    removed=0
    for d in $dirs; do
        # Only remove our own script (or a symlink to it), never a stranger's file.
        if [ -L "$d/$NAME" ] || { [ -f "$d/$NAME" ] && head -n 1 "$d/$NAME" | grep -q 'uv run'; }; then
            rm -f "$d/$NAME" && say "Removed $d/$NAME" && removed=1
        fi
    done
    [ "$removed" = 1 ] || say "$NAME was not installed."
    if [ "$PURGE" = 1 ] && [ -f "$HOME/.sonos-announce" ]; then
        rm -f "$HOME/.sonos-announce" && say "Removed $HOME/.sonos-announce"
    elif [ -f "$HOME/.sonos-announce" ]; then
        say "Kept your settings in $HOME/.sonos-announce (use --purge to remove them too)."
    fi
    exit 0
fi

# --- prerequisites -----------------------------------------------------------

[ "$(uname -s)" = "Darwin" ] || warn "warning: speech uses macOS 'say'; on other systems only --sound will work."

if ! command -v uv >/dev/null 2>&1; then
    warn "$NAME needs uv (https://docs.astral.sh/uv/) to run. Install it with one of:"
    if command -v brew >/dev/null 2>&1; then
        warn "  brew install uv"
    fi
    warn "  curl -LsSf https://astral.sh/uv/install.sh | sh"
    die "uv not found; install it, open a new terminal, and run this installer again"
fi

# --- install -----------------------------------------------------------------

[ -n "$BIN_DIR" ] || BIN_DIR="$(choose_dir)"
mkdir -p "$BIN_DIR" || die "cannot create $BIN_DIR"
[ -w "$BIN_DIR" ] || die "$BIN_DIR is not writable; pick another with --dir, or run with sudo"
TARGET="$BIN_DIR/$NAME"

# Use the copy next to this script when run from a clone; otherwise download.
SRC=""
case "$0" in
    */*) [ -f "$(dirname "$0")/$NAME" ] && SRC="$(cd "$(dirname "$0")" && pwd)/$NAME" ;;
    *)   [ -f "./$NAME" ] && [ -f "./install.sh" ] && SRC="$(pwd)/$NAME" ;;
esac

rm -f "$TARGET"
if [ -n "$SRC" ] && [ "$LINK" = 1 ]; then
    ln -s "$SRC" "$TARGET"
    say "Linked $TARGET -> $SRC"
elif [ -n "$SRC" ]; then
    cp "$SRC" "$TARGET"
    say "Installed $TARGET"
else
    [ "$LINK" = 0 ] || die "--link only works when running install.sh from a clone"
    command -v curl >/dev/null 2>&1 || die "curl is needed to download $NAME"
    TMP="$(mktemp)"
    trap 'rm -f "$TMP"' EXIT
    curl -fsSL "$REPO_RAW/$NAME" -o "$TMP" || die "download failed"
    head -n 1 "$TMP" | grep -q '^#!.*uv run' || die "downloaded file doesn't look like $NAME"
    mv "$TMP" "$TARGET"
    trap - EXIT
    say "Installed $TARGET (downloaded from GitHub)"
fi
chmod +x "$TARGET" 2>/dev/null || true

# Download the Python dependencies now, so the first announcement isn't slow.
say "Fetching dependencies..."
if ! "$TARGET" --help >/dev/null 2>&1; then
    warn "warning: '$TARGET --help' failed; try running it to see why."
fi

# --- PATH --------------------------------------------------------------------

if in_path "$BIN_DIR"; then
    say ""
    say "Done! Try:  $NAME --list"
else
    case "${SHELL:-}" in
        */zsh)  RC="$HOME/.zshrc" ;;
        */bash) RC="$HOME/.bash_profile" ;;
        *)      RC="your shell's startup file" ;;
    esac
    say ""
    say "Almost done: $BIN_DIR is not on your PATH yet. Add it with:"
    say ""
    say "  echo 'export PATH=\"$BIN_DIR:\$PATH\"' >> $RC"
    say ""
    say "then open a new terminal and try:  $NAME --list"
fi
