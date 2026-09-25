#!/usr/bin/env python3
"""Tests for the shell itself: options, history, completion, keys, start-up cost.

Every check runs an interactive zsh against a throwaway HOME that install.sh has
just populated, so these are assertions about the config as installed.

Run: python3 -m unittest discover -s tests
"""

import shutil
import statistics
import subprocess
import time
import unittest

from harness import ZshTestCase


class StartupTest(ZshTestCase):
    def test_interactive_startup_is_silent(self):
        proc = self.zsh("true")
        self.assertEqual(proc.stderr, "", proc.stderr)
        self.assertEqual(proc.stdout, "", proc.stdout)

    def test_a_real_session_starts_without_warnings(self):
        """A pty session loads what `zsh -i -c` skips: fzf's widgets and history."""
        out = self.pty_session(["print -r -- READY"])
        self.assertIn("READY", out)
        for noise in ("can't change option", "command not found",
                      "parse error", "no such file or directory"):
            self.assertNotIn(noise, out.lower())

    def test_first_prompt_sees_a_clean_exit_status(self):
        """A bare [[ ... ]] at the end of .zshrc would paint the first ❯ red."""
        self.assertEqual(self.out("print -r -- $?"), "0")

    def test_startup_cost_stays_under_60ms(self):
        self.zsh("true")            # warm up: the first run builds the compdump
        base = self.median_ms(["zsh", "-f", "-i", "-c", "true"])
        ours = self.median_ms(["zsh", "-i", "-c", "true"])
        self.assertLess(ours - base, 60,
                        f"config costs {ours - base:.0f} ms "
                        f"(bare zsh {base:.0f} ms, ours {ours:.0f} ms)")

    def median_ms(self, args, runs=7):
        times = []
        for _ in range(runs):
            start = time.perf_counter()
            subprocess.run(args, env=self.env, capture_output=True)
            times.append((time.perf_counter() - start) * 1000)
        return statistics.median(times)


class OptionsTest(ZshTestCase):
    def setUp(self):
        super().setUp()
        self.options = set(self.out("setopt").split())

    def test_navigation_options(self):
        for opt in ("autocd", "autopushd", "pushdignoredups", "pushdsilent"):
            self.assertIn(opt, self.options)

    def test_extended_glob_is_on_and_nomatch_is_off(self):
        self.assertIn("extendedglob", self.options)
        self.assertNotIn("nomatch", self.options)

    def test_a_glob_that_matches_nothing_is_passed_through_like_bash(self):
        self.assertEqual(self.out("print -r -- HEAD^"), "HEAD^")

    def test_recursive_glob_works(self):
        (self.home / "pkg").mkdir()
        (self.home / "pkg" / "a.lua").write_text("")
        (self.home / "pkg" / "sub").mkdir()
        (self.home / "pkg" / "sub" / "b.lua").write_text("")
        out = self.out("print -r -- **/*.lua", cwd=str(self.home / "pkg"))
        self.assertEqual(out, "a.lua sub/b.lua")

    def test_interactive_comments(self):
        self.assertIn("interactivecomments", self.options)

    def test_flow_control_is_off_so_ctrl_s_cannot_freeze_the_terminal(self):
        self.assertNotIn("flowcontrol", self.options)

    def test_wordchars_treats_path_separators_as_boundaries(self):
        wordchars = self.out("print -r -- $WORDCHARS")
        for char in "/-.=":
            self.assertNotIn(char, wordchars)

    def test_cdpath_points_at_projects(self):
        self.assertEqual(self.out("print -r -- $cdpath"),
                         f"{self.home}/projects")


class HistoryTest(ZshTestCase):
    def test_sizes_are_large_enough_to_hold_more_than_a_day(self):
        self.assertEqual(self.out("print -r -- $HISTSIZE"), "200000")
        self.assertEqual(self.out("print -r -- $SAVEHIST"), "200000")

    def test_history_file_lives_under_xdg_state(self):
        self.assertEqual(self.out("print -r -- $HISTFILE"),
                         f"{self.home}/.local/state/zsh/history")

    def test_history_options(self):
        options = set(self.out("setopt").split())
        for opt in ("extendedhistory", "sharehistory", "histignorealldups",
                    "histignorespace", "histreduceblanks", "histverify"):
            self.assertIn(opt, options)

    def test_a_command_reaches_the_file_without_the_shell_exiting(self):
        """The whole point: bash only wrote history on exit."""
        history = self.home / ".local/state/zsh/history"
        self.zsh("print -s 'marker command'")
        self.assertIn("marker command", history.read_text())

    def test_a_new_shell_sees_what_an_earlier_one_typed(self):
        """`zsh -i -c` never loads the history file, so this needs a real session."""
        self.zsh("print -s 'zulu-marker-command'")
        out = self.pty_session(
            ["fc -l 1 | grep -q zulu-marker && print -r -- SEEN=yes "
             "|| print -r -- SEEN=no"])
        self.assertIn("SEEN=yes", out)


class CompletionTest(ZshTestCase):
    def test_compinit_ran(self):
        self.assertEqual(self.out("print -r -- ${+functions[compdef]}"), "1")

    def test_dump_is_cached_under_xdg_cache(self):
        self.zsh("true")
        dumps = list((self.home / ".cache/zsh").glob("zcompdump-*"))
        self.assertTrue(dumps, "no completion dump was written")

    def test_menu_selection_is_enabled(self):
        self.assertIn("select", self.out("zstyle -L ':completion:*' menu"))

    def test_completion_cache_is_on(self):
        self.assertIn("use-cache", self.out("zstyle -L | grep use-cache"))


class CompletionSafetyTest(ZshTestCase):
    """Tab must never turn a command that exists into a longer one.

    `ll` is an alias here and also the prefix of llcstat-bpfcc, lldb and others.
    With auto_menu the second Tab — a bash habit, where Tab Tab only lists —
    inserts the first candidate, and a single Enter then runs it. That is how a
    plain `ll` once started a BPF profiler. rec_exact makes the exact match win.
    """

    def setUp(self):
        super().setUp()
        binaries = self.home / "bin"
        binaries.mkdir(parents=True, exist_ok=True)
        for name in ("zzalpha", "zzbeta"):
            script = binaries / name
            script.write_text(f"#!/bin/sh\necho RAN-{name}\n")
            script.chmod(0o755)
        (self.home / ".config/zsh/local.zsh").write_text(
            f"alias zz='print RAN-ALIAS'\npath+=({binaries})\n")

    def test_double_tab_then_enter_keeps_the_command_that_was_typed(self):
        out = self.pty_keys(b"zz\t\t\rexit\n")
        self.assertIn("RAN-ALIAS", out)
        self.assertNotIn("RAN-zzalpha", out)

    def test_single_tab_then_enter_keeps_the_command_that_was_typed(self):
        out = self.pty_keys(b"zz\t\rexit\n")
        self.assertIn("RAN-ALIAS", out)
        self.assertNotIn("RAN-zzalpha", out)

    def test_completion_still_completes_when_there_is_no_exact_match(self):
        out = self.pty_keys(b"zza\t\rexit\n")
        self.assertIn("RAN-zzalpha", out)


class KeysTest(ZshTestCase):
    def test_emacs_keymap_despite_nvim_being_the_editor(self):
        self.assertEqual(self.out("print -r -- $EDITOR"), "nvim")
        self.assertIn("emacs", self.out("bindkey -lL main"))

    def test_up_arrow_does_a_prefix_search(self):
        self.assertIn("up-line-or-beginning-search", self.out(r"bindkey '^[[A'"))

    def test_home_and_end_are_bound(self):
        self.assertIn("beginning-of-line", self.out(r"bindkey '^[[H'"))
        self.assertIn("end-of-line", self.out(r"bindkey '^[[F'"))

    def test_ctrl_x_ctrl_e_opens_the_line_in_the_editor(self):
        self.assertIn("edit-command-line", self.out(r"bindkey '^X^E'"))


class FzfTest(ZshTestCase):
    """fzf's widgets are only wired up in a session that has a terminal."""

    def setUp(self):
        super().setUp()
        if shutil.which("fzf") is None:
            self.skipTest("fzf is not installed")

    def test_ctrl_r_is_bound_to_the_fzf_history_widget(self):
        out = self.pty_session([r"bindkey '^R'"])
        self.assertIn("fzf-history-widget", out)

    def test_ctrl_t_and_alt_c_are_bound(self):
        out = self.pty_session([r"bindkey '^T'", r"bindkey '\ec'"])
        self.assertIn("fzf-file-widget", out)
        self.assertIn("fzf-cd-widget", out)

    def test_colours_follow_the_terminal_palette(self):
        opts = self.out("print -r -- $FZF_DEFAULT_OPTS")
        self.assertIn("pointer:4", opts)      # the palette's blue, not a copy of it
        self.assertIn("bg:-1", opts)          # keep the terminal background …
        self.assertIn("gutter:-1", opts)      # … transparency included


class ToolsTest(ZshTestCase):
    def test_ls_uses_eza_when_it_is_installed(self):
        alias = self.out("alias ls")
        if self.out("print -r -- ${+commands[eza]}") == "1":
            self.assertIn("eza", alias)
        else:
            self.assertIn("--color=auto", alias)

    def test_bat_alias_points_at_the_ubuntu_binary_name(self):
        if self.out("print -r -- ${+commands[batcat]}") == "1":
            self.assertIn("batcat", self.out("alias bat"))

    def test_cat_is_left_alone(self):
        self.assertEqual(self.out("alias cat || true"), "")

    def test_shell_survives_without_any_of_the_optional_tools(self):
        """conf.d/70-tools.zsh must be a no-op on a bare machine."""
        empty = self.home.parent / "emptybin"
        empty.mkdir(exist_ok=True)
        env = dict(self.env, PATH=str(empty))
        proc = subprocess.run(
            [shutil.which("zsh"), "-i", "-c", "alias ls; print -r -- ok"],
            env=env, capture_output=True, text=True,
        )
        self.assertEqual(proc.returncode, 0, proc.stderr)
        self.assertIn("ok", proc.stdout)
        self.assertIn("--color=auto", proc.stdout)

    def test_local_override_file_is_sourced_last(self):
        (self.home / ".config/zsh").mkdir(parents=True, exist_ok=True)
        (self.home / ".config/zsh/local.zsh").write_text("export MARKER=from-local\n")
        self.assertEqual(self.out("print -r -- $MARKER"), "from-local")


class PathTest(ZshTestCase):
    def test_local_bin_is_on_the_path(self):
        path = self.out("print -r -- $PATH")
        self.assertIn(f"{self.home}/.local/bin", path)

    def test_snap_bin_is_on_the_path_so_nvim_resolves(self):
        path = self.out("print -r -- $PATH")
        self.assertIn("/snap/bin", path)

    def test_path_has_no_duplicates(self):
        entries = self.out("print -r -- ${(j: :)path}").split()
        self.assertEqual(len(entries), len(set(entries)), entries)

    def test_editor_is_nvim_even_in_a_non_interactive_shell(self):
        self.assertEqual(self.out("print -r -- $EDITOR", interactive=False), "nvim")


if __name__ == "__main__":
    unittest.main()
