#!/usr/bin/env python3
"""Detect scheduled workflows whose *scheduled* runs have stopped succeeding.

This is deliberately orthogonal to the 24h failure-rate check in
repo-health.yml. A failure *rate* check can never fire for a low-frequency
workflow: a `cron: '0 4 * * 0'` job runs once a week, so it can produce at
most one failure in any 24h window and can never cross a "> 3 failures"
threshold. update-catalogs.yml failed 23 out of 23 scheduled runs over five
months and was invisible to that check by construction.

Staleness asks a different question — "when did this workflow's scheduled
path last actually work?" — and alerts when the answer is older than a
multiple of the workflow's own cron interval.

Usage:
    scheduled-workflow-staleness.py [--repo OWNER/REPO] [--workflows-dir DIR]
                                    [--now ISO8601] [--format text|github]

Exits 0 whether or not anything is stale; the caller decides what to do with
the report. Exits non-zero only on an internal error.
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys
from pathlib import Path

# A workflow is considered stale when its last successful scheduled run is
# older than max(STALE_MULTIPLIER x cron interval, STALE_FLOOR_SECONDS).
#
# The floor keeps high-frequency workflows from alarming on GitHub's own
# scheduler jitter — scheduled runs are queued on a best-effort basis and are
# routinely delayed (or dropped) under load. Fast workflows are already well
# covered by the 24h failure-rate check; this check exists for the slow ones.
STALE_MULTIPLIER = 2
STALE_FLOOR_SECONDS = 6 * 3600

# Events that exercise the workflow the way its schedule does: the full job
# graph, with no `paths:` filter or pull-request-only conditional narrowing it
# to a subset. A green `push` run is NOT evidence the scheduled path works —
# that is exactly how consolidate-changelog.yml's cancelled cron run hid
# behind a passing pull_request run.
SUCCESS_EVENTS = ("schedule", "workflow_dispatch")

# Reference instant for cron-interval derivation. Fixed, never `now`, so the
# derived interval is identical on every run instead of jittering with the
# clock.
CRON_EPOCH = dt.datetime(2025, 1, 1, tzinfo=dt.timezone.utc)
CRON_WINDOW_MINUTES = 4 * 7 * 24 * 60      # 4 weeks — covers minute..weekly
CRON_WIDE_WINDOW_MINUTES = 400 * 24 * 60   # ~13 months — for monthly+ crons
CRON_FALLBACK_INTERVAL = 24 * 3600

MONTH_NAMES = {
    "jan": 1, "feb": 2, "mar": 3, "apr": 4, "may": 5, "jun": 6,
    "jul": 7, "aug": 8, "sep": 9, "oct": 10, "nov": 11, "dec": 12,
}
DOW_NAMES = {
    "sun": 0, "mon": 1, "tue": 2, "wed": 3, "thu": 4, "fri": 5, "sat": 6,
}


# ── Cron parsing ──────────────────────────────────────────────────────────

class CronError(ValueError):
    """Raised for a cron expression we cannot interpret."""


def _parse_field(expr: str, lo: int, hi: int, names: dict[str, int] | None = None) -> set[int]:
    """Expand one cron field ("*/10", "1-5", "MON,WED", "4") into a value set."""
    def to_num(token: str) -> int:
        token = token.strip().lower()
        if names and token in names:
            return names[token]
        if not re.fullmatch(r"\d+", token):
            raise CronError(f"unrecognised value {token!r}")
        return int(token)

    values: set[int] = set()
    for part in expr.split(","):
        part = part.strip()
        if not part:
            raise CronError("empty list element")
        step = 1
        if "/" in part:
            part, raw_step = part.split("/", 1)
            if not re.fullmatch(r"\d+", raw_step) or int(raw_step) == 0:
                raise CronError(f"bad step {raw_step!r}")
            step = int(raw_step)
        if part in ("*", "?"):
            start, end = lo, hi
        elif "-" in part.lstrip("-"):
            raw_start, raw_end = part.split("-", 1)
            start, end = to_num(raw_start), to_num(raw_end)
        else:
            start = end = to_num(part)
            if step > 1:  # "5/15" means "from 5 to the end of the range, step 15"
                end = hi
        if start > end or start < lo or end > hi:
            raise CronError(f"value out of range in {expr!r}")
        values.update(range(start, end + 1, step))
    if not values:
        raise CronError(f"field {expr!r} matches nothing")
    return values


class CronSchedule:
    """A 5-field cron expression, evaluated by direct matching."""

    def __init__(self, expression: str) -> None:
        fields = expression.split()
        if len(fields) != 5:
            raise CronError(f"expected 5 fields, got {len(fields)}: {expression!r}")
        minute, hour, dom, month, dow = fields
        self.expression = expression
        self.minutes = _parse_field(minute, 0, 59)
        self.hours = _parse_field(hour, 0, 23)
        self.days = _parse_field(dom, 1, 31)
        self.months = _parse_field(month, 1, 12, MONTH_NAMES)
        # Cron allows both 0 and 7 for Sunday; normalise 7 down to 0.
        self.weekdays = {d % 7 for d in _parse_field(dow, 0, 7, DOW_NAMES)}
        self.dom_unrestricted = dom.strip() in ("*", "?")
        self.dow_unrestricted = dow.strip() in ("*", "?")

    def matches(self, when: dt.datetime) -> bool:
        if when.minute not in self.minutes or when.hour not in self.hours:
            return False
        if when.month not in self.months:
            return False
        # Standard cron: when day-of-month and day-of-week are BOTH restricted
        # they are OR'd, not AND'd.
        day_ok = when.day in self.days
        # datetime.isoweekday() is Mon=1..Sun=7; % 7 maps Sunday to 0 to match cron.
        weekday_ok = (when.isoweekday() % 7) in self.weekdays
        if self.dom_unrestricted and self.dow_unrestricted:
            return True
        if self.dom_unrestricted:
            return weekday_ok
        if self.dow_unrestricted:
            return day_ok
        return day_ok or weekday_ok

    def interval_seconds(self) -> int:
        """Median gap between consecutive firings, in seconds.

        Derived by stepping minute-by-minute from a fixed reference instant
        rather than by analysing the fields, so any expression a contributor
        adds later is handled without special cases (weekday-vs-day-of-month
        being the classic one that breaks field analysis).
        """
        for window in (CRON_WINDOW_MINUTES, CRON_WIDE_WINDOW_MINUTES):
            gaps = self._gaps(window)
            if gaps:
                gaps.sort()
                return gaps[len(gaps) // 2]
        return CRON_FALLBACK_INTERVAL

    def _gaps(self, window_minutes: int) -> list[int]:
        minute = dt.timedelta(minutes=1)
        cursor = CRON_EPOCH
        previous: dt.datetime | None = None
        gaps: list[int] = []
        for _ in range(window_minutes):
            if self.matches(cursor):
                if previous is not None:
                    gaps.append(int((cursor - previous).total_seconds()))
                previous = cursor
            cursor += minute
        return gaps


# ── Workflow discovery ────────────────────────────────────────────────────

def _indent_of(line: str) -> int:
    return len(line) - len(line.lstrip(" "))


def extract_cron_expressions(text: str) -> list[str]:
    """Return the cron expressions under the workflow's top-level `on:` key.

    Hand-rolled rather than PyYAML because (a) PyYAML is not guaranteed on
    the runner, and (b) YAML 1.1 parses the bare key `on` as the boolean
    True, which is a trap. Comment lines are skipped, so a commented-out
    `# - cron: ...` (testflight.yml has one) is correctly NOT reported.
    """
    lines = text.splitlines()
    crons: list[str] = []

    in_on = False
    on_indent = 0
    in_schedule = False
    schedule_indent = 0

    for raw in lines:
        stripped = raw.strip()
        if not stripped or stripped.startswith("#"):
            continue
        indent = _indent_of(raw)

        if not in_on:
            # Top-level `on:` — also accept the quoted forms people use to
            # dodge the YAML-boolean footgun.
            if indent == 0 and re.match(r"""^(on|"on"|'on')\s*:""", stripped):
                in_on = True
                on_indent = indent
            continue

        # Leaving the `on:` block returns us to scanning for it again.
        if indent <= on_indent:
            in_on = False
            in_schedule = False
            if indent == 0 and re.match(r"""^(on|"on"|'on')\s*:""", stripped):
                in_on = True
                on_indent = indent
            continue

        if not in_schedule:
            if re.match(r"^schedule\s*:", stripped):
                in_schedule = True
                schedule_indent = indent
            continue

        # A sequence item may sit at the SAME indentation as the key that owns
        # it — this is valid YAML and a common style:
        #     on:
        #       schedule:
        #       - cron: '0 4 * * 0'
        # Only a non-list-item key at or above `schedule:` ends the block.
        # Treating indent alone as the terminator silently dropped every cron
        # written that way, making such a workflow invisible to this check.
        if indent <= schedule_indent and not stripped.startswith("- "):
            in_schedule = False
            if re.match(r"^schedule\s*:", stripped):
                in_schedule = True
                schedule_indent = indent
            continue

        match = re.match(r"^-\s*cron\s*:\s*(.+)$", stripped)
        if match:
            value = match.group(1).strip()
            # Strip a trailing comment, but only outside quotes.
            if value[:1] in ("'", '"'):
                closing = value.find(value[0], 1)
                if closing != -1:
                    value = value[1:closing]
            else:
                value = value.split("#", 1)[0].strip()
            if value:
                crons.append(value)

    return crons


def discover_scheduled_workflows(workflows_dir: Path) -> list[tuple[str, list[str]]]:
    """[(filename, [cron, ...])] for every workflow with a real `schedule:`.

    Only the top level of the directory is scanned — `.github/workflows/disabled/`
    is not executed by GitHub and must not be monitored.
    """
    found: list[tuple[str, list[str]]] = []
    for path in sorted(workflows_dir.glob("*.y*ml")):
        if not path.is_file():
            continue
        try:
            text = path.read_text(encoding="utf-8")
        except OSError as exc:
            print(f"::warning::cannot read {path}: {exc}", file=sys.stderr)
            continue
        crons = extract_cron_expressions(text)
        if crons:
            found.append((path.name, crons))
    return found


# ── GitHub queries ────────────────────────────────────────────────────────

class GhError(RuntimeError):
    """A `gh` invocation failed. Never conflate this with "no data" — a
    silently-empty result here would make e.g. `has_any_run()` return False
    and the caller report a false-green "no runs yet" instead of surfacing
    that the check couldn't query Actions at all (auth/rate-limit/etc)."""


def _gh(args: list[str]) -> str:
    result = subprocess.run(
        ["gh", *args], capture_output=True, text=True, check=False
    )
    if result.returncode != 0:
        raise GhError(f"gh {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout.strip()


def workflow_states(repo: str) -> dict[str, str]:
    """{filename: state} — state is active / disabled_manually / disabled_inactivity."""
    raw = _gh([
        "api", f"repos/{repo}/actions/workflows", "--paginate",
        "--jq", ".workflows[] | [.path, .state] | @tsv",
    ])
    states: dict[str, str] = {}
    for line in raw.splitlines():
        if "\t" not in line:
            continue
        path, state = line.split("\t", 1)
        states[Path(path).name] = state.strip()
    return states


def last_success(repo: str, workflow: str) -> dt.datetime | None:
    """Most recent successful run triggered by schedule or workflow_dispatch.

    Status and event are filtered server-side, so pagination can't hide an old
    success behind a wall of recent push runs, and in-progress runs (whose
    `conclusion` is null) are never mistaken for anything.
    """
    newest: dt.datetime | None = None
    for event in SUCCESS_EVENTS:
        raw = _gh([
            "run", "list", "--repo", repo, "--workflow", workflow,
            "--event", event, "--status", "success", "--limit", "1",
            "--json", "createdAt", "--jq", ".[0].createdAt // empty",
        ])
        if not raw:
            continue
        stamp = dt.datetime.fromisoformat(raw.replace("Z", "+00:00"))
        if newest is None or stamp > newest:
            newest = stamp
    return newest


def has_any_run(repo: str, workflow: str) -> bool:
    raw = _gh([
        "run", "list", "--repo", repo, "--workflow", workflow, "--limit", "1",
        "--json", "databaseId", "--jq", ".[0].databaseId // empty",
    ])
    return bool(raw)


# ── Reporting ─────────────────────────────────────────────────────────────

def humanize(seconds: int) -> str:
    if seconds < 3600:
        return f"{seconds // 60}m"
    if seconds < 86400:
        return f"{seconds // 3600}h"
    return f"{seconds // 86400}d"


def evaluate(repo: str, workflows_dir: Path, now: dt.datetime) -> list[dict]:
    states = workflow_states(repo)
    results: list[dict] = []

    for filename, crons in discover_scheduled_workflows(workflows_dir):
        try:
            interval = min(CronSchedule(c).interval_seconds() for c in crons)
        except CronError as exc:
            results.append({
                "workflow": filename, "level": "warn",
                "detail": f"unparseable cron ({exc})",
            })
            continue

        threshold = max(STALE_MULTIPLIER * interval, STALE_FLOOR_SECONDS)
        state = states.get(filename, "active")

        # GitHub disables scheduled workflows after 60 days of repo inactivity.
        # That is silent rot of exactly the kind this check exists to catch.
        if state == "disabled_inactivity":
            results.append({
                "workflow": filename, "level": "stale",
                "detail": "disabled by GitHub for repo inactivity — schedule is not running",
            })
            continue
        if state == "disabled_manually":
            results.append({
                "workflow": filename, "level": "info",
                "detail": "disabled manually — not monitored",
            })
            continue

        success_at = last_success(repo, filename)
        if success_at is None:
            if not has_any_run(repo, filename):
                # Newly added schedule that has not had a chance to fire yet.
                results.append({
                    "workflow": filename, "level": "info",
                    "detail": f"no runs yet (every {humanize(interval)})",
                })
            else:
                results.append({
                    "workflow": filename, "level": "stale",
                    "detail": f"has run but NEVER succeeded (every {humanize(interval)})",
                })
            continue

        age = int((now - success_at).total_seconds())
        if age > threshold:
            results.append({
                "workflow": filename, "level": "stale",
                "detail": (
                    f"last success {humanize(age)} ago, "
                    f"expected every {humanize(interval)}"
                ),
            })
        else:
            results.append({
                "workflow": filename, "level": "ok",
                "detail": f"last success {humanize(age)} ago (every {humanize(interval)})",
            })

    return results


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--repo", default=os.environ.get("REPO", ""))
    parser.add_argument("--workflows-dir", default=".github/workflows")
    parser.add_argument("--now", default=None, help="ISO8601 override, for testing")
    parser.add_argument("--format", choices=("text", "github"), default="text")
    args = parser.parse_args()

    if not args.repo:
        print("error: --repo (or $REPO) is required", file=sys.stderr)
        return 2

    workflows_dir = Path(args.workflows_dir)
    if not workflows_dir.is_dir():
        # An empty scan reads identically to "nothing is scheduled", which
        # would render as a false-green "0 scheduled OK". A wrong path or a
        # checkout that never happened is an internal error, not a result.
        print(f"error: --workflows-dir {workflows_dir} is not a directory", file=sys.stderr)
        return 2

    now = (
        dt.datetime.fromisoformat(args.now.replace("Z", "+00:00"))
        if args.now
        else dt.datetime.now(dt.timezone.utc)
    )

    try:
        results = evaluate(args.repo, workflows_dir, now)
    except GhError as exc:
        # Propagated from _gh(): a `gh` call failed outright (auth,
        # rate-limit, network). Abort rather than let the caller mistake a
        # missing GITHUB_OUTPUT write for "check did not report" — see the
        # module docstring: exits non-zero only on internal error.
        print(f"::error::{exc}", file=sys.stderr)
        return 1

    icon = {"ok": "✅", "stale": "🚨", "warn": "⚠️", "info": "ℹ️"}
    for entry in results:
        print(f"  {icon[entry['level']]} {entry['workflow']}: {entry['detail']}")

    stale = [e for e in results if e["level"] == "stale"]
    warn = [e for e in results if e["level"] == "warn"]

    if stale:
        status = f"🚨 {len(stale)} stale"
        detail = "; ".join(f"{e['workflow']} — {e['detail']}" for e in stale)
    elif warn:
        status = f"⚠️ {len(warn)} unparseable"
        detail = "; ".join(f"{e['workflow']} — {e['detail']}" for e in warn)
    else:
        status = f"✅ {len(results)} scheduled OK"
        detail = ""

    print(f"\nstatus: {status}")
    print(f"detail: {detail}")

    if args.format == "github":
        output_path = os.environ.get("GITHUB_OUTPUT")
        if output_path:
            with open(output_path, "a", encoding="utf-8") as handle:
                handle.write(f"check6_status={status}\n")
                handle.write(f"check6_detail={detail}\n")
        print(json.dumps({"status": status, "detail": detail, "results": results}))

    return 0


if __name__ == "__main__":
    sys.exit(main())
