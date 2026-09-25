# Optional external tools. Every block is guarded: this file must leave a working
# shell on a machine where none of them are installed.

# -- eza: ls with icons, git column and a tree mode ---------------------------
if (( $+commands[eza] )); then
    alias ls='eza --icons --group-directories-first'
    alias ll='eza --icons --group-directories-first --long --git --header'
    alias la='eza --icons --group-directories-first --long --git --all'
    alias l='eza --icons --group-directories-first --oneline'
    alias lt='eza --icons --tree --level=2'
fi

# -- bat: cat with syntax highlighting ----------------------------------------
# Ubuntu ships the binary as batcat; the name bat belongs to another package.
_anticrab_bat=''
(( $+commands[batcat] )) && _anticrab_bat=batcat
(( $+commands[bat] ))    && _anticrab_bat=bat
if [[ -n $_anticrab_bat ]]; then
    # --theme=ansi keeps bat inside the terminal's own 16 colours, so it matches
    # the JetBrains palette instead of bringing a second one.
    alias bat="$_anticrab_bat --theme=ansi"
    export MANPAGER="sh -c 'col -bx | $_anticrab_bat --language=man --plain --theme=ansi'"
    export MANROFFOPT='-c'   # without it groff and col disagree and the page smears
fi
unset _anticrab_bat
# `cat` itself is deliberately left alone: too much muscle memory, too many pipes.

# -- fzf: Ctrl-R history, Ctrl-T files, Alt-C directories ---------------------
if (( $+commands[fzf] )); then
    # Recoloured to JetBrains Dark; fzf's own defaults bring green and magenta
    # that clash with everything else on screen. bg:-1 keeps the terminal
    # background, including its transparency.
    # Palette slots, like the prompt — see 50-prompt.zsh for the table. bg:-1 and
    # gutter:-1 keep the terminal's own background, transparency included. Two
    # values have no slot: the selection background and the border, both taken
    # from the JetBrains theme.
    export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border=rounded --info=inline
        --color=bg:-1,gutter:-1,fg:7,fg+:15,hl:11,hl+:11
        --color=pointer:4,marker:10,prompt:4,spinner:4,info:8,header:8
        --color=bg+:#2b2d30,border:#393b40'
    export FZF_CTRL_R_OPTS='--preview "echo {}" --preview-window=down:3:wrap:hidden
        --bind "ctrl-/:toggle-preview"'

    if (( $+commands[fdfind] )); then
        export FZF_DEFAULT_COMMAND='fdfind --type f --hidden --follow --exclude .git'
        export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
        export FZF_ALT_C_COMMAND='fdfind --type d --hidden --follow --exclude .git'
    fi

    # Only in a session with a terminal. fzf's shipped integration snapshots the
    # whole `options` array and restores it with an eval on the way out; in a
    # shell with no tty that assignment tries to set the `zle` option and prints
    # "can't change option: zle" twice. The widgets are line-editor widgets, so
    # there is nothing to lose by skipping them where there is no line to edit.
    if [[ -t 0 ]]; then
        # fzf 0.48 added `fzf --zsh`. Older builds — Ubuntu 24.04 ships 0.44 —
        # print "unknown option" to *stdout* and still exit 0, so the output
        # cannot be trusted without checking the version first.
        autoload -Uz is-at-least
        _anticrab_fzf_version=${${=${"$(fzf --version 2>/dev/null)"}}[1]}
        if [[ -n $_anticrab_fzf_version ]] \
           && is-at-least 0.48 $_anticrab_fzf_version; then
            source <(fzf --zsh)
        else
            for _anticrab_f in \
                /usr/share/doc/fzf/examples/key-bindings.zsh \
                /usr/share/doc/fzf/examples/completion.zsh \
                /usr/share/fzf/key-bindings.zsh \
                /usr/share/fzf/completion.zsh
            do
                [[ -r $_anticrab_f ]] && source $_anticrab_f
            done
            unset _anticrab_f
        fi
        unset _anticrab_fzf_version
    fi
fi

# -- syntax highlighting, then autosuggestions --------------------------------
# Order matters both ways round: zsh-syntax-highlighting wraps every widget that
# exists when it is sourced, so it goes after the bindings in 40-keys.zsh, and
# zsh-autosuggestions asks to be sourced after it.
if [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets)
    typeset -gA ZSH_HIGHLIGHT_STYLES
    # Palette slots again, so the command line is coloured by the same sixteen as
    # everything else. The one exception is the keyword orange, which JetBrains
    # uses for if/for/while and which has no ANSI slot.
    ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=1'              # typo, red before Enter
    ZSH_HIGHLIGHT_STYLES[command]='fg=4'
    ZSH_HIGHLIGHT_STYLES[builtin]='fg=4'
    ZSH_HIGHLIGHT_STYLES[function]='fg=4'
    ZSH_HIGHLIGHT_STYLES[alias]='fg=4'
    ZSH_HIGHLIGHT_STYLES[precommand]='fg=4,italic'          # sudo, command, exec
    ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#cf8e6d'        # if, for, while
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=2'
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=2'
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=2'
    ZSH_HIGHLIGHT_STYLES[comment]='fg=8'
    ZSH_HIGHLIGHT_STYLES[globbing]='fg=11'
    ZSH_HIGHLIGHT_STYLES[redirection]='fg=5'
    ZSH_HIGHLIGHT_STYLES[commandseparator]='fg=5'
    ZSH_HIGHLIGHT_STYLES[path]='fg=7'
    ZSH_HIGHLIGHT_STYLES[default]='fg=7'
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#4e5157'  # dim enough to read past
    # history only: the completion strategy has to run the completion system on
    # every keystroke, which is exactly the latency this config is avoiding.
    ZSH_AUTOSUGGEST_STRATEGY=(history)
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    # → accepts the suggestion; Ctrl-Space does it without first walking to the
    # end of the line.
    bindkey '^ ' autosuggest-accept
fi
