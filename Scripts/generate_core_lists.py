#!/usr/bin/env python3
"""
generate_core_lists.py — Generate libretro core URL lists and xcfilelists from cores.yml

Usage:
    python3 Scripts/generate_core_lists.py [command] [options]

Commands:
    generate        Generate all output files from cores.yml (default)
    validate        HTTP HEAD check all URLs in the manifest
    diff            Show diff between current files and what would be generated
    bootstrap       Read existing txt files and print a starter YAML

Options:
    --dry-run       (generate only) Print what would be written without writing files
    --manifest PATH Path to cores.yml (default: auto-detected relative to script)
    --verbose       Show additional output

This script uses only Python 3.8+ stdlib (no external dependencies).
"""

import argparse
import difflib
import os
import re
import sys
import urllib.request
import urllib.error
from typing import Dict, List, Optional, Tuple

# ---------------------------------------------------------------------------
# Paths
# ---------------------------------------------------------------------------

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
SCRIPTS_DIR = os.path.join(REPO_ROOT, "CoresRetro", "RetroArch", "scripts")
DEFAULT_MANIFEST = os.path.join(SCRIPTS_DIR, "cores.yml")

OUTPUT_FILES = {
    "urls_ios":           os.path.join(SCRIPTS_DIR, "urls.txt"),
    "urls_appstore_ios":  os.path.join(SCRIPTS_DIR, "urls-appstore.txt"),
    "urls_tvos":          os.path.join(SCRIPTS_DIR, "urls-tv.txt"),
    "urls_appstore_tvos": os.path.join(SCRIPTS_DIR, "urls-appstore-tv.txt"),
    "xcf_ios":            os.path.join(SCRIPTS_DIR, "output_modules.xcfilelist"),
    "xcf_appstore_ios":   os.path.join(SCRIPTS_DIR, "output_modules_appstore_ios.xcfilelist"),
    "xcf_tvos":           os.path.join(SCRIPTS_DIR, "output_modules_tv.xcfilelist"),
    "xcf_appstore_tvos":  os.path.join(SCRIPTS_DIR, "output_modules_appstore_tv.xcfilelist"),
}

# ---------------------------------------------------------------------------
# Minimal YAML parser (stdlib only — no PyYAML dependency)
# ---------------------------------------------------------------------------

def _strip_comment(line: str) -> str:
    """Remove inline YAML comments, respecting quoted strings."""
    in_single = False
    in_double = False
    for i, ch in enumerate(line):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == '#' and not in_single and not in_double:
            return line[:i].rstrip()
    return line


def _parse_scalar(value: str) -> object:
    """Convert a YAML scalar string to a Python value."""
    v = value.strip().strip('"').strip("'")
    if v.lower() == 'true':
        return True
    if v.lower() == 'false':
        return False
    if v.lower() == 'null' or v == '~':
        return None
    return v


def parse_yaml(text: str) -> dict:
    """
    Parse a simple YAML file into a Python dict/list structure.

    Supports:
    - Block mappings and sequences
    - Inline string, bool, null scalars
    - Quoted strings
    - Comments (# …)
    - Multi-level nesting via indentation

    Does NOT support: anchors, tags, flow collections, multi-line scalars.
    """
    lines = text.splitlines()

    def parse_block(lines: List[str], start: int, base_indent: int):
        """
        Parse a block starting at `start` with minimum indent `base_indent`.
        Returns (result, next_line_index).
        result is a dict, list, or scalar.
        """
        result = None
        result_type = None  # 'dict' | 'list' | None

        i = start
        while i < len(lines):
            raw = lines[i]
            stripped = raw.rstrip()

            # Skip blank lines and comment-only lines
            if not stripped or stripped.lstrip().startswith('#'):
                i += 1
                continue

            indent = len(raw) - len(raw.lstrip())

            # If we've dedented past our base, stop
            if indent < base_indent:
                break

            content = _strip_comment(stripped).strip()

            if content.startswith('- '):
                # List item on same line: "- key: val" or "- scalar"
                if result_type is None:
                    result = []
                    result_type = 'list'
                elif result_type != 'list':
                    raise ValueError(f"Mixed mapping/sequence at line {i+1}")

                item_content = content[2:].strip()

                if ':' in item_content:
                    # Inline mapping item or start of a nested mapping
                    # Check if it's a full "key: value" on one line
                    match = re.match(r'^([^:]+):\s*(.*)', item_content)
                    if match:
                        key = match.group(1).strip().strip('"').strip("'")
                        val_str = match.group(2).strip()
                        if val_str:
                            # Single-line mapping item — collect additional keys on next lines
                            item_dict = {key: _parse_scalar(val_str)}
                            i += 1
                            # Collect sibling keys at indent + 2 or indent + 4
                            item_indent = indent + 2
                            while i < len(lines):
                                raw2 = lines[i]
                                s2 = raw2.rstrip()
                                if not s2 or s2.lstrip().startswith('#'):
                                    i += 1
                                    continue
                                ind2 = len(raw2) - len(raw2.lstrip())
                                if ind2 < item_indent:
                                    break
                                c2 = _strip_comment(s2).strip()
                                m2 = re.match(r'^([^:]+):\s*(.*)', c2)
                                if m2:
                                    k2 = m2.group(1).strip().strip('"').strip("'")
                                    v2 = m2.group(2).strip()
                                    if v2:
                                        item_dict[k2] = _parse_scalar(v2)
                                    else:
                                        # Nested value — recurse
                                        nested, i = parse_block(lines, i + 1, ind2 + 2)
                                        item_dict[k2] = nested
                                        continue
                                i += 1
                            result.append(item_dict)
                            continue
                        else:
                            # "- key:" with nested value
                            item_dict = {}
                            # look for nested content
                            i += 1
                            item_indent = indent + 2
                            while i < len(lines):
                                raw2 = lines[i]
                                s2 = raw2.rstrip()
                                if not s2 or s2.lstrip().startswith('#'):
                                    i += 1
                                    continue
                                ind2 = len(raw2) - len(raw2.lstrip())
                                if ind2 < item_indent:
                                    break
                                c2 = _strip_comment(s2).strip()
                                m2 = re.match(r'^([^:]+):\s*(.*)', c2)
                                if m2:
                                    k2 = m2.group(1).strip().strip('"').strip("'")
                                    v2 = m2.group(2).strip()
                                    if v2:
                                        item_dict[k2] = _parse_scalar(v2)
                                    else:
                                        nested, i = parse_block(lines, i + 1, ind2 + 2)
                                        item_dict[k2] = nested
                                        continue
                                i += 1
                            result.append(item_dict)
                            continue
                else:
                    result.append(_parse_scalar(item_content))
                    i += 1
                    continue

            elif content.startswith('-'):
                # Bare list item "- " with possibly sub-block on next lines
                if result_type is None:
                    result = []
                    result_type = 'list'
                # recurse
                nested, i = parse_block(lines, i + 1, indent + 2)
                result.append(nested)
                continue

            elif ':' in content:
                match = re.match(r'^([^:]+):\s*(.*)', content)
                if match:
                    key = match.group(1).strip().strip('"').strip("'")
                    val_str = match.group(2).strip()

                    if result_type is None:
                        result = {}
                        result_type = 'dict'
                    elif result_type != 'dict':
                        raise ValueError(f"Mixed sequence/mapping at line {i+1}")

                    if val_str:
                        result[key] = _parse_scalar(val_str)
                        i += 1
                    else:
                        # Check next non-blank line's indent
                        j = i + 1
                        while j < len(lines) and (not lines[j].strip() or lines[j].lstrip().startswith('#')):
                            j += 1
                        if j < len(lines):
                            next_indent = len(lines[j]) - len(lines[j].lstrip())
                            if next_indent > indent:
                                nested, i = parse_block(lines, i + 1, next_indent)
                                result[key] = nested
                                continue
                        result[key] = None
                        i += 1
                else:
                    i += 1
            else:
                i += 1

        return result, i

    result, _ = parse_block(lines, 0, 0)
    return result or {}


# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------

class BuildbotConfig:
    def __init__(self, data: dict):
        self.base_url: str = data.get("base_url", "")
        self.ios_path: str = data.get("ios_path", "")
        self.tvos_path: str = data.get("tvos_path", "")

    @property
    def ios_base(self) -> str:
        return f"{self.base_url}/{self.ios_path}"

    @property
    def tvos_base(self) -> str:
        return f"{self.base_url}/{self.tvos_path}"


class CoreEntry:
    def __init__(self, data: dict):
        self.name: str = data.get("name", "")
        self.ios: bool = bool(data.get("ios", True))
        self.tvos: bool = bool(data.get("tvos", True))
        self.appstore: bool = bool(data.get("appstore", True))
        self.enabled: bool = bool(data.get("enabled", True))
        # Platform-neutral: same file for both iOS and tvOS
        self.filename: Optional[str] = data.get("filename") or None
        # Per-platform overrides (for cores with non-standard filenames)
        self._ios_filename: Optional[str] = data.get("ios_filename") or None
        self._tvos_filename: Optional[str] = data.get("tvos_filename") or None
        self.appstore_excluded_reason: Optional[str] = data.get("appstore_excluded_reason") or None

    @property
    def is_platform_neutral(self) -> bool:
        return self.filename is not None

    def ios_filename(self) -> str:
        if self._ios_filename:
            return self._ios_filename
        if self.filename:
            return self.filename
        return f"{self.name}_libretro_ios.dylib"

    def tvos_filename(self) -> str:
        if self._tvos_filename:
            return self._tvos_filename
        if self.filename:
            return self.filename
        return f"{self.name}_libretro_tvos.dylib"

    def ios_url(self, buildbot: BuildbotConfig) -> str:
        return f"{buildbot.ios_base}/{self.ios_filename()}.zip"

    def tvos_url(self, buildbot: BuildbotConfig) -> str:
        return f"{buildbot.tvos_base}/{self.tvos_filename()}.zip"


class CoreManifest:
    def __init__(self, data: dict):
        self.buildbot = BuildbotConfig(data.get("buildbot", {}))
        raw_cores = data.get("cores", []) or []
        self.cores: List[CoreEntry] = [CoreEntry(c) for c in raw_cores if isinstance(c, dict)]

    def ios_cores(self, appstore: bool = False) -> List[CoreEntry]:
        """Return cores applicable to iOS (optionally filtered for App Store)."""
        return [c for c in self.cores if c.ios and (not appstore or c.appstore)]

    def tvos_cores(self, appstore: bool = False) -> List[CoreEntry]:
        """Return cores applicable to tvOS (optionally filtered for App Store)."""
        return [c for c in self.cores if c.tvos and (not appstore or c.appstore)]


# ---------------------------------------------------------------------------
# File generation helpers
# ---------------------------------------------------------------------------

XCFILELIST_HEADER = (
    "# Auto-generated by Scripts/generate_core_lists.py\n"
    "# Do not edit manually — edit CoresRetro/RetroArch/scripts/cores.yml instead\n"
    "# and re-run: python3 Scripts/generate_core_lists.py generate\n"
)

XCFILELIST_PREFIX = "$(SRCROOT)/CoresRetro/RetroArch/modules/"


def generate_url_file(
    cores: List[CoreEntry],
    buildbot: BuildbotConfig,
    platform: str,          # 'ios' | 'tvos'
    appstore: bool,
    verbose: bool = False,
) -> str:
    """Generate the content of a urls*.txt file."""
    # No header — URL files are consumed directly by `xargs curl -O` and
    # header lines with spaces would be tokenised into invalid curl arguments.
    lines: List[str] = []
    for core in cores:
        if platform == "ios":
            url = core.ios_url(buildbot)
        else:
            url = core.tvos_url(buildbot)

        # A core appears commented when:
        # 1. globally disabled (enabled=false), or
        # 2. appstore build and this core is appstore-excluded (appstore=false)
        is_disabled = not core.enabled
        is_appstore_excluded = appstore and not core.appstore

        if is_disabled or is_appstore_excluded:
            lines.append(f"#{url}\n")
        else:
            lines.append(f"{url}\n")

    return "".join(lines)


def generate_xcfilelist(
    cores: List[CoreEntry],
    platform: str,      # 'ios' | 'tvos'
    appstore: bool,
) -> str:
    """Generate the content of an output_modules*.xcfilelist file."""
    lines = [XCFILELIST_HEADER]
    for core in cores:
        fname = core.ios_filename() if platform == "ios" else core.tvos_filename()

        # Disabled cores appear as commented entries (matching existing file convention)
        if not core.enabled:
            lines.append(f"#{XCFILELIST_PREFIX}{fname}\n")
            continue

        # Appstore-excluded cores are commented in appstore xcfilelists
        if appstore and not core.appstore:
            lines.append(f"#{XCFILELIST_PREFIX}{fname}\n")
            continue

        lines.append(f"{XCFILELIST_PREFIX}{fname}\n")

    return "".join(lines)


# ---------------------------------------------------------------------------
# Command: generate
# ---------------------------------------------------------------------------

def cmd_generate(manifest: CoreManifest, dry_run: bool, verbose: bool) -> None:
    """Generate all output files from the manifest."""

    # Build all ios/tvos core lists (full, not filtered for appstore)
    all_ios = manifest.ios_cores(appstore=False)
    all_tvos = manifest.tvos_cores(appstore=False)

    # For appstore variants, we still include the same set of cores from the
    # per-platform list — the appstore flag marks them commented/omitted
    outputs: Dict[str, str] = {
        "urls_ios":           generate_url_file(all_ios,  manifest.buildbot, "ios",  appstore=False, verbose=verbose),
        "urls_appstore_ios":  generate_url_file(all_ios,  manifest.buildbot, "ios",  appstore=True,  verbose=verbose),
        "urls_tvos":          generate_url_file(all_tvos, manifest.buildbot, "tvos", appstore=False, verbose=verbose),
        "urls_appstore_tvos": generate_url_file(all_tvos, manifest.buildbot, "tvos", appstore=True,  verbose=verbose),
        "xcf_ios":            generate_xcfilelist(all_ios,  "ios",  appstore=False),
        "xcf_appstore_ios":   generate_xcfilelist(all_ios,  "ios",  appstore=True),
        "xcf_tvos":           generate_xcfilelist(all_tvos, "tvos", appstore=False),
        "xcf_appstore_tvos":  generate_xcfilelist(all_tvos, "tvos", appstore=True),
    }

    for key, content in outputs.items():
        path = OUTPUT_FILES[key]
        if dry_run:
            print(f"[dry-run] Would write {len(content.splitlines())} lines to {path}")
            if verbose:
                print(content)
                print()
        else:
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as fh:
                fh.write(content)
            print(f"  Written: {path}")

    if not dry_run:
        print("Done.")


# ---------------------------------------------------------------------------
# Command: validate
# ---------------------------------------------------------------------------

def cmd_validate(manifest: CoreManifest, verbose: bool) -> None:
    """HTTP HEAD check all enabled URLs in the manifest."""
    errors = 0
    checked = 0

    all_ios = manifest.ios_cores(appstore=False)
    all_tvos = manifest.tvos_cores(appstore=False)

    urls: List[Tuple[str, str]] = []
    seen: set = set()

    for core in all_ios:
        if not core.enabled:
            continue
        url = core.ios_url(manifest.buildbot)
        if url not in seen:
            urls.append((core.name, url))
            seen.add(url)

    for core in all_tvos:
        if not core.enabled:
            continue
        url = core.tvos_url(manifest.buildbot)
        if url not in seen:
            urls.append((core.name, url))
            seen.add(url)

    print(f"Validating {len(urls)} URLs...")

    for name, url in urls:
        try:
            req = urllib.request.Request(url, method="HEAD")
            with urllib.request.urlopen(req, timeout=10) as resp:
                status = resp.status
        except urllib.error.HTTPError as e:
            status = e.code
        except Exception as e:
            status = str(e)

        checked += 1
        if isinstance(status, int) and status < 400:
            marker = "OK "
        else:
            marker = "FAIL"
            errors += 1

        print(f"  [{marker}] {status:>3}  {url}")

    print(f"\n{checked} checked, {errors} failures.")
    if errors:
        sys.exit(1)


# ---------------------------------------------------------------------------
# Command: diff
# ---------------------------------------------------------------------------

def cmd_diff(manifest: CoreManifest, verbose: bool) -> None:
    """Show diff between what would be generated and current files on disk."""
    all_ios = manifest.ios_cores(appstore=False)
    all_tvos = manifest.tvos_cores(appstore=False)

    outputs: Dict[str, str] = {
        "urls_ios":           generate_url_file(all_ios,  manifest.buildbot, "ios",  appstore=False),
        "urls_appstore_ios":  generate_url_file(all_ios,  manifest.buildbot, "ios",  appstore=True),
        "urls_tvos":          generate_url_file(all_tvos, manifest.buildbot, "tvos", appstore=False),
        "urls_appstore_tvos": generate_url_file(all_tvos, manifest.buildbot, "tvos", appstore=True),
        "xcf_ios":            generate_xcfilelist(all_ios,  "ios",  appstore=False),
        "xcf_appstore_ios":   generate_xcfilelist(all_ios,  "ios",  appstore=True),
        "xcf_tvos":           generate_xcfilelist(all_tvos, "tvos", appstore=False),
        "xcf_appstore_tvos":  generate_xcfilelist(all_tvos, "tvos", appstore=True),
    }

    any_diff = False
    for key, generated in outputs.items():
        path = OUTPUT_FILES[key]
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as fh:
                current = fh.read()
        else:
            current = ""

        if current != generated:
            any_diff = True
            diff = difflib.unified_diff(
                current.splitlines(keepends=True),
                generated.splitlines(keepends=True),
                fromfile=f"current/{os.path.basename(path)}",
                tofile=f"generated/{os.path.basename(path)}",
            )
            sys.stdout.writelines(diff)
            print()

    if not any_diff:
        print("No differences — generated output matches existing files.")


# ---------------------------------------------------------------------------
# Command: bootstrap
# ---------------------------------------------------------------------------

def _parse_url_file(path: str) -> List[Tuple[bool, str]]:
    """
    Parse a urls*.txt file.
    Returns list of (enabled, filename) tuples where filename is the dylib basename.
    """
    entries = []
    if not os.path.exists(path):
        return entries
    with open(path, "r", encoding="utf-8") as fh:
        for line in fh:
            line = line.strip()
            if not line:
                continue
            enabled = not line.startswith("#")
            url = line.lstrip("#").strip()
            fname = url.split("/")[-1]
            # Strip .zip suffix
            if fname.endswith(".zip"):
                fname = fname[:-4]
            entries.append((enabled, fname))
    return entries


def _core_name_from_filename(filename: str) -> Tuple[str, Optional[str]]:
    """
    Extract (core_name, custom_filename_or_None) from a dylib filename.

    Standard: fceumm_libretro_ios.dylib → ("fceumm", None)
    Platform-neutral: flycast_libretro.dylib → ("flycast", "flycast_libretro.dylib")
    """
    base = filename
    if base.endswith(".dylib"):
        base = base[:-6]  # strip .dylib

    # Check for platform suffix (including known upstream typo: _ibretro instead of _libretro)
    if base.endswith("_libretro_ios"):
        return base[:-13], None
    elif base.endswith("_libretro_tvos"):
        return base[:-14], None
    elif base.endswith("_ibretro_ios"):
        # Handle upstream typo: return filename so bootstrap can round-trip it
        return base[:-12], filename
    elif base.endswith("_ibretro_tvos"):
        # Handle upstream typo: return filename so bootstrap can round-trip it
        return base[:-13], filename
    else:
        # Platform-neutral — return original filename
        return base.replace("_libretro", ""), filename


def cmd_bootstrap(manifest_path: str) -> None:
    """
    Read existing urls*.txt files and print a starter YAML to stdout.
    Useful for verifying the manifest matches reality.
    """
    ios_path = os.path.join(SCRIPTS_DIR, "urls.txt")
    ios_as_path = os.path.join(SCRIPTS_DIR, "urls-appstore.txt")
    tvos_path = os.path.join(SCRIPTS_DIR, "urls-tv.txt")
    tvos_as_path = os.path.join(SCRIPTS_DIR, "urls-appstore-tv.txt")

    ios_entries = _parse_url_file(ios_path)
    ios_as_entries = _parse_url_file(ios_as_path)
    tvos_entries = _parse_url_file(tvos_path)
    tvos_as_entries = _parse_url_file(tvos_as_path)

    # Build sets for quick lookup
    ios_enabled = {fname for en, fname in ios_entries if en}
    ios_disabled = {fname for en, fname in ios_entries if not en}
    ios_as_enabled = {fname for en, fname in ios_as_entries if en}

    tvos_enabled = {fname for en, fname in tvos_entries if en}
    tvos_disabled = {fname for en, fname in tvos_entries if not en}
    tvos_as_enabled = {fname for en, fname in tvos_as_entries if en}

    # All filenames across both platforms
    all_filenames: Dict[str, dict] = {}

    def register(filename: str, platform: str, enabled: bool, appstore: bool) -> None:
        name, custom = _core_name_from_filename(filename)
        if name not in all_filenames:
            all_filenames[name] = {
                "name": name,
                "ios": False,
                "tvos": False,
                "appstore": True,
                "enabled": True,
                "filename": None,
                "ios_filename": None,
                "tvos_filename": None,
            }
        entry = all_filenames[name]
        if platform == "ios":
            entry["ios"] = True
        else:
            entry["tvos"] = True
        if not appstore:
            entry["appstore"] = False
        if custom:
            base = custom[:-6] if custom.endswith(".dylib") else custom
            if platform == "ios" and base.endswith("_ios"):
                # Per-platform iOS override (e.g. _ibretro_ios pattern)
                if not entry["ios_filename"]:
                    entry["ios_filename"] = custom
            elif platform == "tvos" and base.endswith("_tvos"):
                # Per-platform tvOS override (e.g. _ibretro_tvos pattern)
                if not entry["tvos_filename"]:
                    entry["tvos_filename"] = custom
            elif not entry["filename"]:
                # Platform-neutral filename
                entry["filename"] = custom

    for en, fname in ios_entries:
        # Check appstore: if this fname is NOT in ios_as_enabled set and IS in ios_enabled, it's excluded
        in_as = fname in ios_as_enabled
        register(fname, "ios", en, in_as if en else True)

    for en, fname in tvos_entries:
        tvos_fname = fname
        # Translate tvos filename to check in appstore set
        in_as = tvos_fname in tvos_as_enabled
        register(fname, "tvos", en, in_as if en else True)

    # Determine globally-disabled (commented in all files)
    # Use per-platform filename overrides when present for correct lookup.
    for name, entry in all_filenames.items():
        ios_fname = (entry["ios_filename"]
                     or entry["filename"]
                     or f"{name}_libretro_ios.dylib")
        tvos_fname = (entry["tvos_filename"]
                      or entry["filename"]
                      or f"{name}_libretro_tvos.dylib")
        ios_disabled_here = ios_fname in ios_disabled
        tvos_disabled_here = tvos_fname in tvos_disabled
        if entry["ios"] and entry["tvos"]:
            entry["enabled"] = not (ios_disabled_here and tvos_disabled_here)
        elif entry["ios"]:
            entry["enabled"] = not ios_disabled_here
        else:
            entry["enabled"] = not tvos_disabled_here

    print("# Bootstrap output — cores derived from existing txt files")
    print("# Review and merge into cores.yml as needed")
    print()
    print("cores:")
    for name, entry in sorted(all_filenames.items()):
        print(f"  - name: {entry['name']}")
        print(f"    ios: {'true' if entry['ios'] else 'false'}")
        print(f"    tvos: {'true' if entry['tvos'] else 'false'}")
        print(f"    appstore: {'true' if entry['appstore'] else 'false'}")
        print(f"    enabled: {'true' if entry['enabled'] else 'false'}")
        if entry["filename"]:
            print(f"    filename: \"{entry['filename']}\"")
        if entry["ios_filename"]:
            print(f"    ios_filename: \"{entry['ios_filename']}\"")
        if entry["tvos_filename"]:
            print(f"    tvos_filename: \"{entry['tvos_filename']}\"")
        print()


# ---------------------------------------------------------------------------
# Main entry point
# ---------------------------------------------------------------------------

def load_manifest(path: str) -> CoreManifest:
    if not os.path.exists(path):
        print(f"Error: manifest not found at {path}", file=sys.stderr)
        sys.exit(1)
    with open(path, "r", encoding="utf-8") as fh:
        text = fh.read()
    data = parse_yaml(text)
    if not data:
        print(f"Error: failed to parse YAML from {path}", file=sys.stderr)
        sys.exit(1)
    return CoreManifest(data)


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Generate libretro core URL lists from cores.yml",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__,
    )
    parser.add_argument(
        "command",
        nargs="?",
        default="generate",
        choices=["generate", "validate", "diff", "bootstrap"],
        help="Command to run (default: generate)",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="(generate) Print what would be written without writing files",
    )
    parser.add_argument(
        "--manifest",
        default=DEFAULT_MANIFEST,
        metavar="PATH",
        help=f"Path to cores.yml (default: {DEFAULT_MANIFEST})",
    )
    parser.add_argument(
        "--verbose", "-v",
        action="store_true",
        help="Show additional output",
    )

    args = parser.parse_args()

    if args.command == "bootstrap":
        cmd_bootstrap(args.manifest)
        return

    manifest = load_manifest(args.manifest)

    if args.command == "generate":
        cmd_generate(manifest, dry_run=args.dry_run, verbose=args.verbose)
    elif args.command == "validate":
        cmd_validate(manifest, verbose=args.verbose)
    elif args.command == "diff":
        cmd_diff(manifest, verbose=args.verbose)
    else:
        parser.print_help()
        sys.exit(1)


if __name__ == "__main__":
    main()
