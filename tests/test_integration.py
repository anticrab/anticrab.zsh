#!/usr/bin/env python3
"""The sibling configs must point at zsh, not bash.

anticrab.tmux sets default-shell/default-command and anticrab.wezterm sets
default_prog; both name the shell explicitly. Leaving either on bash means panes
silently keep starting bash — and tmux-resurrect respawns restored panes with
`exec $(default-command)` (scripts/restore.sh:122), so a stale value there
survives every reboot.

The repos are looked up next to this one and skipped when absent, so a checkout
on another machine does not fail.

Run: python3 -m unittest discover -s tests
"""

import pathlib
import unittest

SIBLINGS = pathlib.Path(__file__).resolve().parents[2]


def read(repo, name):
    path = SIBLINGS / repo / name
    if not path.is_file():
        raise unittest.SkipTest(f"{path} is not checked out here")
    return path.read_text()


class TmuxTest(unittest.TestCase):
    def setUp(self):
        self.conf = read("anticrab.tmux", "tmux.conf")

    def test_default_shell_is_zsh(self):
        self.assertIn("set -g default-shell /usr/bin/zsh", self.conf)

    def test_default_command_is_a_zsh_login_shell(self):
        self.assertIn('set -g default-command "zsh -l"', self.conf)

    def test_no_bash_shell_lines_are_left_behind(self):
        for line in self.conf.splitlines():
            if line.startswith(("set -g default-shell", "set -g default-command")):
                self.assertNotIn("bash", line)


class WeztermTest(unittest.TestCase):
    def setUp(self):
        self.lua = read("anticrab.wezterm", "wezterm.lua")

    def test_default_prog_launches_zsh(self):
        self.assertIn('config.default_prog = { "zsh", "-l", "-c", '
                      '"tmux new -A -s main" }', self.lua)


if __name__ == "__main__":
    unittest.main()
