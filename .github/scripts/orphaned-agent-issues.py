#!/usr/bin/env python3
"""Find open `agent-work` issues that no pull request is working on.

Used by repo-health.yml (Check 4). An issue is orphaned when it has been open
longer than --min-age-hours and no pull request is linked to it. A pull request
is linked when it is open or merged and any of these holds:

  - it closes the issue (a closing keyword, or the issue's Development panel);
  - it mentions the issue (a cross-reference in the issue's timeline);
  - its branch is named for the issue: `agent/issue-<N>` or `…/issue-<N>-…`.

A pull request that was closed without merging does not count: that work was
dropped. A merged one does: the work landed, and the issue is open for another
reason (a device check, a follow-up), which is not what this check is for.

The check used to search open pull requests for the text `agent/issue-<N>`.
GitHub's search splits that into words, so it matched unrelated pull requests,
and it never saw a pull request on another branch name or one already merged.

Stdlib only; reads GitHub through the `gh` CLI (GH_TOKEN in the environment).

Usage:
  orphaned-agent-issues.py --repo owner/name [--skip-title TITLE] [--format json]
  orphaned-agent-issues.py --input issues.json --open-branches branches.json   # offline
"""

from __future__ import annotations

import argparse
import datetime as dt
import json
import os
import re
import subprocess
import sys

LABEL = "agent-work"
MIN_AGE_HOURS = 24
LINKED_STATES = ("OPEN", "MERGED")
PAGE_SIZE = 50

QUERY = """
query($owner: String!, $name: String!, $label: String!, $pageSize: Int!, $cursor: String) {
  repository(owner: $owner, name: $name) {
    issues(labels: [$label], states: OPEN, first: $pageSize, after: $cursor) {
      pageInfo { hasNextPage endCursor }
      nodes {
        number
        title
        createdAt
        closedByPullRequestsReferences(first: 20, includeClosedPrs: true) {
          nodes { number state }
        }
        timelineItems(itemTypes: [CROSS_REFERENCED_EVENT, CONNECTED_EVENT], first: 100) {
          nodes {
            ... on CrossReferencedEvent { source { ... on PullRequest { number state } } }
            ... on ConnectedEvent { subject { ... on PullRequest { number state } } }
          }
        }
      }
    }
  }
}
"""


def _gh(args: list[str]) -> str:
    result = subprocess.run(["gh", *args], text=True, capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"gh {' '.join(args[:3])} failed: {result.stderr.strip()}")
    return result.stdout


def fetch_issues(repo: str, label: str) -> list[dict]:
    """Every open issue with `label`, with the pull requests GitHub links to it."""
    owner, name = repo.split("/", 1)
    issues: list[dict] = []
    cursor = None
    while True:
        args = ["api", "graphql", "-f", f"query={QUERY}", "-f", f"owner={owner}", "-f", f"name={name}",
                "-f", f"label={label}", "-F", f"pageSize={PAGE_SIZE}"]
        if cursor:
            args += ["-f", f"cursor={cursor}"]
        page = json.loads(_gh(args))["data"]["repository"]["issues"]
        issues.extend(page["nodes"])
        if not page["pageInfo"]["hasNextPage"]:
            return issues
        cursor = page["pageInfo"]["endCursor"]


def fetch_open_branches(repo: str) -> list[dict]:
    """[{number, headRefName}] for the open pull requests."""
    return json.loads(_gh(["pr", "list", "--repo", repo, "--state", "open", "--limit", "300",
                           "--json", "number,headRefName"]))


def branch_names_issue(branch: str, issue_number: int) -> bool:
    """True for `agent/issue-12`, `fix/issue-12-thing`, not for `agent/issue-123`."""
    return re.search(rf"(?:^|/)issue-{issue_number}(?!\d)", branch) is not None


def linked_pull_requests(issue: dict, open_branches: list[dict]) -> dict[int, str]:
    """{pull request number: state} for the open or merged pull requests linked to `issue`."""
    found: dict[int, str] = {}
    closing = (issue.get("closedByPullRequestsReferences") or {}).get("nodes") or []
    timeline = (issue.get("timelineItems") or {}).get("nodes") or []
    mentioned = [event.get("source") or event.get("subject") for event in timeline if event]
    for pull in [*closing, *mentioned]:
        # A cross-reference from another issue comes back as an empty object.
        if pull and pull.get("number") and pull.get("state") in LINKED_STATES:
            found[pull["number"]] = pull["state"]
    for pull in open_branches:
        if branch_names_issue(pull.get("headRefName") or "", issue["number"]):
            found[pull["number"]] = "OPEN"
    return found


def find_orphans(issues: list[dict], open_branches: list[dict], now: dt.datetime,
                 min_age_hours: int = MIN_AGE_HOURS, skip_titles: tuple[str, ...] = ()) -> list[dict]:
    """The issues nobody is working on, oldest first: [{number, title, age_hours}]."""
    orphans = []
    for issue in issues:
        if issue["title"] in skip_titles:
            continue
        created = dt.datetime.fromisoformat(issue["createdAt"].replace("Z", "+00:00"))
        age_hours = int((now - created).total_seconds() // 3600)
        if age_hours < min_age_hours or linked_pull_requests(issue, open_branches):
            continue
        orphans.append({"number": issue["number"], "title": issue["title"], "age_hours": age_hours})
    return sorted(orphans, key=lambda orphan: -orphan["age_hours"])


def summary(orphans: list[dict]) -> dict:
    """What the health report shows: a count and ` #12 (30h) #15 (26h)`."""
    return {
        "count": len(orphans),
        "detail": "".join(f" #{orphan['number']} ({orphan['age_hours']}h)" for orphan in orphans),
        "orphans": orphans,
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Find open agent-work issues with no linked pull request.")
    parser.add_argument("--repo", default=os.environ.get("REPO", ""))
    parser.add_argument("--label", default=LABEL)
    parser.add_argument("--min-age-hours", type=int, default=MIN_AGE_HOURS)
    parser.add_argument("--skip-title", action="append", default=[],
                        help="exact title of an issue to leave out (the health report's own issue)")
    parser.add_argument("--now", default=None, help="ISO 8601 override, for testing")
    parser.add_argument("--input", help="read the issues from this JSON file instead of GitHub")
    parser.add_argument("--open-branches", help="read the open pull requests from this JSON file")
    parser.add_argument("--format", choices=("text", "json"), default="text")
    args = parser.parse_args(argv)

    now = dt.datetime.fromisoformat(args.now.replace("Z", "+00:00")) if args.now else dt.datetime.now(dt.timezone.utc)
    try:
        if args.input:
            with open(args.input, encoding="utf-8") as handle:
                issues = json.load(handle)
        else:
            if "/" not in args.repo:
                parser.error("--repo owner/name (or $REPO) is required")
            issues = fetch_issues(args.repo, args.label)
        if args.open_branches:
            with open(args.open_branches, encoding="utf-8") as handle:
                open_branches = json.load(handle)
        else:
            open_branches = [] if args.input else fetch_open_branches(args.repo)
    except (RuntimeError, OSError, ValueError, KeyError, TypeError) as error:
        print(f"orphaned-agent-issues: {error}", file=sys.stderr)
        return 2

    result = summary(find_orphans(issues, open_branches, now, args.min_age_hours, tuple(args.skip_title)))
    if args.format == "json":
        print(json.dumps(result))
        return 0
    print(f"{len(issues)} open {args.label} issue(s), {result['count']} with no linked pull request")
    for orphan in result["orphans"]:
        print(f"  #{orphan['number']} orphaned for {orphan['age_hours']}h: {orphan['title']}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
