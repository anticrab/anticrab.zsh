# ~/.zshenv — from anticrab.zsh. The only file this config puts in $HOME.
#
# zsh reads $ZDOTDIR/.zshenv for every shell it starts (interactive or not,
# login or not) and $ZDOTDIR defaults to $HOME, so this is the one startup file
# whose location is fixed. Its job is to point zsh somewhere tidier and to set
# what even non-interactive shells need. Keep it silent — it runs for `zsh -c`
# as well, and stray output here breaks scp and rsync.

export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"

export ZDOTDIR="$XDG_CONFIG_HOME/zsh"

# typeset -U keeps the array unique, so nesting shells — or /etc/zsh/zprofile
# sourcing /etc/profile again for a login shell — cannot grow PATH without end.
typeset -U path PATH
path=(
    "$HOME/.local/bin"   # zvim-open and friends, installed by anticrab.wezterm
    $path
)
# nvim is a snap. /etc/profile adds /snap/bin, but only for login shells, and
# $EDITOR has to resolve in every shell git might spawn.
if [[ -d /snap/bin ]]; then
    path+=(/snap/bin)
fi
export PATH

export EDITOR=nvim
export VISUAL=nvim

# Keep ~/.lesshst from appearing; less history is of no use here.
export LESSHISTFILE=-
