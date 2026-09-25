# anticrab.zsh — Cheatsheet

Coming from bash. Everything bash did still works — pipes, `&&`, `$( )`,
functions, `for` loops, `#!/usr/bin/env bash` scripts. What follows is what is
*new*.

> Forgot something? `bindkey` lists every key binding, `alias` every alias,
> `setopt` every option that is on.

---

## Day one — the five that change how it feels

| Key | Does |
|---|---|
| `Up` | history search by **what is already typed**: `git com` + `Up` walks only the commits |
| `Ctrl-R` | fuzzy search over the whole history (fzf) — type any fragment, in any order |
| `→` or `Ctrl-Space` | accept the grey suggestion sitting ahead of the cursor |
| `Tab` | completion **menu**: arrows to walk it, `Enter` to take it |
| `Ctrl-X Ctrl-E` | open the half-written command in nvim, `:wq` to run it |

An unknown command turns **red as you type it**, before Enter. A red command
means a typo or something not installed.

## Moving around (no `cd` needed)

| Type | Does |
|---|---|
| `anticrab.nvim` | changes into it — `auto_cd` |
| `cd anticrab.tmux` | works from anywhere: `cdpath=(~/projects)` |
| `cd -` `Tab` | numbered list of recent directories |
| `Alt-C` | fuzzy jump into a directory below here (fzf) |
| `Ctrl-T` | fuzzy-pick a file **into the current command** (fzf) |
| `..` `cd ../..` | unchanged |

## History

| Key / syntax | Does |
|---|---|
| `Ctrl-R` | fuzzy search; `Ctrl-/` toggles the preview of a long command |
| `Up` / `Down` | prefix search |
| `!!` | previous command — lands on the line first, `Enter` confirms |
| `!$` | last argument of the previous command |
| ` command` | a **leading space** keeps it out of the history |
| `fc -l -20` | last 20 with numbers |
| `fc` | edit the previous command in nvim and rerun it |

200 000 lines, written immediately, shared across tmux panes. In bash it was
1000 lines flushed at exit.

## Completion

| Key | Does |
|---|---|
| `Tab` | complete; second `Tab` opens the menu |
| arrows | walk the menu |
| `Shift-Tab` | walk it backwards |
| `Ctrl-C` | leave the menu |

A command that already exists is never replaced by a longer one: `ll<Tab>` stays
`ll`, even though `llcstat-bpfcc` and `lldb` start the same way. To reach those,
type enough to be unambiguous: `llc<Tab>`.

Case-insensitive and substring-aware: `cd Pro<Tab>` finds `projects`,
`cd a.nv<Tab>` finds `anticrab.nvim`. Try `git <Tab>`, `git checkout <Tab>`,
`ssh <Tab>`, `docker <Tab>`, `kill <Tab>`, `systemctl <Tab>` — the descriptions
come from the tools themselves.

## Editing the line

| Key | Does |
|---|---|
| `Ctrl-A` / `Ctrl-E` | start / end of line |
| `Ctrl-W` | delete one **path segment** (`/`, `-`, `.`, `=` are boundaries) |
| `Ctrl-U` | delete the whole line |
| `Ctrl-Y` | paste back what was deleted |
| `Ctrl-←` / `Ctrl-→` | word left / right |
| `Alt-←` / `Alt-→` | the same, for a keyboard without Ctrl-arrows |
| `Ctrl-L` | clear the screen (redraws both prompt lines) |
| `Ctrl-X Ctrl-E` | hand the line to nvim |

`Ctrl-S` no longer freezes the terminal.

## Globs — the part bash cannot do

| Pattern | Matches |
|---|---|
| `**/*.lua` | recursively, no `find` |
| `*(.)` | plain files only |
| `*(/)` | directories only |
| `*(om[1])` | the newest entry |
| `*(.mh-2)` | files changed in the last two hours |
| `^*.log` | everything **except** logs |
| `*.{lua,zsh}` | either extension |

```zsh
ls -d *(/)              # just the directories
nvim **/*keymap*        # every matching file, at any depth
print -l *(om[1,3])     # three newest, one per line
```

Arguments that merely look like globs are safe: `git show HEAD^`,
`pip install 'foo[bar]'`, `curl 'u?a=b'` behave as in bash.

## Aliases

| Alias | Runs |
|---|---|
| `ls` `ll` `la` `l` | eza with icons, git column, directories first |
| `lt` | `eza --tree --level=2` |
| `bat` | `batcat --theme=ansi` (Ubuntu names the binary `batcat`) |
| `zvim` | `nvim` |
| `reload` | `exec zsh -l` — re-read the config in place |
| `alert` | desktop notification: `make build; alert` |

`man zsh` is coloured by bat. `cat` is deliberately untouched.

## The prompt

```
~/projects/anticrab.nvim   main ✚2 ?1 ⇡1                           1.4s
❯ git commit -m "…"
```

| Field | Means |
|---|---|
| `main` | branch, or a short object id when HEAD is detached |
| `✚2` | changed tracked files, staged or not |
| `?1` | untracked files |
| `⇡1` / `⇣1` | commits ahead of / behind upstream |
| `1.4s` | the previous command took that long (shown from 1 s up) |
| red `❯` | the previous command failed |

## Escape hatches

| Want | Put in `~/.config/zsh/local.zsh` |
|---|---|
| vi mode on the command line | `bindkey -v` |
| no shared history between panes | `unsetopt share_history` |
| a faster prompt in a huge repo | `ANTICRAB_ZSH_GIT_DIRTY=0` |
| a different timing threshold | `ANTICRAB_ZSH_SLOW_SECONDS=5` |
| your own aliases | anything — the file is untracked |

Back to bash entirely: `exec bash -l`. `~/.bashrc` was never modified.
