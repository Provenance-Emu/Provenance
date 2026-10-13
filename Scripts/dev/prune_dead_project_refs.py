#!/usr/bin/env python3
"""Remove sub-project references whose .xcodeproj no longer exists on disk.

Xcode duplicates `projectReferences` entries on bad merges, and references to
sub-projects that were later deleted (MoltenVK's Cube/ExternalDependencies/
MoltenVK*.xcodeproj, 68 copies each in Provenance.xcodeproj by Oct 2026) show
red in the navigator forever. Tuist cannot generate a project from them, so
they have to go before the shipping project is generated (design doc
2026-10-13, phase 3).

A reference is removed only when ALL of these hold:
  * it is a `PBXFileReference` of type `wrapper.pb-project`;
  * no group chain resolves its path to an existing directory;
  * no `PBXContainerItemProxy` uses it as `containerPortal` (so no
    `PBXReferenceProxy`, `PBXBuildFile` or `PBXTargetDependency` can reach it).
Removed with it: its `projectReferences` entry, that entry's `ProductGroup`
(must have no children), and every mention in a group's `children` list.

Usage: prune_dead_project_refs.py [PBXPROJ] [--apply]
Dry run by default; prints what it would remove. Validate afterwards with
`plutil -lint` (fast) and `xcodebuild -list` (slow, resolves packages: restore
Package.resolved with git afterwards).
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ID = r"[0-9A-F]{24}"
FILE_REF = re.compile(
    rf'^\t\t({ID}) /\* ([^*]*) \*/ = \{{isa = PBXFileReference;(?=[^\n]*lastKnownFileType = "wrapper\.pb-project";)'
    rf'[^\n]*?path = ("?)([^";]+)\3;[^\n]*\}};\n', re.M)
GROUP = re.compile(
    rf'^\t\t({ID}) /\* ([^*]*) \*/ = \{{\n\t\t\tisa = PBXGroup;\n\t\t\tchildren = \((.*?)\);\n(.*?)\n\t\t\}};\n', re.M | re.S)
PROJECT_REF_ENTRY = re.compile(
    rf'\t\t\t\t\{{\n\t\t\t\t\tProductGroup = ({ID}) /\* [^*]* \*/;\n\t\t\t\t\tProjectRef = ({ID}) /\* [^*]* \*/;\n\t\t\t\t\}},\n')
CONTAINER_PORTAL = re.compile(rf'containerPortal = ({ID})')
CHILD_LINE = re.compile(rf'^\t\t\t\t({ID}) /\* [^*]* \*/,\n', re.M)


def group_paths(text: str) -> tuple[dict[str, str], dict[str, str | None]]:
    """(child id -> parent group id, group id -> its own path component or None)."""
    parent: dict[str, str] = {}
    comp: dict[str, str | None] = {}
    for gid, _name, children, rest in GROUP.findall(text):
        path = re.search(r'^\t\t\tpath = ("?)([^";]+)\1;', rest, re.M)
        tree = re.search(r'sourceTree = ("?)([^";]+)\1;', rest)
        comp[gid] = path.group(2) if path and (not tree or tree.group(2) == "<group>") else None
        for cid in re.findall(ID, children):
            parent[cid] = gid
    return parent, comp


def resolve(ref_id: str, path: str, parent: dict[str, str], comp: dict[str, str | None], root: Path) -> Path:
    parts = [path]
    gid = parent.get(ref_id)
    while gid:
        if comp.get(gid):
            parts.append(comp[gid])  # type: ignore[arg-type]
        gid = parent.get(gid)
    out = root
    for part in reversed(parts):
        out = out / part
    return out


def find_dead(text: str, root: Path) -> list[tuple[str, str, Path]]:
    """(file ref id, name, resolved path) for every unresolvable, unreferenced sub-project."""
    parent, comp = group_paths(text)
    portals = set(CONTAINER_PORTAL.findall(text))
    dead = []
    for ref_id, name, _q, path in FILE_REF.findall(text):
        if ref_id in portals:
            continue
        where = resolve(ref_id, path, parent, comp, root)
        if where.exists():
            continue
        dead.append((ref_id, name, where))
    return dead


def prune(text: str, dead_ids: set[str]) -> tuple[str, dict[str, int]]:
    counts = {"fileRefs": 0, "projectReferences": 0, "productGroups": 0, "childLines": 0}
    product_groups: set[str] = set()

    def drop_entry(m: re.Match[str]) -> str:
        if m.group(2) in dead_ids:
            product_groups.add(m.group(1))
            counts["projectReferences"] += 1
            return ""
        return m.group(0)
    text = PROJECT_REF_ENTRY.sub(drop_entry, text)

    def drop_group(m: re.Match[str]) -> str:
        if m.group(1) in product_groups:
            if re.search(ID, m.group(3)):
                raise SystemExit(f"refusing: product group {m.group(1)} still has children")
            counts["productGroups"] += 1
            return ""
        return m.group(0)
    text = GROUP.sub(drop_group, text)

    def drop_ref(m: re.Match[str]) -> str:
        if m.group(1) in dead_ids:
            counts["fileRefs"] += 1
            return ""
        return m.group(0)
    text = FILE_REF.sub(drop_ref, text)

    gone = dead_ids | product_groups

    def drop_child(m: re.Match[str]) -> str:
        if m.group(1) in gone:
            counts["childLines"] += 1
            return ""
        return m.group(0)
    text = CHILD_LINE.sub(drop_child, text)
    return text, counts


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("pbxproj", nargs="?", type=Path,
                    default=Path(__file__).resolve().parents[2] / "Provenance.xcodeproj/project.pbxproj")
    ap.add_argument("--apply", action="store_true", help="write the pruned project (default: dry run)")
    args = ap.parse_args()
    pbxproj = args.pbxproj.resolve()
    root = pbxproj.parent.parent  # <root>/Foo.xcodeproj/project.pbxproj
    text = pbxproj.read_text()
    dead = find_dead(text, root)
    if not dead:
        print(f"{pbxproj.name}: no dead sub-project references")
        return 0
    by_name: dict[str, int] = {}
    for _id, name, _p in dead:
        by_name[name] = by_name.get(name, 0) + 1
    print(f"{len(dead)} dead sub-project reference(s):")
    for name, n in sorted(by_name.items()):
        print(f"  {n:4d} × {name}")
    pruned, counts = prune(text, {d[0] for d in dead})
    print("removing: " + ", ".join(f"{v} {k}" for k, v in counts.items()))
    if args.apply:
        pbxproj.write_text(pruned)
        print(f"wrote {pbxproj}")
    else:
        print("dry run; pass --apply to write")
    return 0


if __name__ == "__main__":
    sys.exit(main())
