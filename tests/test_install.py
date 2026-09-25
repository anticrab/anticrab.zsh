#!/usr/bin/env python3
"""Tests for install.sh.

install.sh is the only part of this repo that writes outside the repo, so the
things worth pinning down are: it is idempotent, it never destroys a config it
did not write without keeping a backup, it never calls sudo, and it seeds the
new zsh history from ~/.bash_history exactly once (this machine has 38 KB of
bash history that would otherwise be stranded).

Everything runs against a throwaway HOME. The real ~/.zshenv is never touched.

Run: python3 -m unittest discover -s tests
"""

import os
import pathlib
import subprocess
import tempfile
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]

# Any call to sudo is a bug: the script must print the apt command, not run it.
SUDO_TRAP = "#!/bin/sh\necho 'install.sh called sudo' >&2\nexit 99\n"


class InstallTestCase(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = pathlib.Path(self.tmp.name)
        self.home = self.root / "home"
        self.bin = self.root / "bin"
        for path in (self.home, self.bin):
            path.mkdir(parents=True)

        trap = self.bin / "sudo"
        trap.write_text(SUDO_TRAP)
        trap.chmod(0o755)

        self.env = dict(os.environ)
        self.env["HOME"] = str(self.home)
        self.env["PATH"] = f"{self.bin}:{os.environ['PATH']}"
        for stale in ("ZDOTDIR", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
                      "XDG_STATE_HOME", "XDG_DATA_HOME"):
            self.env.pop(stale, None)

    def install(self, *args, expect_rc=0):
        proc = subprocess.run(
            [str(REPO / "install.sh"), *args],
            env=self.env, capture_output=True, text=True,
        )
        self.assertNotIn("called sudo", proc.stderr)
        self.assertEqual(proc.returncode, expect_rc, proc.stdout + proc.stderr)
        return proc

    # -- what lands on disk ------------------------------------------------

    def test_installs_zshenv_and_config(self):
        self.install()
        self.assertTrue((self.home / ".zshenv").is_file())
        self.assertTrue((self.home / ".config/zsh/.zshrc").exists())
        self.assertTrue((self.home / ".config/zsh/conf.d/50-prompt.zsh").exists())

    def test_zshenv_points_zdotdir_at_the_config_dir(self):
        self.install()
        text = (self.home / ".zshenv").read_text()
        self.assertIn("ZDOTDIR", text)
        self.assertRegex(text, r"ZDOTDIR=.*zsh")

    def test_only_zshenv_is_placed_in_home(self):
        """Everything else belongs under ~/.config/zsh; $HOME stays clean."""
        self.install()
        dotfiles = {p.name for p in self.home.iterdir() if p.name.startswith(".z")}
        self.assertEqual(dotfiles, {".zshenv"})

    def test_creates_state_and_cache_dirs(self):
        self.install()
        self.assertTrue((self.home / ".local/state/zsh").is_dir())
        self.assertTrue((self.home / ".cache/zsh").is_dir())

    # -- idempotency -------------------------------------------------------

    def test_second_run_changes_nothing(self):
        self.install()
        before = self.snapshot()
        self.install()
        self.assertEqual(before, self.snapshot())

    def test_second_run_leaves_no_backup(self):
        self.install()
        self.install()
        self.assertEqual(self.backups(), [])

    # -- not destroying other people's config ------------------------------

    def test_foreign_zshenv_is_backed_up_before_replacement(self):
        hand_rolled = self.home / ".zshenv"
        hand_rolled.write_text("# my own thing\nexport FOO=1\n")
        self.install()
        backups = self.backups()
        self.assertEqual(len(backups), 1, f"expected one backup, got {backups}")
        self.assertIn("my own thing", backups[0].read_text())
        self.assertIn("ZDOTDIR", hand_rolled.read_text())

    def test_identical_zshenv_is_not_backed_up(self):
        self.install()
        self.install()
        self.assertEqual(self.backups(), [])

    # -- symlink mode (the mode actually used on this machine) -------------

    def test_symlink_mode_links_back_to_the_repo(self):
        self.install("--symlink")
        zshrc = self.home / ".config/zsh/.zshrc"
        confd = self.home / ".config/zsh/conf.d"
        self.assertTrue(zshrc.is_symlink())
        self.assertEqual(zshrc.resolve(), REPO / "zshrc")
        self.assertTrue(confd.is_symlink())
        self.assertEqual(confd.resolve(), REPO / "conf.d")

    def test_symlink_mode_is_idempotent(self):
        self.install("--symlink")
        before = self.snapshot()
        self.install("--symlink")
        self.assertEqual(before, self.snapshot())

    def test_switching_from_copy_to_symlink_replaces_the_copy(self):
        self.install()
        self.install("--symlink")
        self.assertTrue((self.home / ".config/zsh/.zshrc").is_symlink())

    # -- history migration -------------------------------------------------

    def test_seeds_history_from_bash(self):
        (self.home / ".bash_history").write_text("git status\nmake test\n")
        self.install()
        history = (self.home / ".local/state/zsh/history").read_text()
        self.assertIn("make test", history)

    def test_does_not_reseed_history_on_a_second_run(self):
        (self.home / ".bash_history").write_text("git status\n")
        self.install()
        history = self.home / ".local/state/zsh/history"
        history.write_text(history.read_text() + "later command\n")
        self.install()
        text = history.read_text()
        self.assertIn("later command", text)
        self.assertEqual(text.count("git status"), 1)

    def test_no_bash_history_is_not_an_error(self):
        self.install()
        self.assertTrue((self.home / ".local/state/zsh").is_dir())

    # -- missing packages --------------------------------------------------

    def test_reports_missing_packages_without_failing(self):
        """A machine without zsh still gets a working checkout and an apt hint."""
        self.stub_dpkg(installed=False)
        proc = self.install()
        self.assertIn("apt install", proc.stdout)

    def test_no_apt_hint_when_everything_is_installed(self):
        self.stub_dpkg(installed=True)
        proc = self.install()
        self.assertNotIn("apt install", proc.stdout)

    def stub_dpkg(self, installed):
        stub = self.bin / "dpkg-query"
        stub.write_text("#!/bin/sh\nprintf installed\n" if installed
                        else "#!/bin/sh\nexit 1\n")
        stub.chmod(0o755)

    def test_prints_the_chsh_command(self):
        """The one step the script cannot do itself must be spelled out."""
        proc = self.install()
        self.assertIn("chsh", proc.stdout)

    # -- helpers -----------------------------------------------------------

    def snapshot(self):
        out = {}
        for path in sorted(self.home.rglob("*")):
            rel = path.relative_to(self.home)
            if path.is_symlink():
                out[str(rel)] = f"link:{os.readlink(path)}"
            elif path.is_file():
                out[str(rel)] = f"file:{path.read_bytes()!r}"
            else:
                out[str(rel)] = "dir"
        return out

    def backups(self):
        return sorted(p for p in self.home.rglob("*.bak-*") if p.is_file())


if __name__ == "__main__":
    unittest.main()
