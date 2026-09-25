# $ZDOTDIR/.zshrc — interactive shells only. From anticrab.zsh.
#
# Wiring only: the settings live in conf.d and are sourced in name order, so the
# ordering constraints are visible in the file names — options before
# completion, completion before the plugins that wrap editor widgets.

ANTICRAB_ZSH="${ZDOTDIR:-$HOME/.config/zsh}"

# (N) is the nullglob qualifier: an empty conf.d is not an error.
for _anticrab_conf in "$ANTICRAB_ZSH"/conf.d/*.zsh(N); do
    source "$_anticrab_conf"
done
unset _anticrab_conf

# Untracked, machine-specific escape hatch: tokens, one-off aliases, anything
# that must not reach git.
if [[ -r "$ANTICRAB_ZSH/local.zsh" ]]; then
    source "$ANTICRAB_ZSH/local.zsh"
fi

# Leave $? clean. The prompt paints ❯ red when the previous command failed, and
# a bare [[ ... ]] at the end of this file would count as one on the very first
# prompt of every shell.
true
