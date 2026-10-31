#!/usr/bin/env python3
"""Check SkinKit release requirements and tracked resolver commits across the three apps."""

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
            r'(?:(?:requirement:\s*)?\.(revision|exact)\(|(revision|exact):\s*)"([^"\n]+)"', source
        )
        if len(matches) != 1:
            raise ValueError(f"{name}: expected one exact release or immutable SkinKit declaration in {relative}")
        method, named_method, value = matches[0]
        is_release = (method or named_method) == "exact"
        rows.append((name, relative, None if is_release else value, value if is_release else None, True))
    paths = subprocess.check_output(
        ["git", "-C", str(root), "ls-files", "-z", "*Package.resolved", ".package.resolved"]
    ).decode().split("\0")
    for relative in filter(None, paths):
        data = json.loads((root / relative).read_text())
        pins = data.get("pins", data.get("object", {}).get("pins", []))
        for pin in pins:
            identity = pin.get("identity", pin.get("package", "")).lower()
            if identity == "skinkit":
                rows.append((name, relative, pin["state"].get("revision", "missing revision"), pin["state"].get("version"), False))
    return rows


def main():
    root = Path(__file__).resolve().parents[2]
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--expected-revision", required=True, help="Full immutable SkinKit commit tested by all consumers")
    parser.add_argument("--expected-version", help="Require this exact release in declarations and resolver entries")
    parser.add_argument("--provenance", type=Path, default=root)
    parser.add_argument("--ifly", type=Path, default=root.parent / "iFly/iFly")
    parser.add_argument("--icube", type=Path, default=root / "Cores/Dolphin/dolphin-ios")
    args = parser.parse_args()
    if not re.fullmatch(r"[0-9a-f]{40}", args.expected_revision):
        parser.error("--expected-revision must be a full lowercase commit SHA")
    if args.expected_version and not re.fullmatch(r"\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?(?:\+[0-9A-Za-z.-]+)?", args.expected_version):
        parser.error("--expected-version must be a semantic version")

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

    mismatches = 0
    for name, path, revision, version, is_declaration in rows:
        revision_matches = revision == args.expected_revision or (is_declaration and revision is None and args.expected_version is not None)
        version_matches = not args.expected_version or version == args.expected_version
        matches = revision_matches and version_matches
        mismatches += not matches
        status = "PASS" if matches else "MISMATCH"
        revision_label = revision or ("exact release declaration" if is_declaration else "missing revision")
        print(f"{status}: {name}: {path}: version={version or 'revision pin'} revision={revision_label}")
    return int(mismatches > 0)


if __name__ == "__main__":
    raise SystemExit(main())
