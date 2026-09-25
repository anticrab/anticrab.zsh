# Shell behaviour. Sourced first: 30-completion.zsh relies on the (#q...) glob
# qualifier, which needs extended_glob to be on already.

# -- moving around ------------------------------------------------------------
setopt auto_cd            # a bare `anticrab.nvim` cds into it
setopt auto_pushd         # every cd pushes onto the directory stack …
setopt pushd_ignore_dups  # … without piling up duplicates
setopt pushd_silent       # … and without printing the stack every time
cdpath=("$HOME/projects") # `cd anticrab.tmux` works from any directory

# -- globbing -----------------------------------------------------------------
# extended_glob buys **/*.lua, *(.) files only, *(/) dirs only, *(om[1]) newest
# first, and ^pattern negation.
setopt extended_glob
# …and nomatch off keeps bash's behaviour for arguments that merely look like
# globs: `git show HEAD^`, `pip install 'foo[bar]'` and `curl 'u?a=b'` are passed
# through literally instead of dying with "no matches found".
unsetopt nomatch

# -- terminal sanity ----------------------------------------------------------
setopt interactive_comments # `# note` at a prompt is a comment, as in bash
unsetopt flow_control       # Ctrl-S stops freezing the terminal
unsetopt beep
setopt long_list_jobs       # jobs are listed with their pids

# Ctrl-W should eat one path segment, not the whole argument, so / - . = are word
# separators here. zsh's default is '*?_-.[]~=/&;!#$%^(){}<>'.
WORDCHARS='*?_[]~&;!#$%^(){}<>'
