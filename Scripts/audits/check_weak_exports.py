#!/usr/bin/env python3
"""Flag weak C++ symbols exported by more than one image in a built app.

dyld coalesces *exported* weak definitions (template instantiations, inline
functions, nlohmann/fmt/glslang internals) across every loaded image, so two
dynamic frameworks that each export their own copy of the same symbol share
one at runtime, and the loser runs the winner's (possibly different-version)
code. That crashed azahar's shader compiler through Dolphin's glslang in
Oct 2026 (see CLAUDE.md, "Azahar core build gotchas"). This audit finds the
next such pair before it ships.

Usage:
    check_weak_exports.py <Foo.app | Frameworks dir> [--advisory]
        [--allowlist FILE] [--min-overlap N] [--samples N] [--json]

For every Mach-O image (the app binary, every *.framework binary and every
*.dylib under it) the script lists symbols that `nm -m` reports as
`weak external` (defined, not undefined, not private), then reports each
pair of images whose sets overlap. Exit status is 1 when any pair is not
covered by the allowlist, 0 otherwise; `--advisory` always exits 0.

Allowlist lines (``#`` comments allowed):
    pair: <imageA> <imageB>     ignore this pair entirely (any order)
    symbol: <regex>             ignore symbols matching the regex (mangled)
    image: <name>               ignore this image everywhere
"""

from __future__ import annotations

import argparse
import itertools
import json
import os
import re
import subprocess
import sys
from pathlib import Path

HERE = Path(__file__).resolve().parent
DEFAULT_ALLOWLIST = HERE / "weak_exports_allowlist.txt"
WEAK_EXTERNAL = re.compile(r"^\S+\s+\(.*?\)\s+weak external\s+(\S+)")


def mach_o_images(root: Path) -> list[Path]:
    """Every Mach-O we care about under ``root``: app binary, framework binaries, dylibs."""
    images: list[Path] = []
    if root.suffix == ".app":
        info = root / "Info.plist"
        exe = None
        if info.exists():
            try:
                out = subprocess.run(
                    ["/usr/libexec/PlistBuddy", "-c", "Print :CFBundleExecutable", str(info)],
                    capture_output=True, text=True, check=True,
                ).stdout.strip()
                exe = root / out
            except subprocess.CalledProcessError:
                exe = None
        if exe and exe.is_file():
            images.append(exe)
    for dirpath, dirnames, filenames in os.walk(root):
        d = Path(dirpath)
        if d.suffix == ".framework":
            exe = d / d.stem
            if exe.is_file():
                images.append(exe)
            # Do not descend: nested Headers/Modules carry no Mach-O of interest,
            # and a framework embedding a dylib is handled by the dylib walk below.
        for name in filenames:
            if name.endswith(".dylib"):
                images.append(d / name)
    # de-dup while keeping order
    seen: set[Path] = set()
    unique: list[Path] = []
    for p in images:
        if p not in seen:
            seen.add(p)
            unique.append(p)
    return unique


def weak_exports(image: Path) -> set[str]:
    try:
        out = subprocess.run(
            ["nm", "-m", "-arch", "arm64", str(image)],
            capture_output=True, text=True, check=False,
        ).stdout
    except FileNotFoundError:
        sys.exit("nm not found; run with an Xcode toolchain on PATH")
    symbols: set[str] = set()
    for line in out.splitlines():
        if " weak external " not in line or "undefined" in line or " private " in line:
            continue
        m = WEAK_EXTERNAL.match(line)
        if m:
            symbols.add(m.group(1))
    return symbols


def demangle(symbols: list[str]) -> list[str]:
    try:
        out = subprocess.run(["c++filt"], input="\n".join(symbols), capture_output=True,
                             text=True, check=False).stdout
    except FileNotFoundError:
        return symbols
    lines = out.splitlines()
    return lines if len(lines) == len(symbols) else symbols


def load_allowlist(path: Path):
    pairs: set[frozenset[str]] = set()
    symbol_res: list[re.Pattern[str]] = []
    images: set[str] = set()
    if not path.exists():
        return pairs, symbol_res, images
    for raw in path.read_text().splitlines():
        line = raw.split("#", 1)[0].strip()
        if not line:
            continue
        kind, _, rest = line.partition(":")
        rest = rest.strip()
        if kind == "pair":
            parts = rest.split()
            if len(parts) == 2:
                pairs.add(frozenset(parts))
        elif kind == "symbol":
            symbol_res.append(re.compile(rest))
        elif kind == "image":
            images.add(rest)
    return pairs, symbol_res, images


def image_name(p: Path) -> str:
    return p.parent.name if p.parent.suffix == ".framework" else p.name


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("root", type=Path, help="a built .app, or a folder of frameworks/dylibs")
    ap.add_argument("--advisory", action="store_true", help="report but always exit 0")
    ap.add_argument("--allowlist", type=Path, default=DEFAULT_ALLOWLIST)
    ap.add_argument("--min-overlap", type=int, default=1, help="ignore pairs sharing fewer symbols")
    ap.add_argument("--samples", type=int, default=5, help="demangled sample symbols per pair")
    ap.add_argument("--json", action="store_true", help="machine-readable output")
    ap.add_argument("--strict-libretro", action="store_true",
                    help="also flag pairs of two *.libretro.framework dylibs (same codebase, "
                         "loaded one at a time; tolerated by default)")
    args = ap.parse_args()

    root = args.root.resolve()
    if not root.exists():
        sys.exit(f"no such path: {root}")

    pairs_ok, symbol_res, images_ok = load_allowlist(args.allowlist)
    images = [p for p in mach_o_images(root) if image_name(p) not in images_ok]
    if not images:
        sys.exit(f"no Mach-O images found under {root}")

    exports: dict[str, set[str]] = {}
    for img in images:
        syms = {s for s in weak_exports(img) if not any(r.search(s) for r in symbol_res)}
        if syms:
            exports[image_name(img)] = syms

    findings = []
    for a, b in itertools.combinations(sorted(exports), 2):
        shared = exports[a] & exports[b]
        if len(shared) < args.min_overlap:
            continue
        libretro_pair = a.endswith(".libretro.framework") and b.endswith(".libretro.framework")
        if frozenset((a, b)) in pairs_ok:
            reason = "allowlist"
        elif libretro_pair and not args.strict_libretro:
            reason = "libretro pair"
        else:
            reason = ""
        findings.append({
            "images": [a, b],
            "count": len(shared),
            "allowed": bool(reason),
            "reason": reason,
            "samples": demangle(sorted(shared)[: args.samples]),
        })
    findings.sort(key=lambda f: (f["allowed"], -f["count"]))
    blocking = [f for f in findings if not f["allowed"]]

    if args.json:
        print(json.dumps({"root": str(root), "images": sorted(exports), "findings": findings}, indent=2))
    else:
        print(f"weak-export audit: {len(images)} images, {len(exports)} with weak exports, "
              f"{len(findings)} overlapping pair(s), {len(blocking)} not allowlisted")
        for f in findings:
            tag = f"allowed ({f['reason']}) " if f["allowed"] else "OVERLAP "
            print(f"{tag}{f['images'][0]}  <->  {f['images'][1]}  ({f['count']} shared)")
            for s in f["samples"]:
                print(f"    {s}")
        if blocking:
            print("\nFix: hide the C++ surface of one side (-fvisibility=hidden "
                  "-fvisibility-inlines-hidden, or -unexported_symbols_list __Z*) or add a "
                  f"'pair:' line to {args.allowlist.name} with a reason.")

    if blocking and not args.advisory:
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
