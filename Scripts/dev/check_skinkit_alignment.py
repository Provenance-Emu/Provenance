#!/usr/bin/env python3
"""Check immutable SkinKit declarations and tracked resolver pins across the three apps."""

import argparse
import json
from pathlib import Path
import re
import subprocess


def inspect_consumer(name, root, declaration):
    manifests = subprocess.check_output(
        ["git", "-C", str(root), "ls-files", "-z", "*Package.swift", "*Package@*.swift", "*Project.swift"]
    ).decode().split("\0")
    rows = []
    for relative in dict.fromkeys([str(declaration), *filter(None, manifests)]):
        source = (root / relative).read_text()
        if "https://github.com/Provenance-Emu/SkinKit" not in source and relative != str(declaration):
            continue
        matches = re.findall(
            r'https://github\.com/Provenance-Emu/SkinKit(?:\.git)?"\s*,\s*'
            r'(?:(?:requirement:\s*)?\.revision\(|revision:\s*)"([0-9a-f]{40})"', source
        )
        if len(matches) != 1:
            raise ValueError(f"{name}: expected one immutable SkinKit declaration in {relative}")
        rows.append((name, relative, matches[0]))
    paths = subprocess.check_output(
        ["git", "-C", str(root), "ls-files", "-z", "*Package.resolved", ".package.resolved"]
    ).decode().split("\0")
    for relative in filter(None, paths):
        data = json.loads((root / relative).read_text())
        pins = data.get("pins", data.get("object", {}).get("pins", []))
        for pin in pins:
            identity = pin.get("identity", pin.get("package", "")).lower()
            if identity == "skinkit":
                rows.append((name, relative, pin["state"].get("revision", "missing revision")))
    return rows


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-revision", required=True, help="Full immutable SkinKit commit tested by all consumers")
    parser.add_argument("--provenance", type=Path, default=root)
    parser.add_argument("--ifly", type=Path, default=root.parent / "iFly/iFly")
    parser.add_argument("--icube", type=Path, default=root / "Cores/Dolphin/dolphin-ios")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_revision):
        parser.error("--expected-revision must be a full lowercase commit SHA")

    rows = []
    try:
        for name, location, declaration in [
            ("Provenance", args.provenance, Path("PVUI/Package.swift")),
            ("iFly", args.ifly, Path("Project.swift")),
            ("iCube", args.icube, Path("Source/iOS/App/Project.swift")),
        ]:
            rows.extend(inspect_consumer(name, location, declaration))
    except (OSError, ValueError, KeyError, subprocess.CalledProcessError) as error:
        parser.exit(2, f"Cannot inspect consumer: {error}\n")

    for name, path, revision in rows:
        status = "PASS" if revision == args.expected_revision else "MISMATCH"
        print(f"{status}: {name}: {path}: {revision}")
    return int(any(revision != args.expected_revision for _, _, revision in rows))


if __name__ == "__main__":
    raise SystemExit(main())
