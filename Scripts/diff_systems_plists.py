#!/usr/bin/env python3
"""Diff the (historically duplicated) copies of systems.plist.

Provenance used to carry two copies of ``systems.plist``:

* ``PVLibrary/Sources/PVLibrary/Resources/systems.plist``  — the AUTHORITATIVE one.
  ``GameImporter.initCorePlists()`` loads it via ``Bundle.module`` and feeds it to
  ``PVEmulatorConfiguration.updateSystems(fromPlists:)``, which is what actually
  populates Realm and therefore every on-screen control layout.
* ``PVCoreLoader/Sources/PVCoreLoader/Resources/systems.plist`` — a dead copy.
  It was only ever surfaced through the SwiftGen-generated ``PlistFiles.items``
  behind ``CoreLoader.systemsPlist()``, which had no callers anywhere in the repo.

If the dead copy no longer exists this script is a no-op success, so it is safe to
keep wired into CI after the duplicate is removed. While the duplicate exists the
script fails (exit 1) on any divergence so the two cannot silently drift again.

Usage:
    Scripts/diff_systems_plists.py [--strict] [--repo-root PATH]

    --strict   also fail on systems that exist only in one copy, even when the
               identifier is in ``TOLERATED_PVLIBRARY_ONLY``.

Exit codes:
    0  the copies agree (or the duplicate is gone)
    1  divergences found
    2  usage / IO error
"""

from __future__ import annotations

import argparse
import plistlib
import sys
from pathlib import Path
from typing import Any

# The authoritative copy, and the (dead) duplicate.
AUTHORITATIVE_REL = Path("PVLibrary/Sources/PVLibrary/Resources/systems.plist")
DUPLICATE_REL = Path("PVCoreLoader/Sources/PVCoreLoader/Resources/systems.plist")

KEY_ID = "PVSystemIdentifier"

# Systems that legitimately exist only in the authoritative copy. These were added
# to PVLibrary and never backported to the dead duplicate. Listing them here keeps
# the check honest: they are explicitly tolerated rather than silently ignored.
# Remove entries from this set once the duplicate is deleted or resynced.
TOLERATED_PVLIBRARY_ONLY: frozenset[str] = frozenset(
    {
        "com.provenance.cdi",  # CD-i
        "com.provenance.quake2",  # Quake II
        "com.provenance.tic80",  # TIC-80
    }
)


def load(path: Path) -> list[dict[str, Any]]:
    with path.open("rb") as handle:
        data = plistlib.load(handle)
    if not isinstance(data, list):
        raise ValueError(f"{path}: expected a top-level array, got {type(data).__name__}")
    return data


def index_by_identifier(systems: list[dict[str, Any]], label: str) -> dict[str, dict[str, Any]]:
    out: dict[str, dict[str, Any]] = {}
    for entry in systems:
        identifier = entry.get(KEY_ID)
        if not isinstance(identifier, str):
            raise ValueError(f"{label}: entry missing a string {KEY_ID}: {entry.get('PVSystemName')!r}")
        if identifier in out:
            raise ValueError(f"{label}: duplicate {KEY_ID} {identifier!r}")
        out[identifier] = entry
    return out


def render(value: Any) -> str:
    """Compact single-line rendering of a plist value for diff output."""
    if isinstance(value, (dict, list)):
        text = repr(value)
        return text if len(text) <= 200 else text[:197] + "..."
    return repr(value)


def deep_diff(left: Any, right: Any, path: str, out: list[str]) -> None:
    """Append human-readable divergences between two plist values."""
    if type(left) is not type(right) and not (
        isinstance(left, (int, float)) and isinstance(right, (int, float))
    ):
        out.append(f"{path}: type {type(left).__name__} vs {type(right).__name__} "
                   f"({render(left)} vs {render(right)})")
        return

    if isinstance(left, dict):
        for key in sorted(set(left) | set(right)):
            sub = f"{path}.{key}" if path else key
            if key not in right:
                out.append(f"{sub}: only in PVLibrary ({render(left[key])})")
            elif key not in left:
                out.append(f"{sub}: only in PVCoreLoader ({render(right[key])})")
            else:
                deep_diff(left[key], right[key], sub, out)
        return

    if isinstance(left, list):
        if len(left) != len(right):
            out.append(f"{path}: array length {len(left)} vs {len(right)}")
        for i in range(min(len(left), len(right))):
            deep_diff(left[i], right[i], f"{path}[{i}]", out)
        for i in range(len(right), len(left)):
            out.append(f"{path}[{i}]: only in PVLibrary ({render(left[i])})")
        for i in range(len(left), len(right)):
            out.append(f"{path}[{i}]: only in PVCoreLoader ({render(right[i])})")
        return

    if left != right:
        out.append(f"{path}: {render(left)} (PVLibrary) vs {render(right)} (PVCoreLoader)")


def main(argv: list[str]) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--strict", action="store_true",
                        help="fail on one-sided systems even when explicitly tolerated")
    parser.add_argument("--repo-root", type=Path, default=Path(__file__).resolve().parent.parent,
                        help="repository root (defaults to the parent of Scripts/)")
    args = parser.parse_args(argv)

    root: Path = args.repo_root
    authoritative = root / AUTHORITATIVE_REL
    duplicate = root / DUPLICATE_REL

    if not authoritative.is_file():
        print(f"error: authoritative plist not found: {authoritative}", file=sys.stderr)
        return 2

    if not duplicate.is_file():
        print("OK: the duplicate systems.plist no longer exists — nothing to diff.")
        print(f"     authoritative: {AUTHORITATIVE_REL}")
        return 0

    try:
        lib = index_by_identifier(load(authoritative), "PVLibrary")
        loader = index_by_identifier(load(duplicate), "PVCoreLoader")
    except (ValueError, plistlib.InvalidFileException) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2

    print(f"PVLibrary    : {len(lib)} systems  ({AUTHORITATIVE_REL})")
    print(f"PVCoreLoader : {len(loader)} systems  ({DUPLICATE_REL})")
    print()

    failures = 0

    lib_only = sorted(set(lib) - set(loader))
    loader_only = sorted(set(loader) - set(lib))

    if lib_only:
        print("== Systems only in PVLibrary ==")
        for identifier in lib_only:
            tolerated = identifier in TOLERATED_PVLIBRARY_ONLY and not args.strict
            marker = "tolerated" if tolerated else "DIVERGENCE"
            print(f"  [{marker}] {identifier}  ({lib[identifier].get('PVSystemName')})")
            if not tolerated:
                failures += 1
        print()

    if loader_only:
        print("== Systems only in PVCoreLoader ==")
        for identifier in loader_only:
            print(f"  [DIVERGENCE] {identifier}  ({loader[identifier].get('PVSystemName')})")
            failures += 1
        print()

    shared = sorted(set(lib) & set(loader))
    diverged_systems = 0
    for identifier in shared:
        lines: list[str] = []
        deep_diff(lib[identifier], loader[identifier], "", lines)
        if lines:
            diverged_systems += 1
            failures += len(lines)
            print(f"== {identifier} ({lib[identifier].get('PVSystemName')}) — {len(lines)} divergence(s) ==")
            for line in lines:
                print(f"  {line}")
            print()

    print(f"Summary: {len(shared)} shared systems, {diverged_systems} with differing keys, "
          f"{len(lib_only)} PVLibrary-only, {len(loader_only)} PVCoreLoader-only.")

    if failures:
        print(f"FAIL: {failures} divergence(s). PVLibrary's copy is authoritative — "
              f"never 'fix' PVLibrary to match PVCoreLoader.", file=sys.stderr)
        return 1

    print("OK: the two copies agree (modulo explicitly tolerated PVLibrary-only systems).")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
