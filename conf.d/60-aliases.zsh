# Aliases that need nothing installed. The eza/bat ones live in 70-tools.zsh so
# this file stays true on a machine without them.

# Carried over from ~/.bashrc, which is left untouched as the fallback shell.
alias ls='ls --color=auto'
alias ll='ls -alF'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias egrep='grep -E --color=auto'
alias fgrep='grep -F --color=auto'
alias zvim='nvim'

# Desktop notification when a long command finishes: `make build; alert`
alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(fc -ln -1 | sed -e '\''s/[;&|]\s*alert$//'\'')"'

# Re-read the whole config without opening a new pane.
alias reload='exec zsh -l'

# Personal aliases belong in local.zsh next to this directory — it is untracked,
# so nothing there has to be defensible to anyone.
