# Key bindings.

# Explicitly emacs. zsh infers vi mode when $EDITOR or $VISUAL matches *vi*, and
# ours is nvim — without this line the command line starts in normal mode and
# every letter does something surprising. Swap for `bindkey -v` to get vi mode
# on purpose.
bindkey -e

# Up and Down search the history for what is already typed: `git com` then Up
# walks only the commits. This is what keeps share_history from making plain
# Up-arrow useless across tmux panes.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search     # cursor keys, normal mode
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search     # … and application mode
bindkey '^[OB' down-line-or-beginning-search

# The sequences wezterm actually sends. zsh's default keymap knows some of them
# and not others, which is why Home types a tilde in an unconfigured zsh.
bindkey '^[[H'    beginning-of-line
bindkey '^[[F'    end-of-line
bindkey '^[[1~'   beginning-of-line
bindkey '^[[4~'   end-of-line
bindkey '^[[3~'   delete-char
bindkey '^[[1;5C' forward-word    # Ctrl-Right
bindkey '^[[1;5D' backward-word   # Ctrl-Left
bindkey '^[[1;3C' forward-word    # Alt-Right
bindkey '^[[1;3D' backward-word   # Alt-Left
bindkey '^[[Z'    reverse-menu-complete  # Shift-Tab steps back through the menu

# Ctrl-X Ctrl-E opens the half-written command in nvim; :wq runs it. The way out
# of fighting quotes on one line.
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey '^X^E' edit-command-line
