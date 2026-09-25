# The prompt:
#
#   ~/projects/anticrab.nvim   main +2 ?1 ↑1                          1.4s
#   ❯ git commit -m "fix(ui): count means real lines"
#
# Both lines are $PROMPT, reassigned by the precmd hook at the bottom. Printing
# the context line from precmd instead — the way most hand-rolled two-line
# prompts do it — would leave Ctrl-L redrawing only the arrow, and would strand
# that line when the window is resized.
#
# Assigning $PROMPT also means prompt_subst is not needed: with prompt_subst the
# text substituted from a variable is *not* rescanned for prompt escapes, which
# is the usual reason a hand-rolled prompt shows a literal %F{...}.
#
# Every glyph below is one JetBrainsMono Nerd Font draws itself. That is not a
# detail: wezterm silently falls back to DejaVu Sans Mono for what the font
# lacks, and the substitute keeps the cell width but brings another typeface's
# stroke weight into a line of otherwise uniform text. U+271A HEAVY GREEK CROSS
# and U+21E1/U+21E3 (the double arrows) were all fallbacks and looked smudged
# beside the digits; + ? ↑ ↓ … and ❯ are native. Check any replacement with:
#     wezterm ls-fonts --text '<glyph>'   # the font named must be JetBrainsMono

zmodload zsh/datetime   # $EPOCHREALTIME — timing without forking date
autoload -Uz add-zsh-hook

# Palette slots, not colour values. The sixteen are defined once, in
# anticrab.wezterm/wezterm.lua:55-56 (JetBrains Dark); naming the slot means this
# prompt follows a change there instead of quietly drifting from it, and it still
# reads correctly on a console with no true colour.
#
#   0-7  ansi     black red green yellow blue magenta cyan white
#   8-15 brights  same order
#
#   4  #57a8f5 blue    11  #f2c55c yellow    7  #bcbec4 white
#   8  #6f737a grey    10  #73bd79 green     1  #f75464 red
#   9  #ff6b68 bright red
#
# A hex value still works here if you want one: ANTICRAB_ZSH_COLORS[path]='#c87dbb'
typeset -gA ANTICRAB_ZSH_COLORS=(
    path   4    # blue
    branch 8    # grey
    dirty  11   # yellow
    extra  8    # grey
    ahead  10   # green
    behind 9    # bright red
    time   8    # grey
    ok     7    # white
    error  1    # red
)

# 0 stops asking git for the file counts: one fork per prompt, ~10 ms on a repo
# of this size, noticeable on a monorepo. The branch is still shown — it is read
# straight out of .git/HEAD and costs nothing.
: ${ANTICRAB_ZSH_GIT_DIRTY:=1}
# Commands quicker than this get no timing.
: ${ANTICRAB_ZSH_SLOW_SECONDS:=1}

# Gap between the two halves of the context line, or 0 when they cannot both
# fit — which is the caller's signal to drop the right half rather than wrap.
__anticrab_pad() {   # left-width right-width columns
    local -i left=$1 right=$2 columns=$3
    local -i gap=$(( columns - left - right ))
    (( right == 0 || gap < 2 )) && { REPLY=0; return }
    REPLY=$gap
}

__anticrab_duration() {   # seconds, possibly fractional
    local -F secs=$1
    local -i whole=$(( secs ))
    if (( secs < 60 )); then
        REPLY=$(printf '%.1fs' $secs)
    elif (( whole < 3600 )); then
        REPLY=$(printf '%dm%02ds' $(( whole / 60 )) $(( whole % 60 )))
    else
        REPLY=$(printf '%dh%02dm' $(( whole / 3600 )) $(( whole % 3600 / 60 )))
    fi
}

# The repository root above $PWD, or nothing. Walks the path inside the shell
# instead of forking `git rev-parse`, so a prompt outside a repo forks nothing.
__anticrab_git_root() {
    local dir=$PWD
    while true; do
        if [[ -e $dir/.git ]]; then
            REPLY=$dir
            return 0
        fi
        [[ -z $dir ]] && { REPLY=''; return 1 }
        dir=${dir%/*}
    done
}

# Branch name, or the short object id when HEAD is detached. Reads .git/HEAD
# directly: $(<file) is a builtin redirection in zsh and does not fork.
__anticrab_git_head() {   # repo-root
    local gitdir=$1/.git
    if [[ -f $gitdir ]]; then
        # A worktree or submodule: .git is a file holding "gitdir: <path>".
        local pointer=${"$(<$gitdir)"#gitdir: }
        [[ $pointer == /* ]] || pointer=$1/$pointer
        gitdir=$pointer
    fi
    [[ -r $gitdir/HEAD ]] || { REPLY=''; return 1 }
    local head=${"$(<$gitdir/HEAD)"}
    if [[ $head == ref:*refs/heads/* ]]; then
        REPLY=${head#ref: refs/heads/}
    elif [[ $head == ref:* ]]; then
        REPLY=${head#ref: }
    else
        REPLY=${head[1,7]}
    fi
}

# Changed/untracked file counts and upstream divergence from one git fork.
# vcs_info is not used: %u and %c are flags, not numbers, so it cannot produce
# the counts, and it spends several forks to learn less.
typeset -gA _anticrab_git
__anticrab_git_counts() {
    _anticrab_git=( changed 0 untracked 0 ahead 0 behind 0 )
    local -a lines
    lines=( ${(f)"$(git status --porcelain=v2 --branch 2>/dev/null)"} )
    (( $#lines )) || return 1
    local line ab
    for line in $lines; do
        case $line in
            ('# branch.ab '*) ab=${line#\# branch.ab } ;;
            ('1 '*|'2 '*|'u '*) (( _anticrab_git[changed]++ )) ;;
            ('? '*) (( _anticrab_git[untracked]++ )) ;;
        esac
    done
    if [[ -n $ab ]]; then
        _anticrab_git[ahead]=${${ab%% *}#+}
        _anticrab_git[behind]=${${ab##* }#-}
    fi
}

# Appends one field to the plain and the painted halves at once. The plain copy
# is what the width maths is done on; measuring the painted one would count the
# colour escapes.
__anticrab_field() {   # colour-key text
    local text=${2//\%/%%}   # a directory called 100% must not be a prompt escape
    _anticrab_plain+=( "$2" )
    _anticrab_paint+=( "%F{${ANTICRAB_ZSH_COLORS[$1]}}${text}%f" )
}

# Builds the context line. REPLY is the painted line, REPLY_PLAIN the same text
# without colour — kept separate so the tests can assert on the layout.
__anticrab_context() {
    local -a _anticrab_plain=() _anticrab_paint=()
    local -i columns=${COLUMNS:-80}
    (( columns > 0 )) || columns=80   # a shell with no terminal reports 0

    # Path, shortened from the left to half the window: room for the command
    # being typed matters more than the first half of a deep path.
    local dir=${PWD/#$HOME/\~}
    local -i budget=$(( columns / 2 ))
    if (( ${#dir} > budget && budget > 8 )); then
        dir="…${dir: -$(( budget - 1 ))}"
    fi
    __anticrab_field path "$dir"

    if __anticrab_git_root; then
        local root=$REPLY
        if __anticrab_git_head "$root"; then
            __anticrab_field branch "$REPLY"
            if (( ANTICRAB_ZSH_GIT_DIRTY )) && __anticrab_git_counts; then
                (( _anticrab_git[changed] ))   && __anticrab_field dirty  "+${_anticrab_git[changed]}"
                (( _anticrab_git[untracked] )) && __anticrab_field extra  "?${_anticrab_git[untracked]}"
                (( _anticrab_git[ahead] ))     && __anticrab_field ahead  "↑${_anticrab_git[ahead]}"
                (( _anticrab_git[behind] ))    && __anticrab_field behind "↓${_anticrab_git[behind]}"
            fi
        fi
    fi

    local left_plain="${(j: :)_anticrab_plain}"
    local left_paint="${(j: :)_anticrab_paint}"

    local right_plain='' right_paint=''
    if (( ${_anticrab_elapsed:-0} >= ANTICRAB_ZSH_SLOW_SECONDS )); then
        __anticrab_duration ${_anticrab_elapsed}
        right_plain=$REPLY
        right_paint="%F{${ANTICRAB_ZSH_COLORS[time]}}${REPLY}%f"
    fi

    __anticrab_pad ${#left_plain} ${#right_plain} $columns
    local -i gap=$REPLY
    if (( gap > 0 )); then
        REPLY="${left_paint}${(l:gap:):-}${right_paint}"
        REPLY_PLAIN="${left_plain}${(l:gap:):-}${right_plain}"
    else
        REPLY=$left_paint
        REPLY_PLAIN=$left_plain
    fi
}

__anticrab_preexec() {
    _anticrab_started=$EPOCHREALTIME
}

__anticrab_precmd() {
    local -i last=$?   # first statement: anything else clobbers it
    _anticrab_elapsed=0
    if [[ -n ${_anticrab_started:-} ]]; then
        (( _anticrab_elapsed = EPOCHREALTIME - _anticrab_started ))
        _anticrab_started=''
    fi
    __anticrab_context
    # The status is baked in rather than left to %(?.A.B): by the time the prompt
    # is expanded, $? is the status of this hook, not of the command before it.
    local arrow=${ANTICRAB_ZSH_COLORS[ok]}
    (( last )) && arrow=${ANTICRAB_ZSH_COLORS[error]}
    PROMPT="${REPLY}"$'\n'"%F{${arrow}}❯%f "
}

add-zsh-hook preexec __anticrab_preexec
add-zsh-hook precmd  __anticrab_precmd

# Right side of the input line stays empty: the context lives above it.
RPROMPT=''
# Continuation and select prompts, dimmed so they cannot be mistaken for input.
PROMPT2="%F{${ANTICRAB_ZSH_COLORS[branch]}}…%f "
PROMPT3="%F{${ANTICRAB_ZSH_COLORS[branch]}}?#%f "
