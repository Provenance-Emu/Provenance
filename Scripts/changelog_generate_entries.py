#!/usr/bin/env python3
"""Generate [Unreleased] changelog entries from conventional commits.

Reads /tmp/raw_commits.txt (one conventional commit subject per line)
and writes structured changelog entries to /tmp/unreleased_entries.txt.
"""
import re

with open('/tmp/raw_commits.txt') as f:
    lines = [l.strip() for l in f if l.strip()]

added = []
fixed = []
changed = []
ci = []

for line in lines:
    m = re.match(r'^(feat|fix|refactor|perf|docs|chore|build|ci)(?:\(([^)]+)\))?:\s*(.*)', line)
    if not m:
        continue
    kind, scope, desc = m.group(1), m.group(2) or '', m.group(3)

    # Extract PR number if present like (#2750)
    pr_m = re.search(r'\(#(\d+)\)', desc)
    pr_ref = f' (#{pr_m.group(1)})' if pr_m else ''
    clean_desc = re.sub(r'\s*\(#\d+\)', '', desc).strip()

    scope_prefix = f'**{scope.title()}** — ' if scope else ''
    entry = f'- {scope_prefix}{clean_desc}{pr_ref}'

    if kind in ('build', 'ci'):
        ci.append(entry)
    elif kind in ('fix',):
        fixed.append(entry)
    elif kind in ('feat', 'perf'):
        added.append(entry)
    else:
        changed.append(entry)

sections = []
if added:
    sections.append('### Added\n' + '\n'.join(added))
if fixed:
    sections.append('### Fixed\n' + '\n'.join(fixed))
if changed:
    sections.append('### Changed\n' + '\n'.join(changed))
if ci:
    sections.append('### CI / Infrastructure\n' + '\n'.join(ci))

output = '\n\n'.join(sections)
with open('/tmp/unreleased_entries.txt', 'w') as f:
    f.write(output)

print(f"Generated {len(added)} added, {len(fixed)} fixed, {len(changed)} changed, {len(ci)} CI entries")
