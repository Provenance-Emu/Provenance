#!/usr/bin/env python3
"""Check every fenced field in ../metadata.md against the limit in its heading.

A field is a `### Name (limit)` heading followed by a ``` block. Prints each
field's length and exits non-zero if any is over its limit.

    python3 check_metadata.py [path/to/metadata.md]
"""
import re
import sys
from pathlib import Path

path = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "metadata.md"
text = path.read_text()
section, failed = "", False
for m in re.finditer(r"^## ([^\n]+)$|^### ([^\n]+?) \((\d+)\)\n```\n(.*?)\n```", text, re.M | re.S):
    if m.group(1):
        section = m.group(1)
        continue
    name, limit, body = m.group(2), int(m.group(3)), m.group(4)
    n = len(body)
    over = n > limit
    failed |= over
    extra = ""
    if name.startswith("Keywords"):
        extra = f"  ({len(body.split(','))} terms{', has spaces after commas' if ', ' in body else ''})"
    print(f"{'OVER ' if over else 'ok   '}{section} / {name}: {n}/{limit}{extra}")
sys.exit(1 if failed else 0)
