# anticrab.zsh

Personal zsh config. Fourth of a set: [anticrab.nvim](https://github.com/anticrab/anticrab.nvim),
[anticrab.tmux](https://github.com/anticrab/anticrab.tmux),
[anticrab.wezterm](https://github.com/anticrab/anticrab.wezterm) — same
JetBrains Dark palette, same install pattern, same "every change lives in a
repo" rule.

Tested on Ubuntu 24.04 + zsh 5.9 + WezTerm + tmux 3.4.

No framework. No oh-my-zsh, no plugin manager, no prompt engine: about 500 lines
of zsh that can be read in one sitting, plus four apt packages.

Start-up cost is a test, not a hope: about **54 ms** per shell, and the suite
fails if that passes 75. Most of it is not ours to spend — 12-14 ms is
zsh-syntax-highlighting parsing itself, 5 ms `compinit` against a cached dump,
4 ms hashing `$PATH`, 4 ms zsh-autosuggestions. oh-my-zsh, for comparison, costs
200-400 ms, and on this machine a shell start is a tmux pane.

## Install

```bash
# 1. Packages. zsh itself plus the two plugins and the three tools.
sudo apt update && sudo apt install -y \
    zsh zsh-autosuggestions zsh-syntax-highlighting fzf eza bat

# 2. The config
git clone https://github.com/anticrab/anticrab.zsh ~/projects/anticrab.zsh
~/projects/anticrab.zsh/install.sh --symlink

# 3. Make it the login shell (asks for your password)
chsh -s /usr/bin/zsh
```

Then open a new terminal, or `exec zsh -l` in this one.

### What each package is for

| Package | Why |
| --- | --- |
| `zsh` | the shell |
| `zsh-autosuggestions` | grey ghost text from history; `→` or `Ctrl-Space` accepts it |
| `zsh-syntax-highlighting` | an unknown command turns red **before** Enter |
| `fzf` | `Ctrl-R` fuzzy history, `Ctrl-T` files, `Alt-C` directories |
| `eza` | `ls` with icons, a git column and `lt` for a tree |
| `bat` | `bat` with syntax highlighting; also colours man pages |

Everything except `zsh` is optional at runtime. Each block in
`conf.d/70-tools.zsh` is guarded, and a test asserts the shell still starts with
none of them on `$PATH`.

### Modes

`install.sh` copies the files by default. `--symlink` links them back to the repo
instead, so editing the repo takes effect in the next shell — that is how the
other anticrab.* configs are installed here.

Either way, anything already in place that the script did not write is moved to
`<file>.bak-<timestamp>` first. The script never calls `sudo`; missing packages
are printed as an `apt install` line for you to run.

### What lands where

```
~/.zshenv                      # the only file in $HOME: XDG vars, ZDOTDIR, PATH
~/.config/zsh/.zshrc           # sources conf.d in name order
~/.config/zsh/conf.d/*.zsh     # the actual config
~/.config/zsh/local.zsh        # yours, untracked, sourced last
~/.local/state/zsh/history     # 200 000 lines
~/.cache/zsh/                  # completion dump and cache
```

On a first run the history is seeded from `~/.bash_history`, so `Ctrl-R` is not
empty on day one. It happens once — a second run leaves the file alone.

`~/.bashrc` is never touched. `exec bash -l` goes back to bash at any time.

## Cheatsheet

The short version lives in [CHEATSHEET.md](CHEATSHEET.md). The parts worth
knowing on day one:

### History

| Key | Does |
| --- | --- |
| `Up` / `Down` | search history for **what is already typed** — `git com` then `Up` walks only the commits |
| `Ctrl-R` | fuzzy search over everything (fzf) |
| `Ctrl-Space` | accept the grey suggestion |
| `!!` / `!$` | previous command / its last argument — expanded onto the line first, Enter runs it |

200 000 lines, written the moment a command is run and shared between tmux
panes. bash kept 1000 in memory and wrote them only at exit, which is why
`Ctrl-R` used to find nothing from yesterday.

### Moving around

| Type | Does |
| --- | --- |
| `anticrab.nvim` | `auto_cd` — no `cd` needed |
| `cd anticrab.tmux` | works from anywhere: `cdpath` contains `~/projects` |
| `cd -` then `Tab` | numbered list of recent directories, arrows to pick |
| `Ctrl-T` | fuzzy file picker into the current command (fzf) |
| `Alt-C` | fuzzy directory jump (fzf) |

### Editing the line

| Key | Does |
| --- | --- |
| `Tab` | completion menu; arrows or `Tab`/`Shift-Tab` to walk it |
| `Tab` on a real command | leaves it alone — `ll` stays `ll`, even though `llcstat-bpfcc` starts the same way |
| `Ctrl-W` | delete one path segment (not the whole argument) |
| `Ctrl-X Ctrl-E` | open the half-written command in nvim; `:wq` runs it |
| `Ctrl-A` / `Ctrl-E` | start / end of line |
| `Ctrl-←` / `Ctrl-→` | by word |

### Globs worth stealing

```zsh
**/*.lua        # recursively, no find needed
*(.)            # plain files only
*(/)            # directories only
*(om[1])        # the newest file
^*.log          # everything except logs
ls -d *(/) | wc -l
```

`nomatch` is off, so `git show HEAD^` and `pip install 'foo[bar]'` still pass
through literally the way they do in bash.

## Projects and containers

Four docker projects on this machine name the same action four different ways —
`make exec` in fmr-sim, `make in` in retrofit_amr and ros2-sim, `make attach` in
rms-test — and only two of the four Makefiles have a `help` target. So there is
one command that never has to be remembered per project:

| Command | Does |
| --- | --- |
| `m` | list this project's Makefile targets and run the chosen one |
| `m up` | plain `make up`, from anywhere in the project |
| `dex` | pick a running container and get a shell in it |
| `dex rms` | the same, by name |
| `dlog` | follow a container's logs |

`m` finds the Makefile by walking up from `$PWD`, shows the `##` descriptions
where a Makefile has them and bare target names where it does not, and puts the
command it ran into the history so `Up` repeats it. Without fzf it prints the
list, which is still a better `make help`. Parsing is done in zsh rather than
with awk: Ubuntu's awk is mawk, whose `match()` has no capture groups.

`dex` asks for `bash` and falls back to `sh`, because a mosquitto or postgres
image has no bash and docker's own error for that is unhelpful. A single running
container is chosen outright, several are offered as a list.

There is deliberately **no wrapper around docker itself**. zsh's completion
already covers it: `docker <Tab>` lists the subcommands with descriptions and
`docker exec <Tab>` lists the running containers by name. A second vocabulary on
top of docker's own would be one more thing to remember, not one less.

## The prompt

```
~/projects/anticrab.nvim   main +2 ?1 ↑1                           1.4s
❯ git commit -m "fix(ui): count means real lines"
```

* path, shortened from the left to half the window;
* branch, or the short object id when HEAD is detached;
* `+N` changed tracked files, `?N` untracked, `↑N`/`↓N` ahead/behind upstream;
* elapsed time of the previous command, right-aligned, only when it took a
  second or more;
* `❯` is red when the previous command failed.

Both lines are `$PROMPT`, reassigned by a `precmd` hook. That is deliberate:
printing the context line from the hook — the usual recipe — leaves `Ctrl-L`
redrawing only the arrow and strands that line on a resize. It also avoids
`prompt_subst`, under which a substituted variable is *not* rescanned for prompt
escapes, the usual reason a hand-rolled prompt shows a literal `%F{...}`.

Git data comes from **one** `git status --porcelain=v2 --branch` fork.
`vcs_info` is not used: `%u`/`%c` are flags, not numbers, so it cannot produce
the counts, and it spends several forks to learn less. The branch itself is read
out of `.git/HEAD` with no fork at all, and `$PWD` is walked upwards in the shell
to decide whether there is a repo — so a prompt outside a repository forks
nothing.

Knobs (put them in `local.zsh`):

```zsh
ANTICRAB_ZSH_GIT_DIRTY=0        # drop the file counts, keep the branch
ANTICRAB_ZSH_SLOW_SECONDS=5     # only time commands slower than 5 s
ANTICRAB_ZSH_COLORS[path]=5     # another palette slot — or '#c87dbb' for a colour
```

### Colours and glyphs

Nothing here defines a colour. The prompt, the completion menu, fzf and the
syntax highlighting all name **palette slots** — `4` is blue, `8` grey, `11`
yellow, `1` red — and the sixteen are defined once, in
`anticrab.wezterm/wezterm.lua`. Change the palette there and everything follows;
copying the values here is how a terminal ends up looking like two themes at
once. Four colours have no slot and are written out: the fzf selection
background and border, the ghost-text grey, and the keyword orange JetBrains
uses for `if`/`for`/`while`. A test asserts that each of those four still exists
in `wezterm.lua` or in jb.nvim, so none of them can be invented here.

The glyphs are chosen the same way. `+ ? ↑ ↓ … ❯` are all drawn by JetBrainsMono
Nerd Font itself; wezterm silently falls back to DejaVu Sans Mono for anything
the font lacks, which keeps the cell width but drops another typeface's stroke
weight into the middle of a line — `✚` (U+271A) and the double arrows `⇡`/`⇣`
did exactly that and looked smudged beside the digits. Before using a new glyph:

```bash
wezterm ls-fonts --text '★'      # the font it names must be JetBrainsMono
```

## Deliberate choices

**No oh-my-zsh.** Some 3000 files and 200–400 ms per shell, which on this
machine means per tmux pane. Everything used from it here — completion styles,
history options, a prompt — is a dozen lines of zsh apiece.

**No plugin manager.** The two plugins are apt packages, updated by the system,
sourced by absolute path. Nothing to clone, pin or bootstrap.

**No starship / powerlevel10k.** starship is not in Ubuntu 24.04, so it would
mean an installer outside apt. p10k wants its own instant-prompt machinery and a
font setup this terminal already had trouble with. A hand-written prompt is
~150 lines and every character in it is a decision.

**`share_history` is on.** A command is visible in the other tmux panes at once.
The cost is that plain `Up` mixes their commands in, which the prefix search on
`Up`/`Down` makes a non-issue. To opt out: `unsetopt share_history` in
`local.zsh`.

**`bindkey -e` is explicit.** zsh picks vi mode when `$EDITOR` matches `*vi*`,
and `$EDITOR` here is `nvim`. Without that line the command line starts in
normal mode. `bindkey -v` in `local.zsh` gets vi mode on purpose.

**`rec_exact` is on.** A word that is already a command wins over the longer
commands that start with it. Without it `ll` is ambiguous — it is an alias here
*and* the start of `llcstat-bpfcc`, `lldb` and others — so the second `Tab`
(harmless in bash, where `Tab Tab` only lists) inserts the first candidate and a
single `Enter` runs it. Typing `ll` that way once started a BPF profiler.
Completion is unaffected where there is no exact match: `llc<Tab>` still finds
`llcstat-bpfcc`.

**`cat` is not aliased to bat.** Too much muscle memory and too many pipes. `bat`
is its own command, and `MANPAGER` uses it.

## Tests

```bash
tests/run.sh          # everything
tests/run.sh -v       # with each check named
```

They run a real zsh against a throwaway `$HOME` that `install.sh` has just
populated, so what is asserted is the config as installed:

* `test_install.py` — idempotency, backups, symlink mode, history seeding,
  never calling `sudo`, reporting missing packages without failing.
* `test_shell.py` — silent start-up, `$?` clean at the first prompt, the
  start-up budget, every expected `setopt`, history sizes and the file actually
  being written, completion dump location, key bindings, graceful degradation
  without eza/bat/fzf.
* `test_prompt.py` — padding at the boundaries, duration formatting, and the git
  fields against real temporary repositories: clean, changed, staged, untracked,
  detached, ahead of upstream, and a directory literally named `100%`.
* `test_integration.py` — anticrab.tmux and anticrab.wezterm point at zsh, so a
  stale `bash -l` cannot survive in `default-command` (tmux-resurrect respawns
  restored panes with it).

## File map

| File | Holds |
| --- | --- |
| `zshenv` | XDG vars, `ZDOTDIR`, `PATH`, `$EDITOR`. Read by every zsh, so it stays silent. |
| `zshrc` | wiring only |
| `conf.d/10-options.zsh` | `auto_cd`, `cdpath`, globbing, `WORDCHARS` |
| `conf.d/20-history.zsh` | sizes, file location, the six history options |
| `conf.d/30-completion.zsh` | `compinit` caching, completion styles |
| `conf.d/40-keys.zsh` | `bindkey -e`, prefix search, wezterm's key sequences |
| `conf.d/50-prompt.zsh` | the two-line prompt |
| `conf.d/60-aliases.zsh` | aliases that need nothing installed |
| `conf.d/70-tools.zsh` | fzf, eza, bat, and the two plugins |
| `install.sh` | idempotent install, `--symlink` mode |
