#!/usr/bin/env python3
"""Tests for conf.d/50-prompt.zsh.

The prompt is the only part of this config with arithmetic in it — right
alignment against $COLUMNS, duration formatting, and a git parser — so it gets
the closest tests. They call the helper functions directly and read $REPLY,
which is also why those helpers set REPLY instead of echoing: a command
substitution in a precmd hook would fork on every prompt.

Run: python3 -m unittest discover -s tests
"""

import unittest

from harness import ZshTestCase


class PadTest(ZshTestCase):
    def pad(self, left, right, columns):
        return self.out(f"__anticrab_pad {left} {right} {columns}; print -r -- $REPLY")

    def test_gap_fills_the_line(self):
        self.assertEqual(self.pad(10, 5, 80), "65")

    def test_no_right_half_means_no_padding(self):
        self.assertEqual(self.pad(10, 0, 80), "0")

    def test_exactly_two_columns_of_slack_still_pads(self):
        self.assertEqual(self.pad(40, 38, 80), "2")

    def test_one_column_of_slack_drops_the_right_half(self):
        self.assertEqual(self.pad(40, 39, 80), "0")

    def test_overflow_drops_the_right_half(self):
        self.assertEqual(self.pad(70, 20, 80), "0")


class DurationTest(ZshTestCase):
    def duration(self, secs):
        return self.out(f"__anticrab_duration {secs}; print -r -- $REPLY")

    def test_seconds_keep_one_decimal(self):
        self.assertEqual(self.duration("1.44"), "1.4s")

    def test_just_under_a_minute(self):
        self.assertEqual(self.duration("59.9"), "59.9s")

    def test_minutes_and_padded_seconds(self):
        self.assertEqual(self.duration("134"), "2m14s")

    def test_hours_and_padded_minutes(self):
        self.assertEqual(self.duration("3900"), "1h05m")


class ContextTest(ZshTestCase):
    """The plain half of the context line — what the width maths sees."""

    def context(self, cwd=None, columns=100, elapsed=0, env=None):
        script = (f"COLUMNS={columns}; _anticrab_elapsed={elapsed}; "
                  "__anticrab_context; print -r -- $REPLY_PLAIN")
        return self.out(script, cwd=cwd, env=env)

    def painted(self, cwd=None, columns=100, elapsed=0):
        script = (f"COLUMNS={columns}; _anticrab_elapsed={elapsed}; "
                  "__anticrab_context; print -r -- $REPLY")
        return self.out(script, cwd=cwd)

    def test_outside_a_repo_shows_only_the_path(self):
        self.assertEqual(self.context(cwd=str(self.home)), "~")

    def test_home_is_abbreviated_to_a_tilde(self):
        (self.home / "sub").mkdir()
        self.assertEqual(self.context(cwd=str(self.home / "sub")), "~/sub")

    def test_clean_repo_shows_the_branch(self):
        repo = self.git_repo()
        self.assertEqual(self.context(cwd=str(repo)), "~/repo main")

    def test_changed_file_is_counted(self):
        repo = self.git_repo()
        (repo / "file.txt").write_text("two\n")
        self.assertEqual(self.context(cwd=str(repo)), "~/repo main ✚1")

    def test_untracked_files_are_counted_separately(self):
        repo = self.git_repo()
        (repo / "new.txt").write_text("x\n")
        self.assertEqual(self.context(cwd=str(repo)), "~/repo main ?1")

    def test_staged_and_unstaged_both_count_as_changed(self):
        repo = self.git_repo()
        (repo / "file.txt").write_text("two\n")
        (repo / "other.txt").write_text("x\n")
        self.zsh(f"cd {repo} && git add other.txt")
        self.assertEqual(self.context(cwd=str(repo)), "~/repo main ✚2")

    def test_subdirectory_of_a_repo_still_finds_the_branch(self):
        repo = self.git_repo()
        (repo / "deep" / "deeper").mkdir(parents=True)
        self.assertEqual(self.context(cwd=str(repo / "deep" / "deeper")),
                         "~/repo/deep/deeper main")

    def test_detached_head_shows_a_short_object_id(self):
        repo = self.git_repo()
        self.zsh(f"cd {repo} && git checkout -q --detach HEAD")
        line = self.context(cwd=str(repo))
        self.assertRegex(line, r"^~/repo [0-9a-f]{7}$")

    def test_ahead_of_upstream_is_reported(self):
        # A clone already has an upstream and a tracking branch, so one local
        # commit makes it ahead — no push, no remote, no network.
        upstream = self.git_repo("upstream")
        clone = self.home / "clone"
        self.zsh(f"git clone -q {upstream} {clone}")
        self.zsh(f"cd {clone} && git config user.name t "
                 f"&& git config user.email t@e "
                 f"&& print two > file.txt && git commit -qam second")
        self.assertEqual(self.context(cwd=str(clone)), "~/clone main ⇡1")

    def test_git_dirty_off_keeps_the_branch_but_drops_the_counts(self):
        repo = self.git_repo()
        (repo / "file.txt").write_text("two\n")
        env = dict(self.env, ANTICRAB_ZSH_GIT_DIRTY="0")
        self.assertEqual(self.context(cwd=str(repo), env=env), "~/repo main")

    def test_percent_in_a_directory_name_is_escaped_for_the_prompt(self):
        weird = self.home / "100%"
        weird.mkdir()
        self.assertEqual(self.context(cwd=str(weird)), "~/100%")
        self.assertIn("100%%", self.painted(cwd=str(weird)))

    def test_a_long_path_is_shortened_from_the_left(self):
        deep = self.home / ("a" * 30) / ("b" * 30) / ("c" * 30)
        deep.mkdir(parents=True)
        line = self.context(cwd=str(deep), columns=80)
        self.assertTrue(line.startswith("…"), line)
        self.assertLessEqual(len(line), 40)
        self.assertTrue(line.endswith("c" * 10), line)


class TimingTest(ZshTestCase):
    def context(self, elapsed, columns=100):
        script = (f"COLUMNS={columns}; _anticrab_elapsed={elapsed}; "
                  "__anticrab_context; print -r -- $REPLY_PLAIN")
        return self.out(script, cwd=str(self.home))

    def test_quick_command_gets_no_timing(self):
        self.assertEqual(self.context("0.4"), "~")

    def test_slow_command_is_timed_on_the_right_edge(self):
        line = self.context("1.44")
        self.assertTrue(line.startswith("~"), line)
        self.assertTrue(line.endswith("1.4s"), line)
        self.assertEqual(len(line), 100)

    def test_narrow_window_drops_the_timing_rather_than_wrapping(self):
        line = self.context("1.44", columns=6)
        self.assertEqual(line, "~")


class PromptAssemblyTest(ZshTestCase):
    def test_prompt_is_two_lines_ending_in_the_arrow(self):
        prompt = self.out("__anticrab_precmd; print -r -- $PROMPT")
        self.assertEqual(len(prompt.splitlines()), 2, prompt)
        self.assertIn("❯", prompt.splitlines()[1])

    def test_arrow_turns_red_after_a_failed_command(self):
        """The status has to be read before anything in the hook clobbers it."""
        prompt = self.out("false; __anticrab_precmd; print -r -- $PROMPT")
        self.assertIn("%F{#f75464}❯", prompt)

    def test_arrow_is_plain_after_a_successful_command(self):
        prompt = self.out("true; __anticrab_precmd; print -r -- $PROMPT")
        self.assertIn("%F{#bcbec4}❯", prompt)
        self.assertNotIn("#f75464", prompt)


if __name__ == "__main__":
    unittest.main()
