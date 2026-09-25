#!/usr/bin/env bash
# Bootstrap anticrab.zsh: ~/.zshenv plus ~/.config/zsh/{.zshrc,conf.d}.
# Idempotent — safe to run repeatedly.
#
# Modes (mutually exclusive):
#   (default)   copy the files into place.
#   --symlink   symlink them back to this repo, so edits here take effect at
#               once. This is how the other anticrab.* configs are installed on
#               this machine.
#
# In both modes anything already in place that this script did not write is moved
# to a timestamped .bak-<stamp> next to it first, so a hand-rolled config is
# never silently lost. sudo is never called: missing packages are reported with
# the exact apt line to run.

set -euo pipefail

REPO_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
TARGET_DIR="$CONFIG_HOME/zsh"
STAMP="$( date +%Y%m%d-%H%M%S )"

MODE="copy"
for arg in "$@"; do
    case "$arg" in
        --symlink) MODE="symlink" ;;
        --copy)    MODE="copy" ;;
        -h|--help)
            cat <<USAGE
Usage: install.sh [--symlink]

Without flags: copy zshenv and the config into place. With --symlink: symlink
them back to this repo, so editing the repo takes effect immediately.

Installs:
  ~/.zshenv                    (sets ZDOTDIR; the only file placed in \$HOME)
  ~/.config/zsh/.zshrc
  ~/.config/zsh/conf.d/*.zsh

Creates ~/.cache/zsh and ~/.local/state/zsh, and on a first run seeds the zsh
history from ~/.bash_history. Never calls sudo.
USAGE
            exit 0 ;;
        *) echo "Unknown argument: $arg (try --help)" >&2; exit 1 ;;
    esac
done

CHANGED=0
note() { printf '  %s\n' "$*"; }

backup() {   # path
    mv "$1" "$1.bak-$STAMP"
    note "kept the previous $1 as $1.bak-$STAMP"
    CHANGED=1
}

install_copy() {   # src dst
    local src=$1 dst=$2
    mkdir -p "$( dirname "$dst" )"
    if [[ -L $dst ]]; then
        rm "$dst"                      # a link from an earlier --symlink run
    elif [[ -f $dst ]]; then
        cmp -s "$src" "$dst" && return 0
        backup "$dst"
    fi
    cp "$src" "$dst"
    note "installed $dst"
    CHANGED=1
}

# Every file in $2 is present in $1 and identical — i.e. $2 is our own copy and
# holds nothing of the user's.
dir_is_our_copy() {   # src-dir dst-dir
    local src=$1 dst=$2 entry
    for entry in "$dst"/*; do
        [[ -e $entry ]] || continue
        cmp -s "$entry" "$src/${entry##*/}" || return 1
    done
    return 0
}

install_link() {   # src dst
    local src=$1 dst=$2
    mkdir -p "$( dirname "$dst" )"
    if [[ -L $dst ]]; then
        [[ "$( readlink "$dst" )" == "$src" ]] && return 0
        rm "$dst"
    elif [[ -d $dst ]]; then
        if dir_is_our_copy "$src" "$dst"; then
            rm -rf "$dst"
        else
            backup "$dst"
        fi
    elif [[ -e $dst ]]; then
        if cmp -s "$src" "$dst"; then
            rm "$dst"                  # our own copy, nothing to preserve
        else
            backup "$dst"
        fi
    fi
    ln -s "$src" "$dst"
    note "linked $dst -> $src"
    CHANGED=1
}

sync_dir() {   # src-dir dst-dir  (copy mode)
    local src=$1 dst=$2 entry name
    [[ -L $dst ]] && { rm "$dst"; CHANGED=1; }
    mkdir -p "$dst"
    for entry in "$src"/*.zsh; do
        install_copy "$entry" "$dst/${entry##*/}"
    done
    # Anything left behind belongs to an older layout. Move it aside instead of
    # leaving a renamed config file sourced for ever.
    for entry in "$dst"/*.zsh; do
        [[ -e $entry ]] || continue
        name=${entry##*/}
        [[ -e "$src/$name" ]] || backup "$entry"
    done
}

# -- config -------------------------------------------------------------------

echo "anticrab.zsh -> $TARGET_DIR ($MODE mode)"

if [[ $MODE == symlink ]]; then
    install_link "$REPO_DIR/zshenv" "$HOME/.zshenv"
    install_link "$REPO_DIR/zshrc"  "$TARGET_DIR/.zshrc"
    install_link "$REPO_DIR/conf.d" "$TARGET_DIR/conf.d"
else
    install_copy "$REPO_DIR/zshenv" "$HOME/.zshenv"
    install_copy "$REPO_DIR/zshrc"  "$TARGET_DIR/.zshrc"
    sync_dir     "$REPO_DIR/conf.d" "$TARGET_DIR/conf.d"
fi

for dir in "$CACHE_HOME/zsh" "$STATE_HOME/zsh"; do
    [[ -d $dir ]] || { mkdir -p "$dir"; note "created $dir"; CHANGED=1; }
done

# -- history ------------------------------------------------------------------
# First run only: carry the bash history over, so Ctrl-R is not empty on day one.
HISTORY_FILE="$STATE_HOME/zsh/history"
if [[ ! -e $HISTORY_FILE && -s "$HOME/.bash_history" ]]; then
    cp "$HOME/.bash_history" "$HISTORY_FILE"
    note "seeded $HISTORY_FILE from ~/.bash_history ($( wc -l < "$HISTORY_FILE" ) lines)"
    CHANGED=1
fi

(( CHANGED )) || note "already up to date"

# -- packages -----------------------------------------------------------------
# Reported, never installed: this script does not ask for a password.
package_installed() {   # package
    if command -v dpkg-query >/dev/null 2>&1; then
        [[ "$( dpkg-query -W -f='${db:Status-Status}' "$1" 2>/dev/null )" == installed ]]
    else
        command -v "$1" >/dev/null 2>&1
    fi
}

MISSING=()
for pkg in zsh zsh-autosuggestions zsh-syntax-highlighting fzf eza bat; do
    package_installed "$pkg" || MISSING+=("$pkg")
done

echo
if (( ${#MISSING[@]} )); then
    echo "Missing packages: ${MISSING[*]}"
    echo "  sudo apt install -y ${MISSING[*]}"
    echo
fi

# -- next steps ---------------------------------------------------------------
ZSH_BIN="$( command -v zsh || echo /usr/bin/zsh )"
cat <<NEXT
Next steps:
  1. make zsh the login shell (asks for your password, this script will not):
       chsh -s $ZSH_BIN
  2. anticrab.tmux and anticrab.wezterm must point at zsh as well:
       tmux.conf   default-shell / default-command
       wezterm.lua default_prog
  3. open a new pane, or run:  exec $ZSH_BIN -l

bash is untouched: 'exec bash -l' returns to it at any time.
NEXT
