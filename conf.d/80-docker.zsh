# The two things the project Makefiles do not cover: the containers nobody
# wrapped (postgres, rabbitmq, mosquitto) and following their logs.
#
# Everything else about docker is already served by zsh's own completion —
# `docker <Tab>` lists the subcommands with their descriptions, `docker exec
# <Tab>` lists the running containers — so there is no wrapper here, and no
# second vocabulary to remember on top of docker's own.

if (( $+commands[docker] )); then

    # Name of a running container. One running container is chosen outright;
    # several are offered as a list.
    __anticrab_pick_container() {
        local -a rows
        rows=( ${(f)"$(docker ps --format '{{.Names}}	{{.Image}}	{{.Status}}' 2>/dev/null)"} )
        if (( ! $#rows )); then
            print -u2 -- "no running containers"
            return 1
        fi
        if (( $#rows == 1 )); then
            REPLY=${rows[1]%%	*}
            return 0
        fi
        local pick
        if (( $+commands[fzf] )); then
            pick=$(print -rl -- $rows | fzf --prompt='container ' --height=40% --reverse) || return 1
        else
            print -rl -- $rows
            return 1
        fi
        [[ -n $pick ]] || return 1
        REPLY=${pick%%	*}
    }

    # Enter a container. bash when the image has it, sh otherwise: a mosquitto or
    # postgres image may have no bash, and docker's error for that is unhelpful.
    dex() {
        local name=$1
        if [[ -z $name ]]; then
            __anticrab_pick_container || return
            name=$REPLY
        fi
        print -s "dex $name"
        docker exec -it "$name" sh -c \
            'if command -v bash >/dev/null 2>&1; then exec bash; else exec sh; fi'
    }

    dlog() {
        local name=$1
        if [[ -z $name ]]; then
            __anticrab_pick_container || return
            name=$REPLY
        fi
        docker logs -f --tail 200 "$name"
    }
fi
