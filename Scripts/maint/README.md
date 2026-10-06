# maint — Provenance maintenance jobs

One registry ([`jobs.toml`](jobs.toml)) describes every recurring script: what it
does, the command, and when it is out of date. `maint.py` reads it to tell you
what needs running, run it with the right paths, and keep CI honest.

Needs Python 3.11+ (`brew install python`); standard library only.

## Everyday use

```bash
make maint                                   # dashboard at http://127.0.0.1:8765
python3 Scripts/maint/maint.py status        # stale jobs + unregistered scripts
python3 Scripts/maint/maint.py status --all  # include on-demand jobs
python3 Scripts/maint/maint.py list          # every job and its command
python3 Scripts/maint/maint.py run licenses  # run one job from the repo root
python3 Scripts/maint/maint.py run local-dylibs -- fetch flycast   # pass arguments
python3 Scripts/maint/maint.py run --stale --auto-only             # what CI runs
python3 Scripts/maint/maint.py run --dry-run uti                   # show, don't run
```

Runs are logged to `.maint/logs/<job>.log`; `.maint/` is gitignored.

## When is a job stale?

Read from git history, so a fresh CI checkout agrees with your working copy:

- **inputs changed** — an `inputs` file (or the script itself) changed in a commit
  newer than the last commit to its `outputs`, or has uncommitted edits. A
  successful run since then also counts, for when regenerating changes nothing.
- **too old** — `max_age` passed since the outputs last changed (or since the
  last successful run on this machine, for jobs whose output isn't committed).
- **check failed** — the job's `check` command exited 1. Exit 0 is current;
  anything else is shown as an error. Results are cached for 6 hours
  (`status --refresh` re-runs them, `--no-checks` skips them).

Jobs with none of these are **on demand**: listed with their command, never stale.

`needs` keeps a job from running where it can't: `network`, `macos`,
`submodules`, `env:VAR`, `py:module`, `path:some/path`, or any tool on `PATH`.

## Modes

- `auto` — deterministic generators. CI and the local schedule run these and
  open a pull request.
- `manual` — needs judgement, secrets or your Mac (core pins, UTIs, license
  gaps). Only ever reported: in `status`, the dashboard, and the CI issue.

## Adding a script

Put it in the right `Scripts/` folder, then either add a job or list it under
`[ignore]`. `python3 Scripts/maint/maint.py stub` prints a starting job for every
unregistered script. Pull requests that touch `Scripts/` fail until each script is
registered.

## Automation

| Where | What | Set up |
|---|---|---|
| Git hook | After `git pull` / branch switch, one line if something is stale. Never runs anything. | `make maint-hooks` (`hooks uninstall` removes it) |
| CI | `.github/workflows/maint.yml`, Mondays: runs stale `auto` jobs into one PR (`maint/auto-ci`) and keeps one issue, *Maintenance: jobs needing attention*, for the rest. On PRs touching scripts: tests + registration check. | Nothing |
| Your Mac (opt in) | launchd runs stale `auto` jobs weekly in a separate worktree (`~/Library/Caches/provenance-maint/worktree`, branch `maint/auto-local`) and opens a PR with `gh`. Never touches your checkout. Covers what CI can't, e.g. jobs needing submodules. | `python3 Scripts/maint/maint.py schedule install [--weekday 1 --hour 9]`; log in `~/Library/Logs/provenance-maint.log`; `schedule uninstall` |

## Dashboard security

The server binds to 127.0.0.1, rejects requests whose `Host` isn't its own
(DNS rebinding), needs the per-session token embedded in the page for every
POST, runs only jobs named in `jobs.toml`, and never takes arguments from the page.

## Tests

```bash
python3 -m unittest discover -s Scripts/maint -p 'test_*.py'
```
