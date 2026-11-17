#!/usr/bin/env python3
"""Tests for orphaned-agent-issues.py.

Stdlib `unittest` only, like the other health-check tests. No network: the
issues are built here in the shape the GraphQL query returns.

Run with:
    python3 .github/scripts/test_orphaned_agent_issues.py
"""

from __future__ import annotations

import contextlib
import datetime as dt
import importlib.util
import io
import json
import tempfile
import unittest
from pathlib import Path

_SCRIPT = Path(__file__).resolve().parent / "orphaned-agent-issues.py"
_spec = importlib.util.spec_from_file_location("orphaned_agent_issues", _SCRIPT)
orphans = importlib.util.module_from_spec(_spec)
assert _spec.loader is not None
_spec.loader.exec_module(orphans)

NOW = dt.datetime(2026, 11, 17, 0, 0, tzinfo=dt.timezone.utc)


def issue(number: int, hours_old: int = 100, closing=(), mentions=(), connected=(), title: str | None = None) -> dict:
    """An open agent-work issue. Pull requests are (number, state) pairs."""
    def pull(pair):
        return {"number": pair[0], "state": pair[1]}

    created = NOW - dt.timedelta(hours=hours_old)
    return {
        "number": number,
        "title": title or f"Issue {number}",
        "createdAt": created.strftime("%Y-%m-%dT%H:%M:%SZ"),
        "closedByPullRequestsReferences": {"nodes": [pull(p) for p in closing]},
        "timelineItems": {"nodes": [{"source": pull(p)} for p in mentions] + [{"subject": pull(p)} for p in connected]},
    }


def numbers(issues, branches=(), **options) -> list[int]:
    return [o["number"] for o in orphans.find_orphans(list(issues), list(branches), NOW, **options)]


class OrphanTests(unittest.TestCase):

    def test_an_old_issue_with_no_pull_request_is_orphaned(self):
        self.assertEqual(numbers([issue(10)]), [10])

    def test_an_issue_younger_than_the_limit_is_not(self):
        self.assertEqual(numbers([issue(10, hours_old=23)]), [])
        self.assertEqual(numbers([issue(10, hours_old=24)]), [10])
        self.assertEqual(numbers([issue(10, hours_old=30)], min_age_hours=48), [])

    def test_an_open_pull_request_that_closes_it_links_it(self):
        self.assertEqual(numbers([issue(10, closing=[(50, "OPEN")])]), [])

    # The two issues the old search-based check kept reporting: the fix was
    # merged from a branch not named after the issue, and the issue stayed open
    # for a device check.
    def test_a_merged_pull_request_that_mentions_it_links_it(self):
        self.assertEqual(numbers([issue(3761, mentions=[(3763, "MERGED")])]), [])
        self.assertEqual(numbers([issue(3726, mentions=[(3799, "MERGED")])]), [])

    def test_a_pull_request_connected_in_the_development_panel_links_it(self):
        self.assertEqual(numbers([issue(10, connected=[(50, "OPEN")])]), [])

    def test_a_pull_request_closed_without_merging_does_not_link_it(self):
        self.assertEqual(numbers([issue(10, closing=[(50, "CLOSED")], mentions=[(51, "CLOSED")])]), [10])
        self.assertEqual(numbers([issue(10, mentions=[(51, "CLOSED"), (52, "MERGED")])]), [])

    def test_a_mention_from_another_issue_is_not_a_pull_request(self):
        mentioned_by_issue = issue(10)
        mentioned_by_issue["timelineItems"]["nodes"] = [{"source": {}}, {}, None]
        self.assertEqual(numbers([mentioned_by_issue]), [10])

    def test_an_open_branch_named_for_the_issue_links_it(self):
        branches = [{"number": 60, "headRefName": "agent/issue-10"}]
        self.assertEqual(numbers([issue(10)], branches), [])
        self.assertEqual(numbers([issue(10)], [{"number": 61, "headRefName": "fix/issue-10-crash"}]), [])

    def test_a_branch_for_another_issue_number_does_not(self):
        for branch in ("agent/issue-100", "agent/issue-1", "agent/reissue-10"):
            with self.subTest(branch=branch):
                self.assertEqual(numbers([issue(10)], [{"number": 60, "headRefName": branch}]), [10])

    def test_the_report_issue_is_skipped_by_title(self):
        issues = [issue(3666, title="Automation Health Monitor"), issue(11)]
        self.assertEqual(numbers(issues, skip_titles=("Automation Health Monitor",)), [11])
        self.assertEqual(numbers(issues), [3666, 11])

    def test_orphans_come_oldest_first_and_summarise_like_the_report(self):
        found = orphans.find_orphans([issue(1, hours_old=30), issue(2, hours_old=500), issue(3, closing=[(9, "OPEN")])], [], NOW)
        result = orphans.summary(found)
        self.assertEqual(result["count"], 2)
        self.assertEqual(result["detail"], " #2 (500h) #1 (30h)")
        self.assertEqual(orphans.summary([]), {"count": 0, "detail": "", "orphans": []})


class CommandLineTests(unittest.TestCase):

    def run_main(self, *args: str) -> tuple[int, str]:
        out = io.StringIO()
        with contextlib.redirect_stdout(out), contextlib.redirect_stderr(out):
            code = orphans.main(list(args))
        return code, out.getvalue()

    def test_json_output_from_files(self):
        with tempfile.TemporaryDirectory() as folder:
            issues_path = Path(folder) / "issues.json"
            branches_path = Path(folder) / "branches.json"
            issues_path.write_text(json.dumps([issue(10), issue(11), issue(12, title="Automation Health Monitor")]))
            branches_path.write_text(json.dumps([{"number": 60, "headRefName": "agent/issue-11"}]))
            code, output = self.run_main("--input", str(issues_path), "--open-branches", str(branches_path),
                                         "--skip-title", "Automation Health Monitor",
                                         "--now", "2026-11-17T00:00:00Z", "--format", "json")
        self.assertEqual(code, 0)
        self.assertEqual(json.loads(output), {
            "count": 1, "detail": " #10 (100h)",
            "orphans": [{"number": 10, "title": "Issue 10", "age_hours": 100}],
        })

    # A failed read must not look like "no orphans".
    def test_an_unreadable_source_fails_instead_of_reporting_none(self):
        code, output = self.run_main("--input", "/nonexistent/issues.json", "--format", "json")
        self.assertEqual(code, 2)
        self.assertNotIn('"count"', output)


if __name__ == "__main__":
    unittest.main()
