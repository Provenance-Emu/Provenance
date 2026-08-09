#!/usr/bin/env python3
"""Tests for scheduled-workflow-staleness.py.

Stdlib `unittest` only — the runner is not guaranteed to have pytest, for the
same reason the script under test hand-rolls its YAML scan instead of relying
on PyYAML.

Run with:
    python3 .github/scripts/test_scheduled_workflow_staleness.py
"""

from __future__ import annotations

import contextlib
import datetime as dt
import importlib.util
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

# The script's filename has hyphens, so it is not importable as a module name.
_SCRIPT = Path(__file__).with_name("scheduled-workflow-staleness.py")
_spec = importlib.util.spec_from_file_location("staleness", _SCRIPT)
assert _spec and _spec.loader
sws = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(sws)


class ExtractCronExpressions(unittest.TestCase):
    def test_nested_indent_style(self):
        text = """name: Nightly
on:
  schedule:
    - cron: '0 4 * * *'
  workflow_dispatch:
jobs:
  build:
    runs-on: ubuntu-latest
"""
        self.assertEqual(sws.extract_cron_expressions(text), ["0 4 * * *"])

    def test_same_indent_as_schedule_key(self):
        """F3: a sequence item may sit at the SAME indent as the key owning it.

        This is valid YAML. The pre-fix terminator (`indent <= schedule_indent`)
        ended the block on the very first `- cron:` line and returned [], making
        any workflow written this way invisible to the staleness check.
        """
        text = """name: Weekly
on:
  schedule:
  - cron: '0 4 * * 0'
  - cron: '30 5 * * 1'
  push:
    branches: [develop]
jobs:
  build:
    runs-on: ubuntu-latest
"""
        self.assertEqual(
            sws.extract_cron_expressions(text), ["0 4 * * 0", "30 5 * * 1"]
        )

    def test_same_indent_block_still_terminates_on_sibling_key(self):
        """The relaxed terminator must not swallow crons from outside `schedule:`."""
        text = """on:
  schedule:
  - cron: '0 4 * * 0'
  push:
    branches: [develop]
jobs:
  build:
    steps:
      - cron: 'not a schedule entry'
"""
        self.assertEqual(sws.extract_cron_expressions(text), ["0 4 * * 0"])

    def test_commented_out_cron_is_ignored(self):
        text = """on:
  schedule:
    # - cron: '0 4 * * *'
    - cron: '0 6 * * *'
"""
        self.assertEqual(sws.extract_cron_expressions(text), ["0 6 * * *"])

    def test_quoted_on_key_is_recognised(self):
        """YAML 1.1 parses bare `on` as True, so people quote it to dodge that."""
        for key in ('"on"', "'on'"):
            with self.subTest(key=key):
                text = f"""{key}:
  schedule:
    - cron: '15 3 * * *'
"""
                self.assertEqual(sws.extract_cron_expressions(text), ["15 3 * * *"])

    def test_trailing_comment_is_stripped(self):
        text = """on:
  schedule:
    - cron: 0 4 * * *  # nightly
    - cron: "0 5 * * *"  # also nightly
"""
        self.assertEqual(
            sws.extract_cron_expressions(text), ["0 4 * * *", "0 5 * * *"]
        )

    def test_no_schedule_block(self):
        text = """on:
  push:
    branches: [develop]
"""
        self.assertEqual(sws.extract_cron_expressions(text), [])


class DiscoverScheduledWorkflows(unittest.TestCase):
    def test_separates_scheduled_from_unscheduled(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "nightly.yml").write_text(
                "on:\n  schedule:\n    - cron: '0 4 * * *'\n", encoding="utf-8"
            )
            (root / "onpush.yaml").write_text(
                "on:\n  push:\n    branches: [develop]\n", encoding="utf-8"
            )
            # A `disabled/` subdirectory is not executed by GitHub and must not
            # be monitored — only the top level is scanned.
            nested = root / "disabled"
            nested.mkdir()
            (nested / "old.yml").write_text(
                "on:\n  schedule:\n    - cron: '0 1 * * *'\n", encoding="utf-8"
            )

            found, unreadable = sws.discover_scheduled_workflows(root)

        self.assertEqual(found, [("nightly.yml", ["0 4 * * *"])])
        self.assertEqual(unreadable, [])

    def test_unreadable_file_is_reported_not_dropped(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            bad = root / "locked.yml"
            bad.write_text(
                "on:\n  schedule:\n    - cron: '0 4 * * *'\n", encoding="utf-8"
            )
            bad.chmod(0o000)
            try:
                found, unreadable = sws.discover_scheduled_workflows(root)
            finally:
                bad.chmod(0o644)

        if not unreadable:  # running as root, where chmod 000 does not deny reads
            self.skipTest("cannot make a file unreadable as this user")
        self.assertEqual(found, [])
        self.assertEqual([name for name, _ in unreadable], ["locked.yml"])

    def test_missing_directory_yields_nothing(self):
        found, unreadable = sws.discover_scheduled_workflows(Path("/nonexistent/xyz"))
        self.assertEqual(found, [])
        self.assertEqual(unreadable, [])


class WorkflowFiles(unittest.TestCase):
    def test_empty_directory(self):
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(sws.workflow_files(Path(tmp)), [])

    def test_only_yaml_files_count(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "a.yml").write_text("on: {}\n", encoding="utf-8")
            (root / "b.yaml").write_text("on: {}\n", encoding="utf-8")
            (root / "README.md").write_text("nope\n", encoding="utf-8")
            names = [p.name for p in sws.workflow_files(root)]
        self.assertEqual(names, ["a.yml", "b.yaml"])


class GhFailureHandling(unittest.TestCase):
    """F1: a failed `gh` call must never be indistinguishable from 'no data'."""

    @staticmethod
    @contextlib.contextmanager
    def _gh_returning(returncode: int, stdout: str = "", stderr: str = ""):
        original = subprocess.run

        def fake_run(*_args, **_kwargs):
            return subprocess.CompletedProcess(
                args=["gh"], returncode=returncode, stdout=stdout, stderr=stderr
            )

        subprocess.run = fake_run
        try:
            yield
        finally:
            subprocess.run = original

    def test_gh_raises_on_nonzero_exit(self):
        with self._gh_returning(1, stderr="HTTP 401: Bad credentials"):
            with self.assertRaises(sws.GhError) as ctx:
                sws._gh(["api", "repos/o/r/actions/workflows"])
        self.assertIn("Bad credentials", str(ctx.exception))

    def test_has_any_run_raises_rather_than_returning_false(self):
        """The false-green this guards: gh fails -> False -> 'no runs yet'."""
        with self._gh_returning(1, stderr="rate limit exceeded"):
            with self.assertRaises(sws.GhError):
                sws.has_any_run("o/r", "nightly.yml")

    def test_last_success_raises_rather_than_returning_none(self):
        """The bogus alert this guards: gh fails -> None -> 'NEVER succeeded'."""
        with self._gh_returning(1, stderr="rate limit exceeded"):
            with self.assertRaises(sws.GhError):
                sws.last_success("o/r", "nightly.yml")

    def test_gh_success_returns_stdout(self):
        with self._gh_returning(0, stdout="  12345\n"):
            self.assertTrue(sws.has_any_run("o/r", "nightly.yml"))

    def test_evaluate_propagates_gh_error(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "nightly.yml").write_text(
                "on:\n  schedule:\n    - cron: '0 4 * * *'\n", encoding="utf-8"
            )
            with self._gh_returning(1, stderr="HTTP 403"):
                with self.assertRaises(sws.GhError):
                    sws.evaluate("o/r", root, dt.datetime.now(dt.timezone.utc))

    def test_main_exits_nonzero_and_writes_no_output_on_gh_failure(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "nightly.yml").write_text(
                "on:\n  schedule:\n    - cron: '0 4 * * *'\n", encoding="utf-8"
            )
            output = root / "gh_output"
            output.write_text("", encoding="utf-8")
            code = _run_main(
                ["--repo", "o/r", "--workflows-dir", str(root), "--format", "github"],
                env={"GITHUB_OUTPUT": str(output)},
                gh=self._gh_returning(1, stderr="HTTP 403"),
            )
            self.assertEqual(code, 1)
            # No check6_* written -> repo-health.yml renders "check did not report".
            self.assertEqual(output.read_text(encoding="utf-8"), "")


class MainDirectoryGuards(unittest.TestCase):
    def test_missing_directory_exits_2(self):
        self.assertEqual(
            _run_main(["--repo", "o/r", "--workflows-dir", "/nonexistent/xyz"]), 2
        )

    def test_empty_directory_exits_2(self):
        """F2: a dir that exists but holds no workflow files scanned nothing."""
        with tempfile.TemporaryDirectory() as tmp:
            self.assertEqual(
                _run_main(["--repo", "o/r", "--workflows-dir", tmp]), 2
            )

    def test_directory_with_no_scheduled_workflow_is_not_green(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "onpush.yml").write_text(
                "on:\n  push:\n    branches: [develop]\n", encoding="utf-8"
            )
            out = io.StringIO()
            code = _run_main(
                ["--repo", "o/r", "--workflows-dir", tmp],
                gh=GhFailureHandling._gh_returning(0, stdout=""),
                stdout=out,
            )
        self.assertEqual(code, 0)
        # Assert on the summary line specifically — a per-entry line elsewhere
        # in stdout must not be able to pass or fail this by accident.
        status_line = next(
            line for line in out.getvalue().splitlines() if line.startswith("status:")
        )
        self.assertIn("no scheduled workflows found", status_line)
        self.assertNotIn("✅", status_line)

    def test_missing_repo_exits_2(self):
        self.assertEqual(_run_main(["--repo", ""], env={"REPO": ""}), 2)


def _run_main(argv, env=None, gh=None, stdout=None):
    """Invoke the script's main() with argv/env overrides, capturing output."""
    original_argv = sys.argv
    original_environ = dict(sws.os.environ)
    sys.argv = ["scheduled-workflow-staleness.py", *argv]
    if env:
        sws.os.environ.update(env)
    sink = stdout if stdout is not None else io.StringIO()
    try:
        errsink = io.StringIO()
        with contextlib.redirect_stdout(sink), contextlib.redirect_stderr(errsink):
            if gh is not None:
                with gh:
                    return sws.main()
            return sws.main()
    finally:
        sys.argv = original_argv
        sws.os.environ.clear()
        sws.os.environ.update(original_environ)


class CronSchedules(unittest.TestCase):
    def test_weekly_interval(self):
        self.assertEqual(
            sws.CronSchedule("0 4 * * 0").interval_seconds(), 7 * 24 * 3600
        )

    def test_daily_interval(self):
        self.assertEqual(sws.CronSchedule("0 4 * * *").interval_seconds(), 24 * 3600)

    def test_bad_expression_raises(self):
        with self.assertRaises(sws.CronError):
            sws.CronSchedule("0 4 * *")


if __name__ == "__main__":
    unittest.main(verbosity=2)
