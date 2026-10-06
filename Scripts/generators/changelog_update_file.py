#!/usr/bin/env python3
"""Update CHANGELOG.md with new [Unreleased] entries.

Reads /tmp/unreleased_entries.txt and merges them into the [Unreleased]
section of CHANGELOG.md, deduplicating by PR number.
"""
import re

with open('CHANGELOG.md', 'r') as f:
    content = f.read()

with open('/tmp/unreleased_entries.txt') as f:
    new_entries = f.read().strip()

if not new_entries:
    print("Nothing to add.")
    exit(0)

# Find [Unreleased] section
unreleased_match = re.search(r'## \[Unreleased\][^\n]*\n', content)
if not unreleased_match:
    # No [Unreleased] section — create one before first release
    first_release = re.search(r'\n## \[', content)
    if first_release:
        insert_pos = first_release.start()
        content = content[:insert_pos] + f'\n\n## [Unreleased]\n\n{new_entries}\n' + content[insert_pos:]
    else:
        content += f'\n\n## [Unreleased]\n\n{new_entries}\n'
else:
    # Find end of [Unreleased] section (next ## heading or EOF)
    start = unreleased_match.end()
    next_section = re.search(r'\n## \[', content[start:])
    if next_section:
        end = start + next_section.start()
    else:
        end = len(content)

    existing_section = content[start:end]

    # Dedup: only add entries (by PR number) not already present
    existing_prs = set(re.findall(r'#(\d+)', existing_section))
    filtered_lines = []
    for line in new_entries.split('\n'):
        if line.startswith('###'):
            filtered_lines.append(line)
            continue
        prs_in_line = set(re.findall(r'#(\d+)', line))
        if not prs_in_line or not prs_in_line.issubset(existing_prs):
            filtered_lines.append(line)

    filtered = '\n'.join(filtered_lines).strip()
    if not filtered or filtered == '\n'.join(l for l in new_entries.split('\n') if l.startswith('###')).strip():
        print("All entries already present — skipping.")
        exit(0)

    # Append at the end of the [Unreleased] section
    content = content[:end] + '\n' + filtered + '\n' + content[end:]

with open('CHANGELOG.md', 'w') as f:
    f.write(content)

print("CHANGELOG.md updated.")
