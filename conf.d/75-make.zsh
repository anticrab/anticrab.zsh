# `m` — run a target of this project's Makefile, chosen from a list.
#
# Four docker projects on this machine name the same action four different ways:
# `make exec` in fmr-sim, `make in` in retrofit_amr and ros2-sim, `make attach`
# in rms-test. Only two of the four have a `help` target. Nothing here is
# configured per project — the list comes out of the Makefile itself, with the
# ## descriptions where they exist and bare target names where they do not.
#
# Plain functions from here on: 70-tools.zsh has already sourced
# zsh-syntax-highlighting, which wraps the editor widgets that exist when it runs.

# Directory of the nearest Makefile at or above $PWD. Walks the path in the
# shell, so it costs no fork.
__anticrab_make_root() {
    local dir=$PWD
    while true; do
        if [[ -f $dir/Makefile || -f $dir/makefile || -f $dir/GNUmakefile ]]; then
            REPLY=$dir
            return 0
        fi
        [[ -z $dir ]] && { REPLY=''; return 1 }
        dir=${dir%/*}
    done
}

# One line per target: the name, then its ## description when it has one.
# Parsed in zsh rather than with awk because Ubuntu's awk is mawk, whose match()
# has no capture groups — and this way it is one read instead of a fork.
__anticrab_make_targets() {   # path to a Makefile
    local line name desc
    while IFS= read -r line; do
        # A target starts at column 0 with a name and a colon. Recipes are
        # indented, .PHONY starts with a dot, and `VAR := value` has a space
        # before the colon — or, without one, the := that is checked next.
        [[ $line == [A-Za-z0-9_][A-Za-z0-9_.-]#:* ]] || continue
        [[ $line == *:=* ]] && continue
        name=${line%%:*}
        desc=''
        if [[ $line == *'##'* ]]; then
            desc=${line#*\#\#}
            desc=${desc## }
        fi
        print -r -- "${(r:16:)name} $desc"
    done < $1
}

m() {
    if ! __anticrab_make_root; then
        print -u2 -- "m: no Makefile at or above $PWD"
        return 1
    fi
    local root=$REPLY

    # With an argument it is plain `make`, so muscle memory keeps working.
    if (( $# )); then
        make -C $root "$@"
        return
    fi

    local makefile
    for makefile in $root/Makefile $root/makefile $root/GNUmakefile; do
        [[ -f $makefile ]] && break
    done

    local -a targets
    targets=( ${(f)"$(__anticrab_make_targets $makefile)"} )
    if (( ! $#targets )); then
        print -u2 -- "m: ${makefile:t} defines no targets"
        return 1
    fi

    local pick
    if (( $+commands[fzf] )); then
        pick=$(print -rl -- $targets | fzf --prompt='make ' --height=40% --reverse) || return
    else
        print -rl -- $targets     # no fzf: this is still a better `make help`
        return 0
    fi
    [[ -n $pick ]] || return

    local target=${pick%% *}
    print -s "make $target"       # so Up-arrow repeats it like anything else
    make -C $root $target
}
