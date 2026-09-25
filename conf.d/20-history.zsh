# History.
#
# bash kept 1000 lines in memory and 2000 on disk (~/.bashrc:19-20) and wrote
# them only when the shell exited — which is why Ctrl-R never found yesterday's
# commands in a tmux pane that stays open for weeks.

HISTFILE="${XDG_STATE_HOME:-$HOME/.local/state}/zsh/history"
if [[ ! -d "${HISTFILE:h}" ]]; then
    mkdir -p "${HISTFILE:h}"
fi

HISTSIZE=200000   # lines kept in memory
SAVEHIST=200000   # lines kept on disk

setopt extended_history     # store the start time and duration, not just the text
setopt share_history        # write at once, and import what other panes wrote
setopt hist_ignore_all_dups # a repeated command keeps only its newest entry
setopt hist_ignore_space    # a leading space keeps a command out of the history
setopt hist_reduce_blanks   # collapse redundant whitespace before storing
setopt hist_verify          # !! and !$ expand onto the line; Enter is a second step

# share_history is what makes the history useful across tmux panes, and it is
# also what mixes their commands into plain Up-arrow. The antidote is the prefix
# search bound in 40-keys.zsh. To opt out entirely, put this in local.zsh:
#     unsetopt share_history
