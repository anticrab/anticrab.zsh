# Completion.
#
# compinit is where a zsh start-up spends its time, so the dump is cached and
# fully rebuilt at most once a day. Every tmux pane pays the difference.

# LS_COLORS paints the completion menu, so it has to exist before the zstyles.
if (( $+commands[dircolors] )); then
    if [[ -r "$HOME/.dircolors" ]]; then
        eval "$(dircolors -b "$HOME/.dircolors")"
    else
        eval "$(dircolors -b)"
    fi
fi

zmodload zsh/complist        # arrow-key navigation inside the completion menu
autoload -Uz compinit

_anticrab_zcompdump="${XDG_CACHE_HOME:-$HOME/.cache}/zsh/zcompdump-${ZSH_VERSION}"
if [[ ! -d "${_anticrab_zcompdump:h}" ]]; then
    mkdir -p "${_anticrab_zcompdump:h}"
fi

# (#qN.mh-24): exists, is a plain file, modified less than 24 hours ago.
if [[ -n "$_anticrab_zcompdump"(#qN.mh-24) ]]; then
    compinit -C -d "$_anticrab_zcompdump"   # trust the dump, skip the rescan
else
    compinit -d "$_anticrab_zcompdump"
    # Byte-compile it so the next shell maps it instead of parsing it.
    if [[ ! -e "$_anticrab_zcompdump.zwc" \
       || "$_anticrab_zcompdump" -nt "$_anticrab_zcompdump.zwc" ]]; then
        zcompile -R -- "$_anticrab_zcompdump" 2>/dev/null
    fi
fi
unset _anticrab_zcompdump

setopt complete_in_word  # completing in the middle of a word works …
setopt always_to_end     # … and leaves the cursor after the completion
setopt auto_menu         # a second Tab opens the menu
unsetopt menu_complete   # but the first Tab never inserts a guess blindly

zstyle ':completion:*' menu select
# case-insensitive first, then partial words, then substrings: `cd Pro<Tab>`
# finds projects, `cd a.nv<Tab>` finds anticrab.nvim.
zstyle ':completion:*' matcher-list \
    'm:{[:lower:][:upper:]}={[:upper:][:lower:]}' 'r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{#6f737a}%d%f'
zstyle ':completion:*:warnings'     format '%F{#f75464}no matches%f'
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/compcache"
# kill <Tab> shows the process table and lets the arrows pick a pid.
zstyle ':completion:*:*:*:*:processes' command 'ps -u $USER -o pid,user,comm -w'
