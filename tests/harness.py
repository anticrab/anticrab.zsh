"""Shared fixture: a throwaway HOME with anticrab.zsh installed into it.

Every shell test runs a real zsh against that HOME, so what is tested is the
config as install.sh actually lays it down, not a hand-assembled copy of it.

Two ways to run a shell, and the difference matters:

* `zsh()` — `zsh -i -c '<script>'`. Cheap, fine for asking a loaded config about
  itself. It is *not* a session: zsh never reads the history file and never
  starts the line editor in this mode.
* `pty_session()` — a real interactive zsh driven over a pseudo-terminal.
  Anything about history loading or key bindings has to be tested here.
"""

import os
import pathlib
import select
import shutil
import subprocess
import tempfile
import time
import unittest

REPO = pathlib.Path(__file__).resolve().parents[1]


class ZshTestCase(unittest.TestCase):
    def setUp(self):
        self.zsh_bin = shutil.which("zsh")
        if self.zsh_bin is None:
            self.fail("zsh is not installed — run ./install.sh and the apt line "
                      "it prints")

        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.home = pathlib.Path(self.tmp.name) / "home"
        self.home.mkdir(parents=True)

        self.env = dict(os.environ)
        self.env["HOME"] = str(self.home)
        for stale in ("ZDOTDIR", "XDG_CONFIG_HOME", "XDG_CACHE_HOME",
                      "XDG_STATE_HOME", "XDG_DATA_HOME"):
            self.env.pop(stale, None)

        subprocess.run([str(REPO / "install.sh"), "--symlink"],
                       env=self.env, capture_output=True, text=True, check=True)

    def zsh(self, script, cwd=None, env=None, interactive=True, check=True):
        args = [self.zsh_bin] + (["-i"] if interactive else []) + ["-c", script]
        proc = subprocess.run(args, env=env or self.env, cwd=cwd,
                              capture_output=True, text=True)
        if check:
            self.assertEqual(proc.returncode, 0,
                             f"zsh exited {proc.returncode}\n"
                             f"stdout: {proc.stdout}\nstderr: {proc.stderr}")
        return proc

    def out(self, script, **kwargs):
        return self.zsh(script, **kwargs).stdout.strip()

    def pty_session(self, commands, cwd=None, env=None, timeout=20):
        """Type `commands` into an interactive zsh on a pty; return all output.

        The output includes the terminal's echo of what was typed and the prompt
        itself, so assertions should look for a marker the typed line does not
        already contain.
        """
        import pty
        master, slave = pty.openpty()
        proc = subprocess.Popen([self.zsh_bin, "-i"],
                                stdin=slave, stdout=slave, stderr=slave,
                                env=env or self.env, cwd=cwd, close_fds=True)
        os.close(slave)
        os.write(master, "".join(f"{line}\n" for line in [*commands, "exit"]).encode())

        chunks, deadline = [], time.time() + timeout
        while time.time() < deadline:
            ready, _, _ = select.select([master], [], [], 0.5)
            if not ready:
                if proc.poll() is not None:
                    break
                continue
            try:
                data = os.read(master, 8192)
            except OSError:
                break
            if not data:
                break
            chunks.append(data)
        try:
            proc.wait(timeout=5)
        except subprocess.TimeoutExpired:
            proc.kill()
        os.close(master)
        return b"".join(chunks).decode(errors="replace")

    def git_repo(self, name="repo", branch="main"):
        """An initialised repo with one commit, at $HOME/<name>."""
        path = self.home / name
        path.mkdir(parents=True, exist_ok=True)
        run = lambda *a: subprocess.run(a, cwd=path, env=self.env, check=True,
                                        capture_output=True)
        run("git", "init", "-q", "-b", branch)
        # Identity in the repo itself: later commits are made by the shell under
        # test, which does not carry the GIT_AUTHOR_* environment.
        run("git", "config", "user.name", "test")
        run("git", "config", "user.email", "test@example.invalid")
        (path / "file.txt").write_text("one\n")
        run("git", "add", "file.txt")
        run("git", "commit", "-qm", "first")
        return path
