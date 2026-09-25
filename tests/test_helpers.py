#!/usr/bin/env python3
"""Tests for the project helpers: `m`, `dex`, `dlog`.

Four docker projects on this machine, four different words for "get me inside
the container" — `make exec`, `make in`, `make attach` — and only two of the four
Makefiles have a `help` target. `m` exists so that word never has to be
remembered: it lists what this project actually offers.

`dex` and `dlog` cover the containers no Makefile wraps (postgres, rabbitmq,
mosquitto). Everything else about docker is already served by zsh's completion.

docker, make and fzf are all stubbed here: the tests assert on the command that
would have run, not on a live daemon.

Run: python3 -m unittest discover -s tests
"""

import os
import subprocess
import unittest

from harness import ZshTestCase

RECORDER = """#!/bin/sh
printf '%s\\n' "$*" >> "{log}"
{body}
"""


class HelperTestCase(ZshTestCase):
    """A throwaway project tree plus stubbed make/docker/fzf on $PATH."""

    MAKEFILE = """\
COMPOSE := docker compose -f docker/compose.yaml

.PHONY: help up exec

help:  ## Show this help
\t@echo help

up: .env  ## Start the containers
\t$(COMPOSE) up -d

exec:  ## Enter the development container
\t$(COMPOSE) exec development bash

build-gpu:
\t$(COMPOSE) build
"""

    BARE_MAKEFILE = "in:\n\tdocker exec -it dev bash\n\nrun:\n\tdocker compose up\n"

    def setUp(self):
        super().setUp()
        self.bin = self.home / "stub-bin"
        self.bin.mkdir()
        self.log = self.home / "calls.log"
        self.env["PATH"] = f"{self.bin}:{self.env['PATH']}"

        self.stub("make")
        self.stub("docker", body=(
            'if [ "$1" = ps ]; then\n'
            '  printf "rms\\trms-sprint12:latest\\tUp 40 minutes\\n"\n'
            '  printf "rms-postgres\\tpostgres:17\\tUp 40 minutes\\n"\n'
            'fi\n'))
        # fzf without a terminal: take the first line offered.
        self.stub("fzf", body="head -n 1")

        self.project = self.home / "work" / "fmr-sim"
        (self.project / "src" / "deep").mkdir(parents=True)
        (self.project / "Makefile").write_text(self.MAKEFILE)

        self.bare = self.home / "work" / "retrofit"
        self.bare.mkdir(parents=True)
        (self.bare / "Makefile").write_text(self.BARE_MAKEFILE)

    def stub(self, name, body="exit 0"):
        path = self.bin / name
        path.write_text(RECORDER.format(log=self.log, body=body))
        path.chmod(0o755)

    def calls(self):
        return self.log.read_text().splitlines() if self.log.exists() else []


class MakeHelperTest(HelperTestCase):
    def test_finds_the_makefile_from_a_subdirectory(self):
        out = self.out("__anticrab_make_root && print -r -- $REPLY",
                       cwd=str(self.project / "src" / "deep"))
        self.assertEqual(out, str(self.project))

    def test_reports_no_makefile_outside_a_project(self):
        proc = self.zsh("__anticrab_make_root", cwd=str(self.home), check=False)
        self.assertEqual(proc.returncode, 1)

    def test_lists_targets_with_their_descriptions(self):
        out = self.out(f"__anticrab_make_targets {self.project}/Makefile")
        self.assertIn("Enter the development container", out)
        self.assertIn("Start the containers", out)

    def test_lists_targets_that_have_no_descriptions(self):
        """Two of the four real Makefiles document nothing; still usable."""
        out = self.out(f"__anticrab_make_targets {self.bare}/Makefile")
        names = [line.split()[0] for line in out.splitlines()]
        self.assertEqual(names, ["in", "run"])

    def test_skips_phony_variables_and_recipe_lines(self):
        out = self.out(f"__anticrab_make_targets {self.project}/Makefile")
        names = [line.split()[0] for line in out.splitlines()]
        self.assertEqual(names, ["help", "up", "exec", "build-gpu"])

    def test_an_argument_is_passed_straight_to_make(self):
        self.zsh("m up", cwd=str(self.project / "src"))
        self.assertIn(f"-C {self.project} up", self.calls())

    def test_no_argument_picks_a_target_and_runs_it(self):
        self.zsh("m", cwd=str(self.project))
        self.assertIn(f"-C {self.project} help", self.calls())

    def test_the_chosen_command_lands_in_the_history(self):
        """So that Up-arrow repeats it like anything else."""
        history = self.home / ".local/state/zsh/history"
        self.zsh("m", cwd=str(self.project))
        self.assertIn("make help", history.read_text())

    def test_outside_a_project_it_explains_itself(self):
        proc = self.zsh("m", cwd=str(self.home), check=False)
        self.assertNotEqual(proc.returncode, 0)
        self.assertIn("Makefile", proc.stdout + proc.stderr)


class DockerHelperTest(HelperTestCase):
    def test_dex_enters_the_named_container(self):
        self.zsh("dex rms-postgres")
        self.assertTrue(any("exec -it rms-postgres" in c for c in self.calls()),
                        self.calls())

    def test_dex_without_a_name_picks_a_running_container(self):
        self.zsh("dex")
        self.assertTrue(any("exec -it rms " in c or c.endswith("exec -it rms")
                            or "exec -it rms" in c for c in self.calls()),
                        self.calls())

    def test_dex_falls_back_to_sh_when_the_image_has_no_bash(self):
        joined = " ".join(self.calls() or [""])
        self.zsh("dex rms")
        joined = " ".join(self.calls())
        self.assertIn("bash", joined)
        self.assertIn("sh", joined)

    def test_dlog_follows_the_named_container(self):
        self.zsh("dlog rms")
        self.assertTrue(any("logs" in c and "rms" in c for c in self.calls()),
                        self.calls())

    def test_dlog_without_a_name_picks_one(self):
        self.zsh("dlog")
        self.assertTrue(any("logs" in c for c in self.calls()), self.calls())

    def test_helpers_are_absent_when_docker_is_not_installed(self):
        empty = self.home.parent / "nodocker"
        empty.mkdir(exist_ok=True)
        proc = subprocess.run(
            [self.zsh_bin, "-i", "-c", "print -r -- ${+functions[dex]}"],
            env=dict(self.env, PATH=str(empty)), capture_output=True, text=True)
        self.assertEqual(proc.stdout.strip(), "0", proc.stderr)


if __name__ == "__main__":
    unittest.main()
