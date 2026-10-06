#!/usr/bin/env python3
"""maint — find and run Provenance's maintenance scripts.

Every recurring job (generators, audits, RetroArch core pins, release helpers) is
declared in Scripts/maint/jobs.toml. This tool reads that registry and:

  status    shows which jobs are stale and why, plus scripts nobody registered
  list      describes every job and the exact command it runs
  run       runs jobs from the repo root (or every stale one)
  serve     opens a local web dashboard with the same data and Run buttons
  report    prints a Markdown summary (used by CI for its PR and tracking issue)
  hooks     installs a report-only git hook
  schedule  installs an opt-in launchd job that runs stale `auto` jobs in a
            separate worktree and opens a pull request

Staleness comes from git history, not file timestamps, so a fresh CI checkout
gets the same answer as your working copy. See Scripts/maint/README.md.

Requires Python 3.11+ (for tomllib). Standard library only.
"""
from __future__ import annotations

import sys

if sys.version_info < (3, 11):
    if "--quiet" not in sys.argv:
        sys.stderr.write(
            f"maint needs Python 3.11+ (this is {sys.version.split()[0]} at {sys.executable}).\n"
            "Install one with `brew install python` and run it with that python3.\n"
        )
    sys.exit(0 if "--quiet" in sys.argv else 2)

import argparse
import json
import os
import platform
import re
import shlex
import shutil
import socket
import subprocess
import threading
import time
import tomllib
from dataclasses import dataclass, field
from pathlib import Path
from typing import Callable, Iterable

REPO_ROOT = Path(__file__).resolve().parents[2]
MAINT_DIR = Path(__file__).resolve().parent
REGISTRY_PATH = MAINT_DIR / "jobs.toml"
STATE_DIR = REPO_ROOT / ".maint"
STATE_PATH = STATE_DIR / "state.json"
LOG_DIR = STATE_DIR / "logs"

CHECK_TIMEOUT_SECONDS = 180
CHECK_CACHE_SECONDS = 6 * 60 * 60
NETWORK_PROBE = ("github.com", 443)

# A `check` command reports with its exit code.
CHECK_CURRENT, CHECK_STALE = 0, 1

CURRENT, STALE, ON_DEMAND, ERROR = "current", "stale", "on-demand", "error"
STATE_ORDER = {STALE: 0, ERROR: 1, CURRENT: 2, ON_DEMAND: 3}

HOOK_MARKER = "# provenance-maint hook"
HOOK_NAMES = ("post-merge", "post-checkout")

LAUNCHD_LABEL = "org.provenance-emu.maint"
SCHEDULE_BRANCH = "maint/auto-local"
SCHEDULE_WORKTREE = Path.home() / "Library" / "Caches" / "provenance-maint" / "worktree"
SCHEDULE_LOG = Path.home() / "Library" / "Logs" / "provenance-maint.log"

_DURATION_UNITS = {"m": 60, "h": 3600, "d": 86400, "w": 7 * 86400}


# --------------------------------------------------------------------------- registry


@dataclass
class Job:
    id: str
    title: str
    category: str
    description: str = ""
    run: list[str] | str | None = None
    check: list[str] | str | None = None
    mode: str = "manual"
    inputs: list[str] = field(default_factory=list)
    outputs: list[str] = field(default_factory=list)
    max_age: int | None = None
    max_age_text: str | None = None
    needs: list[str] = field(default_factory=list)
    files: list[str] = field(default_factory=list)
    args_hint: str | None = None
    reason_pattern: str | None = None

    @property
    def has_rules(self) -> bool:
        return bool(self.inputs or self.outputs or self.max_age or self.check)

    def command_text(self, command: list[str] | str | None) -> str:
        if command is None:
            return ""
        return command if isinstance(command, str) else shlex.join(command)

    def referenced_paths(self) -> set[str]:
        """Repo files this job's commands mention (used for implicit inputs)."""
        found = set()
        for command in (self.run, self.check):
            text = self.command_text(command)
            for token in re.findall(r"[A-Za-z0-9_./()-]+", text):
                token = token.strip("()")
                if token and not token.startswith("-") and (REPO_ROOT / token).is_file():
                    found.add(token)
        return found


@dataclass
class Registry:
    jobs: dict[str, Job]
    ignore: list[str]
    scan_roots: list[str]
    scan_extensions: list[str]
    skip_dirs: list[str]


def parse_duration(text: str) -> int:
    match = re.fullmatch(r"\s*(\d+)\s*([mhdw])\s*", text)
    if not match:
        raise ValueError(f"bad duration {text!r}: use a number and one of m/h/d/w, e.g. '30d'")
    return int(match.group(1)) * _DURATION_UNITS[match.group(2)]


def load_registry(path: Path = REGISTRY_PATH) -> Registry:
    with path.open("rb") as handle:
        data = tomllib.load(handle)
    jobs = {}
    for job_id, raw in data.get("jobs", {}).items():
        unknown = set(raw) - {
            "title", "category", "description", "run", "check", "mode", "inputs", "outputs",
            "max_age", "needs", "files", "args_hint", "reason_pattern",
        }
        if unknown:
            raise ValueError(f"job {job_id}: unknown keys {sorted(unknown)}")
        mode = raw.get("mode", "manual")
        if mode not in ("auto", "manual"):
            raise ValueError(f"job {job_id}: mode must be 'auto' or 'manual'")
        if mode == "auto" and not raw.get("run"):
            raise ValueError(f"job {job_id}: an auto job needs a `run` command")
        max_age_text = raw.get("max_age")
        jobs[job_id] = Job(
            id=job_id,
            title=raw.get("title", job_id),
            category=raw.get("category", "other"),
            description=raw.get("description", "").strip(),
            run=raw.get("run"),
            check=raw.get("check"),
            mode=mode,
            inputs=list(raw.get("inputs", [])),
            outputs=list(raw.get("outputs", [])),
            max_age=parse_duration(max_age_text) if max_age_text else None,
            max_age_text=max_age_text,
            needs=list(raw.get("needs", [])),
            files=list(raw.get("files", [])),
            args_hint=raw.get("args_hint"),
            reason_pattern=raw.get("reason_pattern"),
        )
    scan = data.get("scan", {})
    return Registry(
        jobs=jobs,
        ignore=list(data.get("ignore", {}).get("paths", [])),
        scan_roots=list(scan.get("roots", ["Scripts"])),
        scan_extensions=list(scan.get("extensions", [".py", ".sh"])),
        skip_dirs=list(scan.get("skip_dirs", [])),
    )


# --------------------------------------------------------------------------- helpers


def glob_to_regex(pattern: str) -> re.Pattern[str]:
    """`**` crosses directories, `*` and `?` stay within one path segment."""
    out, i = [], 0
    while i < len(pattern):
        char = pattern[i]
        if pattern.startswith("**/", i):
            out.append("(?:.*/)?")
            i += 3
            continue
        if pattern.startswith("**", i):
            out.append(".*")
            i += 2
            continue
        out.append({"*": "[^/]*", "?": "[^/]"}.get(char, re.escape(char)))
        i += 1
    return re.compile("".join(out) + r"\Z")


def matches_any(path: str, patterns: Iterable[str]) -> bool:
    return any(glob_to_regex(pattern).match(path) for pattern in patterns)


def git(*args: str, cwd: Path | None = None, check: bool = True) -> str:
    result = subprocess.run(["git", *args], cwd=cwd or REPO_ROOT, text=True, capture_output=True)
    if check and result.returncode != 0:
        raise RuntimeError(f"git {' '.join(args)} failed: {result.stderr.strip()}")
    return result.stdout


def pathspecs(patterns: Iterable[str]) -> list[str]:
    return [f":(glob){pattern}" for pattern in patterns]


def last_commit(patterns: list[str]) -> tuple[str, int] | None:
    """(sha, unix time) of the newest commit touching any of `patterns`."""
    if not patterns:
        return None
    out = git("log", "-1", "--format=%H %ct", "--", *pathspecs(patterns)).strip()
    if not out:
        return None
    sha, stamp = out.split()
    return sha, int(stamp)


def dirty_paths(patterns: list[str]) -> list[str]:
    if not patterns:
        return []
    out = git("status", "--porcelain", "--", *pathspecs(patterns))
    return [line[3:] for line in out.splitlines() if line.strip()]


def humanize_age(seconds: float) -> str:
    days = seconds / 86400
    if days >= 2:
        return f"{int(days)} days"
    hours = seconds / 3600
    if hours >= 2:
        return f"{int(hours)} hours"
    return f"{max(1, int(seconds // 60))} minutes"


# --------------------------------------------------------------------------- state


def load_state() -> dict:
    try:
        return json.loads(STATE_PATH.read_text())
    except (OSError, ValueError):
        return {"jobs": {}, "checks": {}}


def save_state(state: dict) -> None:
    STATE_DIR.mkdir(exist_ok=True)
    tmp = STATE_PATH.with_suffix(".tmp")
    tmp.write_text(json.dumps(state, indent=2, sort_keys=True))
    tmp.replace(STATE_PATH)


_state_lock = threading.Lock()


def update_state(mutator: Callable[[dict], None]) -> None:
    with _state_lock:
        state = load_state()
        state.setdefault("jobs", {})
        state.setdefault("checks", {})
        mutator(state)
        save_state(state)


# --------------------------------------------------------------------------- needs


_needs_cache: dict[str, str | None] = {}


def unmet_need(need: str) -> str | None:
    """None when the requirement is met, otherwise a short reason."""
    if need in _needs_cache:
        return _needs_cache[need]
    reason: str | None = None
    if need == "network":
        try:
            socket.create_connection(NETWORK_PROBE, timeout=3).close()
        except OSError:
            reason = "no network"
    elif need == "macos":
        if platform.system() != "Darwin":
            reason = "needs macOS"
    elif need == "submodules":
        out = git("submodule", "status", check=False)
        if any(line.startswith("-") for line in out.splitlines()):
            reason = "submodules not checked out"
    elif need.startswith("env:"):
        if not os.environ.get(need[4:]):
            reason = f"${need[4:]} not set"
    elif need.startswith("py:"):
        import importlib.util

        if importlib.util.find_spec(need[3:]) is None:
            reason = f"python module {need[3:]} missing"
    elif need.startswith("path:"):
        if not (REPO_ROOT / need[5:]).exists():
            reason = f"{need[5:]} missing"
    elif shutil.which(need) is None:
        reason = f"`{need}` not installed"
    _needs_cache[need] = reason
    return reason


def unmet_needs(job: Job) -> list[str]:
    return [reason for need in job.needs if (reason := unmet_need(need))]


# --------------------------------------------------------------------------- staleness


@dataclass
class JobStatus:
    job: Job
    state: str
    reasons: list[str]
    blocked: list[str]
    last_run: dict | None

    def to_json(self) -> dict:
        job = self.job
        return {
            "id": job.id,
            "title": job.title,
            "category": job.category,
            "description": job.description,
            "mode": job.mode,
            "state": self.state,
            "reasons": self.reasons,
            "blocked": self.blocked,
            "runnable": job.run is not None and not self.blocked,
            "run": job.command_text(job.run),
            "check": job.command_text(job.check),
            "args_hint": job.args_hint,
            "inputs": job.inputs,
            "outputs": job.outputs,
            "max_age": job.max_age_text,
            "needs": job.needs,
            "last_run": self.last_run,
        }


INTERPRETERS = {".sh": "bash", ".bash": "bash", ".py": "python3", ".rb": "ruby"}


def shell_command(command: list[str] | str, extra_args: list[str] | None = None) -> list[str]:
    extra_args = extra_args or []
    if isinstance(command, str):
        return ["bash", "-c", command + ' "$@"', "maint", *extra_args]
    program = REPO_ROOT / command[0]
    # Some checked-in scripts lack the execute bit; run those through their interpreter.
    if program.is_file() and not os.access(program, os.X_OK) and program.suffix in INTERPRETERS:
        return [INTERPRETERS[program.suffix], *command, *extra_args]
    return [*command, *extra_args]


def child_env() -> dict[str, str]:
    env = dict(os.environ)
    env["REPO_ROOT"] = str(REPO_ROOT)
    env["PYTHONDONTWRITEBYTECODE"] = "1"
    return env


def run_check(job: Job) -> tuple[int, str]:
    try:
        result = subprocess.run(
            shell_command(job.check), cwd=REPO_ROOT, env=child_env(), text=True,
            capture_output=True, timeout=CHECK_TIMEOUT_SECONDS,
        )
    except subprocess.TimeoutExpired:
        return 2, f"check timed out after {CHECK_TIMEOUT_SECONDS}s"
    except OSError as error:
        return 2, f"could not start check: {error}"
    output = (result.stdout + "\n" + result.stderr).strip()
    lines = [line.strip() for line in output.splitlines() if line.strip()]
    message = lines[-1] if lines else f"exit {result.returncode}"
    if job.reason_pattern:
        pattern = re.compile(job.reason_pattern)
        message = next((line for line in lines if pattern.search(line)), message)
    return result.returncode, message


def evaluate(job: Job, state: dict, *, run_checks: bool = True, refresh: bool = False) -> JobStatus:
    reasons: list[str] = []
    errors: list[str] = []
    blocked = unmet_needs(job)
    last_run = state.get("jobs", {}).get(job.id)
    now = time.time()

    inputs = sorted(set(job.inputs) | job.referenced_paths())
    if job.outputs:
        out_commit = last_commit(job.outputs)
        if out_commit is None:
            reasons.append("outputs have never been committed")
        elif inputs:
            # Commit order, not timestamps: commits made in the same second still count.
            behind = int(git("rev-list", "--count", f"{out_commit[0]}..HEAD", "--",
                             *pathspecs(inputs)).strip() or 0)
            in_commit = last_commit(inputs)
            # Regenerating after an input change can leave the outputs identical, so
            # nothing new gets committed. run_job records the input commit such a
            # no-change run verified; that commit still being the latest means current.
            verified = bool(last_run and in_commit and last_run.get("verified_inputs") == in_commit[0])
            if behind and not verified:
                if dirty_paths(job.outputs):
                    reasons.append("outputs regenerated but not committed yet")
                else:
                    changed = git("log", "-1", "--format=", "--name-only", in_commit[0], "--",
                                  *pathspecs(inputs)).split()
                    what = changed[0] if changed else "an input"
                    reasons.append(f"{what} changed in {behind} commit(s) since the outputs were regenerated")
        dirty_inputs = dirty_paths(job.inputs)
        if dirty_inputs and not dirty_paths(job.outputs):
            reasons.append(f"uncommitted change to {dirty_inputs[0]}")

    if job.max_age:
        reference = []
        if job.outputs and (out_commit := last_commit(job.outputs)):
            reference.append(out_commit[1])
        if last_run and last_run.get("last_success"):
            reference.append(last_run["last_success"])
        if not reference:
            reasons.append("never run on this machine")
        else:
            age = now - max(reference)
            if age > job.max_age:
                reasons.append(f"last refreshed {humanize_age(age)} ago (limit {job.max_age_text})")

    if job.check:
        cached = state.get("checks", {}).get(job.id)
        fresh = cached and now - cached.get("ts", 0) < CHECK_CACHE_SECONDS
        if fresh and not refresh:
            code, message = cached["exit"], cached["message"]
        elif run_checks and not blocked:
            code, message = run_check(job)
            update_state(lambda s: s["checks"].__setitem__(
                job.id, {"ts": time.time(), "exit": code, "message": message}))
        else:
            code, message = None, None
        if code == CHECK_STALE:
            reasons.append(message)
        elif code not in (None, CHECK_CURRENT):
            errors.append(f"check failed: {message}")

    if reasons:
        state_name = STALE
    elif errors:
        state_name, reasons = ERROR, errors
    elif job.has_rules:
        state_name = CURRENT
    else:
        state_name = ON_DEMAND
    return JobStatus(job, state_name, reasons, blocked, last_run)


def evaluate_all(registry: Registry, **kwargs) -> list[JobStatus]:
    state = load_state()
    statuses = [evaluate(job, state, **kwargs) for job in registry.jobs.values()]
    return sorted(statuses, key=lambda s: (s.job.category, STATE_ORDER[s.state], s.job.id))


# --------------------------------------------------------------------------- unregistered scripts


def unregistered_scripts(registry: Registry) -> list[str]:
    claimed_text = " ".join(
        job.command_text(job.run) + " " + job.command_text(job.check)
        for job in registry.jobs.values()
    )
    claim_patterns = [pattern for job in registry.jobs.values() for pattern in job.files]
    found = []
    for root in registry.scan_roots:
        base = REPO_ROOT / root
        if not base.is_dir():
            continue
        for path in base.rglob("*"):
            rel = path.relative_to(REPO_ROOT).as_posix()
            if any(part in registry.skip_dirs for part in path.relative_to(base).parts):
                continue
            if not path.is_file() or path.suffix not in registry.scan_extensions:
                continue
            if rel.startswith("Scripts/maint/"):
                continue
            if rel in claimed_text or matches_any(rel, claim_patterns) or matches_any(rel, registry.ignore):
                continue
            found.append(rel)
    return sorted(found)


def job_stub(path: str) -> str:
    stem = Path(path).stem.replace("_", "-").lower()
    runner = {".py": "python3 ", ".rb": "ruby ", ".swift": "swift "}.get(Path(path).suffix, "")
    return (
        f'[jobs.{stem}]\n'
        f'title = "TODO: what {Path(path).name} does"\n'
        f'category = "{Path(path).parent.name}"\n'
        f'run = "{runner}{path}"\n'
        f'mode = "manual"\n'
        f'# inputs = []   outputs = []   max_age = "30d"   needs = []\n'
    )


# --------------------------------------------------------------------------- running


@dataclass
class RunResult:
    job_id: str
    exit_code: int
    duration: float
    changed: list[str]
    log_path: Path


def porcelain_snapshot() -> set[str]:
    return set(git("status", "--porcelain", "--untracked-files=all").splitlines())


def run_job(job: Job, extra_args: list[str] | None = None, *, dry_run: bool = False,
            emit: Callable[[str], None] = print) -> RunResult:
    if job.run is None:
        raise ValueError(f"{job.id} has no `run` command — it is fixed by hand. {job.description}")
    command = shell_command(job.run, extra_args)
    LOG_DIR.mkdir(parents=True, exist_ok=True)
    log_path = LOG_DIR / f"{job.id}.log"
    emit(f"$ cd {REPO_ROOT}")
    emit(f"$ {shlex.join(command)}")
    if dry_run:
        return RunResult(job.id, 0, 0.0, [], log_path)

    before = porcelain_snapshot()
    started = time.time()
    with log_path.open("w") as log:
        log.write(f"$ {shlex.join(command)}\n")
        with subprocess.Popen(
            command, cwd=REPO_ROOT, env=child_env(), text=True,
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, bufsize=1,
        ) as process:
            assert process.stdout is not None
            for line in process.stdout:
                log.write(line)
                emit(line.rstrip("\n"))
            exit_code = process.wait()
    duration = time.time() - started
    changed = sorted(entry[3:] for entry in porcelain_snapshot() - before)
    # Outputs identical to what's committed: the committed outputs are proven
    # current for the inputs as of now (see `verified` in evaluate()).
    verified_inputs = None
    if exit_code == 0 and job.outputs and not dirty_paths(job.outputs):
        newest_input = last_commit(sorted(set(job.inputs) | job.referenced_paths()))
        verified_inputs = newest_input[0] if newest_input else None

    def record(state: dict) -> None:
        entry = state["jobs"].setdefault(job.id, {})
        entry.update({"last_run": started, "exit": exit_code, "duration": round(duration, 1),
                      "changed": changed, "verified_inputs": verified_inputs})
        if exit_code == 0:
            entry["last_success"] = started
        state["checks"].pop(job.id, None)  # re-check after a run

    update_state(record)
    verdict = "ok" if exit_code == 0 else f"FAILED (exit {exit_code})"
    detail = f"{len(changed)} file(s) changed" if changed else "nothing changed"
    emit(f"── {job.id}: {verdict} in {duration:.1f}s, {detail}")
    return RunResult(job.id, exit_code, duration, changed, log_path)


# --------------------------------------------------------------------------- output


STATE_ICONS = {CURRENT: "✅", STALE: "⚠️ ", ON_DEMAND: "· ", ERROR: "❌"}


def print_status(statuses: list[JobStatus], unknown: list[str], *, verbose: bool) -> None:
    category = None
    for status in statuses:
        if status.state == ON_DEMAND and not verbose:
            continue
        if status.job.category != category:
            category = status.job.category
            print(f"\n{category}")
        line = f"  {STATE_ICONS[status.state]} {status.job.id:<22} {status.job.title}"
        print(line)
        for reason in status.reasons:
            print(f"       ↳ {reason}")
        if status.blocked and status.state == STALE:
            print(f"       ⏭ can't run here: {', '.join(status.blocked)}")
    stale = [s for s in statuses if s.state == STALE]
    hidden = sum(1 for s in statuses if s.state == ON_DEMAND)
    print()
    if unknown:
        print(f"❓ {len(unknown)} script(s) not in Scripts/maint/jobs.toml:")
        for path in unknown:
            print(f"     {path}")
        print("   Add a job for each (`maint stub <path>` prints one) or list it under [ignore].")
    print(f"{len(stale)} stale, {sum(s.state == CURRENT for s in statuses)} current"
          + (f", {hidden} on-demand (use --all)" if hidden and not verbose else ""))
    if stale:
        auto = [s.job.id for s in stale if s.job.mode == "auto" and not s.blocked]
        if auto:
            print(f"Run the safe ones: python3 Scripts/maint/maint.py run --stale --auto-only")


def markdown_report(statuses: list[JobStatus], unknown: list[str], *, manual_only: bool,
                    ran: list[RunResult] | None = None) -> str:
    lines = []
    if ran:
        lines += ["### Regenerated", ""]
        for result in ran:
            mark = "✅" if result.exit_code == 0 else "❌"
            lines.append(f"- {mark} `{result.job_id}` — "
                         + (", ".join(f"`{c}`" for c in result.changed[:8]) or "no changes"))
        lines.append("")
    stale = [s for s in statuses if s.state in (STALE, ERROR)
             and (not manual_only or s.job.mode == "manual" or s.blocked)]
    if stale:
        lines += ["### Needs attention", "", "| Job | Why | Command |", "|---|---|---|"]
        for status in stale:
            why = "; ".join(status.reasons).replace("|", "\\|")
            if status.blocked:
                why += f" (can't run in CI: {', '.join(status.blocked)})"
            command = status.job.command_text(status.job.run) or "fix by hand"
            lines.append(f"| `{status.job.id}` — {status.job.title} | {why} | `{command}` |")
        lines.append("")
    if unknown:
        lines += ["### Scripts missing from `Scripts/maint/jobs.toml`", ""]
        lines += [f"- `{path}`" for path in unknown]
        lines += ["", "Add a job for each, or list it under `[ignore]`.", ""]
    if not lines:
        lines = ["Everything is current."]
    lines += ["", "_Generated by `python3 Scripts/maint/maint.py report`._"]
    return "\n".join(lines)


# --------------------------------------------------------------------------- hooks


def hooks_dir() -> Path:
    custom = git("config", "--get", "core.hooksPath", check=False).strip()
    if custom:
        return (REPO_ROOT / Path(custom).expanduser()).resolve()
    return (REPO_ROOT / git("rev-parse", "--git-path", "hooks").strip()).resolve()


def hook_body() -> str:
    return (
        "#!/bin/sh\n"
        f"{HOOK_MARKER} — report-only; remove with `maint.py hooks uninstall`\n"
        "root=\"$(git rev-parse --show-toplevel)\"\n"
        "command -v python3 >/dev/null 2>&1 || exit 0\n"
        "python3 \"$root/Scripts/maint/maint.py\" status --quiet --no-checks 2>/dev/null\n"
        "exit 0\n"
    )


def install_hooks() -> int:
    directory = hooks_dir()
    directory.mkdir(parents=True, exist_ok=True)
    for name in HOOK_NAMES:
        path = directory / name
        if path.exists() and HOOK_MARKER not in path.read_text(errors="ignore"):
            print(f"skipped {path}: an existing hook is there. Add this line to it:")
            print('  python3 "$(git rev-parse --show-toplevel)/Scripts/maint/maint.py" status --quiet --no-checks')
            continue
        path.write_text(hook_body())
        path.chmod(0o755)
        print(f"installed {path}")
    return 0


def uninstall_hooks() -> int:
    for name in HOOK_NAMES:
        path = hooks_dir() / name
        if path.exists() and HOOK_MARKER in path.read_text(errors="ignore"):
            path.unlink()
            print(f"removed {path}")
    return 0


# --------------------------------------------------------------------------- schedule (launchd)


def launchd_plist_path() -> Path:
    return Path.home() / "Library" / "LaunchAgents" / f"{LAUNCHD_LABEL}.plist"


def schedule_install(weekday: int, hour: int) -> int:
    if platform.system() != "Darwin":
        print("The local schedule uses launchd and only works on macOS.")
        return 2
    import plistlib

    plist = {
        "Label": LAUNCHD_LABEL,
        "ProgramArguments": [sys.executable, str(MAINT_DIR / "maint.py"), "schedule", "run"],
        "StartCalendarInterval": {"Weekday": weekday, "Hour": hour, "Minute": 0},
        "StandardOutPath": str(SCHEDULE_LOG),
        "StandardErrorPath": str(SCHEDULE_LOG),
        "EnvironmentVariables": {"PATH": os.environ.get("PATH", "/usr/bin:/bin")},
        "WorkingDirectory": str(REPO_ROOT),
    }
    path = launchd_plist_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(plistlib.dumps(plist))
    domain = f"gui/{os.getuid()}"
    subprocess.run(["launchctl", "bootout", domain, str(path)], capture_output=True)
    subprocess.run(["launchctl", "bootstrap", domain, str(path)], check=True)
    day = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"][weekday % 7]
    print(f"Scheduled every {day} at {hour:02d}:00 with {sys.executable}.")
    print(f"Runs stale `auto` jobs in {SCHEDULE_WORKTREE} on branch {SCHEDULE_BRANCH} and opens a PR.")
    print(f"Log: {SCHEDULE_LOG}")
    return 0


def schedule_uninstall() -> int:
    path = launchd_plist_path()
    if path.exists():
        subprocess.run(["launchctl", "bootout", f"gui/{os.getuid()}", str(path)], capture_output=True)
        path.unlink()
        print(f"removed {path}")
    else:
        print("no schedule installed")
    return 0


def schedule_run() -> int:
    """Run stale auto jobs in a dedicated worktree and open/update a pull request."""
    print(f"=== maint schedule run {time.strftime('%Y-%m-%d %H:%M:%S')}", flush=True)
    for need in ("network", "gh"):
        if reason := unmet_need(need):
            print(f"skipping: {reason}")
            return 0
    git("fetch", "--quiet", "origin", "develop")
    worktree = SCHEDULE_WORKTREE
    if (worktree / ".git").exists():
        git("checkout", "--quiet", "--force", "-B", SCHEDULE_BRANCH, "origin/develop", cwd=worktree)
        git("clean", "-fdqx", cwd=worktree)  # including .maint/: start from a clean slate
    else:
        worktree.parent.mkdir(parents=True, exist_ok=True)
        git("worktree", "prune")
        git("worktree", "add", "--force", "-B", SCHEDULE_BRANCH, str(worktree), "origin/develop")
    tool = worktree / "Scripts" / "maint" / "maint.py"
    result = subprocess.run([sys.executable, str(tool), "run", "--stale", "--auto-only", "--keep-going",
                             "--report", str(worktree / ".maint" / "report.md")], cwd=worktree)
    if not git("status", "--porcelain", cwd=worktree).strip():  # .maint/ is gitignored
        print("nothing changed")
        return result.returncode
    git("add", "-A", cwd=worktree)
    git("commit", "--quiet", "-m", "chore(maint): regenerate stale outputs",
        "-m", "Run by the local maint schedule (Scripts/maint/maint.py schedule run).", cwd=worktree)
    git("push", "--quiet", "--force", "origin", f"{SCHEDULE_BRANCH}:{SCHEDULE_BRANCH}", cwd=worktree)
    body_path = worktree / ".maint" / "report.md"
    existing = subprocess.run(
        ["gh", "pr", "list", "--head", SCHEDULE_BRANCH, "--state", "open", "--json", "number",
         "--jq", ".[0].number // empty"], cwd=worktree, text=True, capture_output=True).stdout.strip()
    if existing:
        subprocess.run(["gh", "pr", "edit", existing, "--body-file", str(body_path)], cwd=worktree)
        print(f"updated PR #{existing}")
    else:
        subprocess.run(["gh", "pr", "create", "--base", "develop", "--head", SCHEDULE_BRANCH,
                        "--title", "[Auto] Maintenance: regenerate stale outputs (local schedule)",
                        "--body-file", str(body_path)], cwd=worktree)
    return result.returncode


# --------------------------------------------------------------------------- CLI


def select_jobs(registry: Registry, ids: list[str], *, stale: bool, auto_only: bool) -> list[Job]:
    unknown = [job_id for job_id in ids if job_id not in registry.jobs]
    if unknown:
        raise SystemExit(f"unknown job(s): {', '.join(unknown)}. See `maint.py list`.")
    if ids:
        jobs = [registry.jobs[job_id] for job_id in ids]
    elif stale:
        statuses = evaluate_all(registry)
        jobs = [s.job for s in statuses if s.state == STALE and s.job.run and not s.blocked]
    else:
        raise SystemExit("name the job(s) to run, or pass --stale")
    if auto_only:
        jobs = [job for job in jobs if job.mode == "auto"]
    return jobs


def cmd_status(args: argparse.Namespace, registry: Registry) -> int:
    statuses = evaluate_all(registry, run_checks=not args.no_checks, refresh=args.refresh)
    unknown = unregistered_scripts(registry)
    stale = [s for s in statuses if s.state == STALE]
    if args.json:
        print(json.dumps({"jobs": [s.to_json() for s in statuses],
                          "unregistered": [{"path": p, "stub": job_stub(p)} for p in unknown]}, indent=2))
    elif args.quiet:
        if stale or unknown:
            parts = []
            if stale:
                parts.append(f"{len(stale)} maintenance job(s) stale ({', '.join(s.job.id for s in stale[:4])}"
                             + (", …" if len(stale) > 4 else "") + ")")
            if unknown:
                parts.append(f"{len(unknown)} unregistered script(s)")
            print(f"maint: {'; '.join(parts)} — run `make maint` to see them")
    else:
        print_status(statuses, unknown, verbose=args.all)
    return 1 if args.fail_on_stale and (stale or unknown) else 0


def cmd_list(args: argparse.Namespace, registry: Registry) -> int:
    if args.json:
        print(json.dumps([evaluate(job, load_state(), run_checks=False).to_json()
                          for job in registry.jobs.values()], indent=2))
        return 0
    category = None
    for job in sorted(registry.jobs.values(), key=lambda j: (j.category, j.id)):
        if job.category != category:
            category = job.category
            print(f"\n{category}")
        print(f"  {job.id:<22} {job.title}  [{job.mode}]")
        if job.description:
            print(f"      {job.description.splitlines()[0]}")
        if job.run:
            print(f"      run:   {job.command_text(job.run)}" + (f" {job.args_hint}" if job.args_hint else ""))
        if job.check:
            print(f"      check: {job.command_text(job.check)}")
    return 0


def cmd_run(args: argparse.Namespace, registry: Registry) -> int:
    jobs = select_jobs(registry, args.jobs, stale=args.stale, auto_only=args.auto_only)
    if not jobs:
        print("nothing to run")
        if args.report:
            write_report(args.report, registry, [])
        return 0
    results = []
    for job in jobs:
        blocked = unmet_needs(job)
        if blocked:
            print(f"── {job.id}: skipped ({', '.join(blocked)})")
            continue
        print(f"\n══ {job.id} — {job.title}")
        result = run_job(job, args.extra, dry_run=args.dry_run)
        results.append(result)
        if result.exit_code != 0 and not args.keep_going:
            break
    if args.report:
        write_report(args.report, registry, results)
    return 0 if all(r.exit_code == 0 for r in results) else 1


def write_report(path: str, registry: Registry, results: list[RunResult]) -> None:
    statuses = evaluate_all(registry)
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(markdown_report(statuses, unregistered_scripts(registry),
                                          manual_only=False, ran=results))


def cmd_report(args: argparse.Namespace, registry: Registry) -> int:
    statuses = evaluate_all(registry, run_checks=not args.no_checks)
    print(markdown_report(statuses, unregistered_scripts(registry), manual_only=args.manual_only))
    return 0


def cmd_stub(args: argparse.Namespace, registry: Registry) -> int:
    for path in args.paths or unregistered_scripts(registry):
        print(job_stub(path))
    return 0


def cmd_serve(args: argparse.Namespace, registry: Registry) -> int:
    from server import serve  # Scripts/maint/server.py

    return serve(args.port, open_browser=not args.no_open)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="maint", description=__doc__,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)

    status = sub.add_parser("status", help="show stale jobs and unregistered scripts")
    status.add_argument("--json", action="store_true")
    status.add_argument("--all", action="store_true", help="include on-demand jobs")
    status.add_argument("--quiet", action="store_true", help="one line, only when something is stale")
    status.add_argument("--no-checks", action="store_true", help="skip `check` commands (use cached results)")
    status.add_argument("--refresh", action="store_true", help="ignore cached check results")
    status.add_argument("--fail-on-stale", action="store_true", help="exit 1 if anything is stale")

    listing = sub.add_parser("list", help="describe every job")
    listing.add_argument("--json", action="store_true")

    run = sub.add_parser("run", help="run jobs from the repo root")
    run.add_argument("jobs", nargs="*")
    run.add_argument("--stale", action="store_true", help="run every stale job")
    run.add_argument("--auto-only", action="store_true", help="only jobs with mode = auto")
    run.add_argument("--dry-run", action="store_true", help="print the command without running it")
    run.add_argument("--keep-going", action="store_true", help="continue after a failure")
    run.add_argument("--report", metavar="FILE", help="write a Markdown summary here")

    report = sub.add_parser("report", help="Markdown summary for CI")
    report.add_argument("--manual-only", action="store_true",
                        help="only jobs CI cannot fix itself (manual or blocked)")
    report.add_argument("--no-checks", action="store_true")

    stub = sub.add_parser("stub", help="print a jobs.toml stub for unregistered scripts")
    stub.add_argument("paths", nargs="*")

    serve = sub.add_parser("serve", help="open the web dashboard")
    serve.add_argument("--port", type=int, default=8765)
    serve.add_argument("--no-open", action="store_true")

    hooks = sub.add_parser("hooks", help="install the report-only git hook")
    hooks.add_argument("action", choices=["install", "uninstall"])

    schedule = sub.add_parser("schedule", help="opt-in launchd job (macOS)")
    schedule.add_argument("action", choices=["install", "uninstall", "run"])
    schedule.add_argument("--weekday", type=int, default=1, help="0=Sunday … 6=Saturday (default Monday)")
    schedule.add_argument("--hour", type=int, default=9)
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = list(sys.argv[1:] if argv is None else argv)
    extra: list[str] = []
    if "--" in argv:
        split = argv.index("--")
        argv, extra = argv[:split], argv[split + 1:]
    args = build_parser().parse_args(argv)
    args.extra = extra
    registry = load_registry()
    handlers = {
        "status": cmd_status, "list": cmd_list, "run": cmd_run, "report": cmd_report,
        "stub": cmd_stub, "serve": cmd_serve,
    }
    if args.command in handlers:
        return handlers[args.command](args, registry)
    if args.command == "hooks":
        return install_hooks() if args.action == "install" else uninstall_hooks()
    if args.action == "install":
        return schedule_install(args.weekday, args.hour)
    if args.action == "uninstall":
        return schedule_uninstall()
    return schedule_run()


if __name__ == "__main__":
    sys.exit(main())
