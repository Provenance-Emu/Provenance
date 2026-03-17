#!/usr/bin/env python3
"""
update_core_versions.py — Scan emulator core source files and validate/update Core.plist versions.

For native (non-libretro) cores: searches submodule source trees for version
strings in version.h, configure.ac, CMakeLists.txt, etc.

For libretro cores embedded in native wrappers (BeetlePSX, etc.): searches
C/C++ source for retro_get_system_info() version strings.

The RetroArch PVRetroArch/Core.plist sub-cores are updated at runtime via
LibretroMetadataReader (reads compiled dylib __cstring sections); this script
handles the *source-level* validation so discrepancies are visible in PRs.

Usage:
  python3 Scripts/update_core_versions.py           # report only
  python3 Scripts/update_core_versions.py --fix     # update plists in-place
  python3 Scripts/update_core_versions.py --json    # machine-readable report
  python3 Scripts/update_core_versions.py --core mGBA  # single core
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from pathlib import Path
from typing import Optional

# ---------------------------------------------------------------------------
# Config
# ---------------------------------------------------------------------------

REPO_ROOT = Path(__file__).resolve().parent.parent

# Filename pattern → content regex pairs for native core version discovery.
# The first capture group must be the version string.
VERSION_SEARCH_RULES: list[tuple[str, str]] = [
    # C/C++ headers:  #define FOO_VERSION "1.2.3"  or  #define VERSION 1.2.3
    (r"version\.h$",        r'#define\s+\w*VERSION\w*\s+"([0-9][^"]*)"'),
    (r"version\.h$",        r'#define\s+\w*VERSION\w*\s+([0-9]+\.[0-9]+(?:\.[0-9]+)?)'),
    (r"Version\.h$",        r'#define\s+\w*VERSION\w*\s+"([0-9][^"]*)"'),
    # autoconf
    (r"configure\.ac$",     r'AC_INIT\s*\([^,]+,\s*\[?([0-9][0-9.a-z-]*)\]?'),
    # cmake
    (r"CMakeLists\.txt$",   r'(?:project|set)\s*\([^)]*?VERSION\s+"?([0-9][0-9.a-z-]*)"?'),
    # plain VERSION file
    (r"^VERSION$",          r'^([0-9][0-9.]*)'),
    # .version file
    (r"\.version$",         r'^([0-9][0-9.]*)'),
    # Makefile / mk
    (r"Makefile(?:\..*)?$", r'^\s*VERSION\s*:?=\s*([0-9][0-9.]*)'),
    (r"\.mk$",              r'^\s*VERSION\s*:?=\s*([0-9][0-9.]*)'),
]

# Regex to find library_version inside retro_get_system_info implementations.
# Works across multi-line function bodies.
LIBRETRO_VERSION_RE = re.compile(
    r"retro_get_system_info\b[^{]*\{[^}]*library_version\s*=\s*\"([^\"]+)\"",
    re.DOTALL,
)

# Maximum directory depth to recurse into a submodule when scanning.
MAX_SCAN_DEPTH = 5

# Directory name components that indicate embedded third-party libraries.
# Files inside these are excluded from version scanning to avoid false positives.
# NOTE: Keep this list conservative — only well-known third-party library dirs.
# Core-specific build dirs like 'cmake/' at the top level should NOT be excluded.
SKIP_DIR_COMPONENTS: set[str] = {
    "vendor", "third_party", "thirdparty", "third-party",
    "external", "externals", "deps", "dependencies",
    # Multimedia framework bundles (version strings are library versions, not core versions)
    "ffmpeg", "ffmpeg-ios", "libav", "ffmpegios",
    # Graphics / utility libraries
    "vma", "vulkan", "glm", "imgui",
    "libpng", "zlib", "bzip2", "lzma", "minizip",
    "boost", "googletest", "gtest", "catch2",
    "SDL", "SDL2", "glfw", "glew",
}

# CMakeLists.txt / configure.ac version searches are only trusted at shallow depth.
MAX_BUILD_SCRIPT_DEPTH = 2

# Sentinel versions that indicate "unknown / not set"
SENTINEL_VERSIONS: set[str] = {"0", "unknown", "n/a", "nightly", "dev", "git", "tbd", ""}


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def find_all_core_plists() -> list[Path]:
    """Return sorted list of all Core.plist paths under Cores/ and CoresRetro/."""
    results: list[Path] = []
    for top in ("Cores", "CoresRetro"):
        base = REPO_ROOT / top
        if base.is_dir():
            results.extend(sorted(base.rglob("Core.plist")))
    return results


def plist_field(content: str, key: str) -> Optional[str]:
    """Extract the <string> value after a <key>KEY</key> entry."""
    m = re.search(
        r"<key>" + re.escape(key) + r"</key>\s*<string>(.*?)</string>",
        content,
        re.DOTALL,
    )
    return m.group(1).strip() if m else None


def plist_bool(content: str, key: str) -> Optional[bool]:
    """Return True/False for a <key>KEY</key><true/> or <false/> entry."""
    m = re.search(
        r"<key>" + re.escape(key) + r"</key>\s*<(true|false)/>",
        content,
        re.DOTALL,
    )
    if m:
        return m.group(1) == "true"
    return None


def read_plist_info(plist_path: Path) -> dict:
    """Parse the fields we care about from a Core.plist."""
    try:
        raw = plist_path.read_bytes()
    except OSError:
        return {}

    # Binary plist — use plistlib
    if raw[:6] == b"bplist":
        import plistlib
        try:
            data = plistlib.loads(raw)
        except Exception:
            return {}
        return {
            "identifier":  data.get("PVCoreIdentifier", ""),
            "name":        data.get("PVProjectName", plist_path.parent.name),
            "url":         data.get("PVProjectURL", ""),
            "version":     data.get("PVProjectVersion", ""),
            "disabled":    data.get("PVDisabled", False) is True,
            "raw_content": str(data),
        }

    # XML plist
    content = raw.decode("utf-8", errors="replace")
    return {
        "identifier":      plist_field(content, "PVCoreIdentifier") or "",
        "name":            plist_field(content, "PVProjectName") or plist_path.parent.name,
        "url":             plist_field(content, "PVProjectURL") or "",
        "version":         plist_field(content, "PVProjectVersion") or "",
        "disabled":        plist_bool(content, "PVDisabled") is True,
        "raw_content":     content,
    }


def update_plist_version(plist_path: Path, new_version: str) -> bool:
    """Overwrite PVProjectVersion in the plist.  Returns True if changed."""
    try:
        raw = plist_path.read_bytes()
    except OSError:
        return False

    # Binary plist — use plistlib
    if raw[:6] == b"bplist":
        import plistlib
        try:
            data = plistlib.loads(raw)
        except Exception:
            return False
        if data.get("PVProjectVersion") == new_version:
            return False
        data["PVProjectVersion"] = new_version
        plist_path.write_bytes(plistlib.dumps(data, fmt=plistlib.FMT_BINARY))
        return True

    # XML plist — regex replace
    try:
        content = raw.decode("utf-8")
    except UnicodeDecodeError:
        return False

    updated = re.sub(
        r"(<key>PVProjectVersion</key>\s*<string>)(.*?)(</string>)",
        lambda m: m.group(1) + new_version + m.group(3),
        content,
        flags=re.DOTALL,
    )
    if updated == content:
        return False
    plist_path.write_text(updated, encoding="utf-8")
    return True


# ---------------------------------------------------------------------------
# Source scanning
# ---------------------------------------------------------------------------


def _relative_depth(path: Path, base: Path) -> int:
    try:
        return len(path.relative_to(base).parts)
    except ValueError:
        return 999


def _is_third_party_path(fpath: Path, base: Path) -> bool:
    """Return True if any component of the relative path looks like a third-party lib dir."""
    try:
        rel_parts = fpath.relative_to(base).parts
    except ValueError:
        return False
    return any(p.lower() in SKIP_DIR_COMPONENTS for p in rel_parts)


def scan_source_tree(core_dir: Path) -> list[tuple[str, str, str]]:
    """
    Walk *core_dir* looking for version strings.

    Returns a list of (kind, rel_path, version) triples where kind is one of:
      'libretro'     – found inside retro_get_system_info()
      'version_file' – found in version.h / configure.ac / CMakeLists.txt / etc.
    """
    if not core_dir.is_dir():
        return []

    results: list[tuple[str, str, str]] = []
    seen_libretro: set[str] = set()
    seen_file: set[str] = set()

    for fpath in core_dir.rglob("*"):
        if not fpath.is_file():
            continue
        # Skip hidden paths
        if any(p.startswith(".") for p in fpath.parts):
            continue
        depth = _relative_depth(fpath, core_dir)
        # Limit recursion depth
        if depth > MAX_SCAN_DEPTH:
            continue
        # Skip embedded third-party library directories
        if _is_third_party_path(fpath, core_dir):
            continue

        fname = fpath.name
        rel = str(fpath.relative_to(core_dir))

        # --- libretro source check (C / C++) ---
        if fname.endswith((".c", ".cpp")):
            try:
                text = fpath.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                continue
            if "retro_get_system_info" in text:
                m = LIBRETRO_VERSION_RE.search(text)
                if m:
                    ver = m.group(1).strip()
                    if ver and ver not in seen_libretro:
                        seen_libretro.add(ver)
                        results.append(("libretro", rel, ver))
            continue

        # --- version file patterns ---
        for file_pat, content_pat in VERSION_SEARCH_RULES:
            if not re.search(file_pat, fname, re.IGNORECASE):
                continue
            # For build scripts (CMakeLists, configure.ac, Makefile), only trust
            # files close to the root of the core — deep copies are likely from
            # embedded sublibraries.
            is_build_script = bool(re.search(r"(CMakeLists\.txt|configure\.ac|Makefile)", fname, re.IGNORECASE))
            if is_build_script and depth > MAX_BUILD_SCRIPT_DEPTH:
                continue
            try:
                text = fpath.read_text(encoding="utf-8", errors="ignore")
            except OSError:
                break
            m = re.search(content_pat, text, re.IGNORECASE | re.MULTILINE)
            if m:
                ver = m.group(1).strip()
                key = (file_pat, ver)
                if ver and key not in seen_file:
                    seen_file.add(key)
                    results.append(("version_file", rel, ver))
            break  # only apply first matching rule per filename

    return results


def _parse_semver_tuple(version: str) -> tuple[int, ...]:
    """
    Parse a version string into a comparable tuple of ints.

    Strips leading 'v', splits on '.' and '-', keeps only numeric parts.
    Returns () if no numeric parts are found.
    """
    cleaned = version.lstrip("vV").split("-")[0].split(" ")[0]
    parts = []
    for part in cleaned.split("."):
        try:
            parts.append(int(part))
        except ValueError:
            break
    return tuple(parts)


def pick_best_version(found: list[tuple[str, str, str]], current_version: str = "") -> Optional[str]:
    """
    Choose the most trustworthy version from scan results.

    Priority: libretro source (ground truth) > version file.
    Within a category, take the first non-sentinel entry.

    Avoids suggesting a version downgrade vs the current plist version when the
    current version is non-sentinel — this prevents false positives where a
    vendored copy of older source code (e.g. FCEU-2.2.3/) is mistakenly preferred
    over a plist that already has the correct newer version from a submodule.
    """
    current_is_sentinel = current_version.lower() in SENTINEL_VERSIONS
    current_tuple = _parse_semver_tuple(current_version) if not current_is_sentinel else ()

    for kind in ("libretro", "version_file"):
        candidates = [v for (k, _, v) in found if k == kind and v.lower() not in SENTINEL_VERSIONS]
        if not candidates:
            continue
        best = candidates[0]
        # If current plist has a valid version and the found version is strictly
        # older, skip — the plist likely reflects a newer submodule state.
        if not current_is_sentinel and current_tuple:
            best_tuple = _parse_semver_tuple(best)
            if best_tuple and best_tuple < current_tuple:
                continue  # found version is older; try next kind
        return best
    return None


# ---------------------------------------------------------------------------
# Main logic
# ---------------------------------------------------------------------------


def analyse_core(plist_path: Path, core_root: Path) -> dict:
    """
    Analyse a single Core.plist and the corresponding source tree.

    Returns a dict with all gathered information.
    """
    info = read_plist_info(plist_path)
    rel_plist = str(plist_path.relative_to(REPO_ROOT))

    # Determine the core source directory to scan.
    # For  Cores/<CoreName>/<anything>/Core.plist  →  Cores/<CoreName>/
    # For  CoresRetro/<CoreName>/<anything>/Core.plist  →  CoresRetro/<CoreName>/
    try:
        parts = plist_path.relative_to(REPO_ROOT).parts  # e.g. ('Cores','mGBA','Sources',...)
        src_dir = REPO_ROOT / parts[0] / parts[1]
    except (ValueError, IndexError):
        src_dir = plist_path.parent

    found = scan_source_tree(src_dir)
    best = pick_best_version(found, current_version=info.get("version", ""))

    return {
        "plist":            rel_plist,
        "core":             info.get("name", plist_path.parent.name),
        "identifier":       info.get("identifier", ""),
        "url":              info.get("url", ""),
        "current_version":  info.get("version", ""),
        "disabled":         info.get("disabled", False),
        "found":            [{"kind": k, "file": f, "version": v} for k, f, v in found],
        "best_version":     best,
        "needs_update":     (
            best is not None
            and best != info.get("version", "")
            and best.lower() not in SENTINEL_VERSIONS
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Validate and optionally update emulator Core.plist versions.",
    )
    parser.add_argument(
        "--fix",
        action="store_true",
        help="Update Core.plist files in-place where a better version is found.",
    )
    parser.add_argument(
        "--json",
        action="store_true",
        help="Emit a JSON report instead of human-readable text.",
    )
    parser.add_argument(
        "--core",
        metavar="NAME",
        help="Limit to a single core (matched case-insensitively against core directory name).",
    )
    parser.add_argument(
        "--include-disabled",
        action="store_true",
        help="Include cores that have PVDisabled=true in the report (skipped by default).",
    )
    args = parser.parse_args()

    skip_disabled = not args.include_disabled

    plists = find_all_core_plists()
    if not plists:
        print("No Core.plist files found.  Run from the repo root or check paths.", file=sys.stderr)
        return 1

    results: list[dict] = []
    fixes_applied = 0

    for plist_path in plists:
        # Core directory name filter
        try:
            parts = plist_path.relative_to(REPO_ROOT).parts
            core_dir_name = parts[1] if len(parts) > 1 else plist_path.parent.name
        except ValueError:
            core_dir_name = plist_path.parent.name

        if args.core and core_dir_name.lower() != args.core.lower():
            continue

        result = analyse_core(plist_path, REPO_ROOT)

        if skip_disabled and result["disabled"]:
            continue

        results.append(result)

        if args.fix and result["needs_update"]:
            new_ver = result["best_version"]
            if update_plist_version(plist_path, new_ver):
                result["fixed"] = True
                fixes_applied += 1
                if not args.json:
                    print(
                        f"  FIXED {result['core']}: "
                        f"{result['current_version']!r} → {new_ver!r}"
                    )

    if args.json:
        print(json.dumps(results, indent=2))
        return 0

    # Human-readable report
    needs_update = [r for r in results if r["needs_update"]]
    no_source    = [r for r in results if not r["found"] and r["current_version"].lower() in SENTINEL_VERSIONS]
    up_to_date   = [r for r in results if not r["needs_update"] and r["found"]]

    print(f"\n=== Core Version Audit ({len(results)} cores) ===\n")

    if needs_update:
        print(f"[NEEDS UPDATE] {len(needs_update)} core(s):")
        for r in needs_update:
            fixed_tag = " ✓ fixed" if r.get("fixed") else ""
            print(f"  {r['core']}: {r['current_version']!r} → {r['best_version']!r}{fixed_tag}")
            for entry in r["found"][:2]:
                print(f"      [{entry['kind']}] {entry['file']}: {entry['version']}")
        print()

    if no_source:
        print(f"[NO SOURCE FOUND] {len(no_source)} core(s) with sentinel version and no source info:")
        for r in no_source:
            print(f"  {r['core']}: {r['current_version']!r}  ({r['url'] or 'no URL'})")
        print()

    if up_to_date:
        print(f"[OK] {len(up_to_date)} core(s) with version info found and matching (or not needing update):")
        for r in up_to_date:
            print(f"  {r['core']}: {r['current_version']!r}")
        print()

    unchanged = [r for r in results if not r["found"] and r["current_version"].lower() not in SENTINEL_VERSIONS]
    if unchanged:
        print(f"[UNCHANGED] {len(unchanged)} core(s) — plist version set, no source to verify:")
        for r in unchanged:
            print(f"  {r['core']}: {r['current_version']!r}")
        print()

    print(f"Summary: {len(needs_update)} need update, {len(no_source)} missing source+version, "
          f"{len(up_to_date)} ok, {len(unchanged)} unverifiable.")
    if fixes_applied:
        print(f"\n{fixes_applied} plist(s) updated.")

    return 0


if __name__ == "__main__":
    sys.exit(main())
