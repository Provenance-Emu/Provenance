#!/usr/bin/env python3
"""
generate_licenses.py — Auto-generate license manifest from Core.plist files + SPM.

Scans all Core.plist files under Cores/ and CoresRetro/, reads
Package.resolved for SPM dependencies, then outputs:
  - Scripts/licenses.json   (structured JSON)
  - LICENSES.md             (markdown table, at repo root)

Usage:
    python3 Scripts/generate_licenses.py [--output-dir <dir>] [--check] [--repo-root <dir>]

Options:
    --output-dir DIR    Directory for output files (default: repo root for LICENSES.md,
                        Scripts/ for licenses.json)
    --check             Exit non-zero if any core is missing PVLicense or PVCopyrightHolder
    --repo-root DIR     Root of the repository (default: parent of this script's directory)
"""

from __future__ import annotations

import argparse
import glob
import json
import os
import plistlib
import sys
import warnings
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _load_plist(path: Path) -> dict[str, Any] | None:
    """Load a plist file (XML or binary), return None on failure."""
    try:
        with open(path, "rb") as fh:
            return plistlib.load(fh)
    except Exception as exc:  # noqa: BLE001
        warnings.warn(f"Could not parse plist {path}: {exc}", stacklevel=2)
        return None


def _normalise_string_or_list(value: Any) -> list[str] | None:
    """Return a list given either a str or a list of str."""
    if value is None:
        return None
    if isinstance(value, list):
        return [str(v) for v in value]
    return [str(value)]


def _bool_or_none(value: Any) -> bool | None:
    if value is None:
        return None
    return bool(value)


# ---------------------------------------------------------------------------
# Core-entry builder
# ---------------------------------------------------------------------------

REQUIRED_FIELDS = ("PVLicense", "PVCopyrightHolder")


def _build_core_entry(
    data: dict[str, Any],
    *,
    is_retro: bool,
    source_path: Path,
) -> dict[str, Any]:
    """Convert a single Core.plist dict into a normalised entry."""
    name = (data.get("PVProjectName") or data.get("PVCoreIdentifier", "Unknown") or "").strip()
    identifier = data.get("PVCoreIdentifier", "")
    project_url = data.get("PVProjectURL")
    version = data.get("PVProjectVersion")
    supported_systems = data.get("PVSupportedSystems") or []

    # New fields from issue #3236 (may not exist yet — use None as default)
    license_spdx = data.get("PVLicense")
    license_url = data.get("PVLicenseURL")
    copyright_holder = _normalise_string_or_list(data.get("PVCopyrightHolder"))
    upstream_url = data.get("PVUpstreamProjectURL")
    fork_notes = data.get("PVForkNotes")
    app_store_compat = _bool_or_none(data.get("PVLicenseAppStoreCompatible"))

    # Warn about missing fields
    missing = []
    if not license_spdx:
        missing.append("PVLicense")
    if not copyright_holder:
        missing.append("PVCopyrightHolder")
    if missing:
        rel = source_path.name
        print(
            f"  WARNING: {name!r} ({identifier}) in {rel} missing: {', '.join(missing)}",
            file=sys.stderr,
        )

    return {
        "name": name,
        "identifier": identifier,
        "projectURL": project_url,
        "version": version,
        "license": license_spdx,
        "licenseURL": license_url,
        "copyrightHolder": copyright_holder,
        "upstreamProjectURL": upstream_url,
        "forkNotes": fork_notes,
        "appStoreCompatible": app_store_compat,
        "isRetroArch": is_retro,
        "supportedSystems": list(supported_systems),
        "_sourceFile": str(source_path),
    }


# ---------------------------------------------------------------------------
# Native-core scanner
# ---------------------------------------------------------------------------

def scan_native_cores(repo_root: Path) -> list[dict[str, Any]]:
    """Find and parse all native Core.plist files under Cores/."""
    entries: list[dict[str, Any]] = []
    seen_identifiers: set[str] = set()

    cores_root = repo_root / "Cores"
    if not cores_root.is_dir():
        print(f"  INFO: Cores directory not found: {cores_root}", file=sys.stderr)
        return entries

    # Glob both Cores/*/Core.plist and Cores/*/*/Core.plist
    patterns = [
        str(cores_root / "*" / "Core.plist"),
        str(cores_root / "*" / "*" / "Core.plist"),
        str(cores_root / "*" / "*" / "*" / "Core.plist"),
    ]
    found_files: set[str] = set()
    for pattern in patterns:
        for path_str in glob.glob(pattern):
            found_files.add(path_str)

    for path_str in sorted(found_files):
        path = Path(path_str)
        data = _load_plist(path)
        if data is None:
            continue

        identifier = data.get("PVCoreIdentifier", "")

        # Skip duplicates (e.g. PPSSPP has Core.plist in two places)
        if identifier and identifier in seen_identifiers:
            continue
        if identifier:
            seen_identifiers.add(identifier)

        entry = _build_core_entry(data, is_retro=False, source_path=path)
        entries.append(entry)

    return entries


# ---------------------------------------------------------------------------
# RetroArch core scanner
# ---------------------------------------------------------------------------

def scan_retroarch_cores(repo_root: Path) -> list[dict[str, Any]]:
    """Parse the RetroArch Core.plist which contains a PVCores array."""
    ra_plist_path = (
        repo_root / "CoresRetro" / "RetroArch" / "PVRetroArch" / "Core.plist"
    )
    if not ra_plist_path.is_file():
        print(f"  INFO: RA Core.plist not found: {ra_plist_path}", file=sys.stderr)
        return []

    data = _load_plist(ra_plist_path)
    if data is None:
        return []

    entries: list[dict[str, Any]] = []

    # First, add the top-level RetroArch entry itself
    top_entry = _build_core_entry(data, is_retro=True, source_path=ra_plist_path)
    entries.append(top_entry)

    # Then iterate PVCores sub-entries
    pv_cores = data.get("PVCores", [])
    if not isinstance(pv_cores, list):
        return entries

    for core_data in pv_cores:
        if not isinstance(core_data, dict):
            continue
        entry = _build_core_entry(core_data, is_retro=True, source_path=ra_plist_path)
        entries.append(entry)

    return entries


# ---------------------------------------------------------------------------
# SPM Package.resolved scanner
# ---------------------------------------------------------------------------

def scan_spm_packages(repo_root: Path) -> list[dict[str, Any]]:
    """
    Read the workspace-level Package.resolved and return lightweight
    dependency records.  License data is NOT available in Package.resolved,
    so fields default to None.
    """
    resolved_path = (
        repo_root
        / "Provenance.xcworkspace"
        / "xcshareddata"
        / "swiftpm"
        / "Package.resolved"
    )
    if not resolved_path.is_file():
        print(
            f"  INFO: Package.resolved not found at {resolved_path}; skipping SPM scan.",
            file=sys.stderr,
        )
        return []

    try:
        with open(resolved_path) as fh:
            resolved = json.load(fh)
    except Exception as exc:  # noqa: BLE001
        print(f"  WARNING: Could not parse Package.resolved: {exc}", file=sys.stderr)
        return []

    # Support both v1 (object.pins[]) and v2 (pins[]) formats
    pins = resolved.get("pins") or resolved.get("object", {}).get("pins") or []

    entries: list[dict[str, Any]] = []
    for pin in pins:
        name = pin.get("package") or pin.get("identity", "")
        repo_url = pin.get("repositoryURL") or pin.get("location", "")
        state = pin.get("state", {})
        version = state.get("version") or state.get("branch") or state.get("revision", "")[:8]

        entries.append(
            {
                "name": name,
                "identifier": f"spm.{name.lower()}",
                "projectURL": repo_url,
                "version": version,
                "license": None,
                "licenseURL": None,
                "copyrightHolder": None,
                "upstreamProjectURL": None,
                "forkNotes": None,
                "appStoreCompatible": None,
                "isRetroArch": False,
                "supportedSystems": [],
                "_sourceFile": str(resolved_path),
            }
        )

    return entries


# ---------------------------------------------------------------------------
# Output generators
# ---------------------------------------------------------------------------

def write_licenses_json(
    entries: list[dict[str, Any]],
    output_path: Path,
) -> None:
    """Write structured JSON manifest."""
    # Strip internal _sourceFile field from output
    clean_entries = []
    for e in entries:
        clean = {k: v for k, v in e.items() if not k.startswith("_")}
        clean_entries.append(clean)

    manifest = {
        "generated": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "cores": clean_entries,
    }
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as fh:
        json.dump(manifest, fh, indent=2, ensure_ascii=False)
        fh.write("\n")
    print(f"  Wrote {output_path} ({len(clean_entries)} entries)")


def _tbd(value: Any) -> str:
    """Return a human-readable cell value for the markdown table."""
    if value is None or value == "" or value == []:
        return "TBD"
    if isinstance(value, list):
        return ", ".join(str(v) for v in value)
    return str(value)


def _md_link(url: str | None, text: str) -> str:
    if url:
        return f"[{text}]({url})"
    return text


def write_licenses_md(
    entries: list[dict[str, Any]],
    output_path: Path,
) -> None:
    """Write a markdown attribution table."""
    header = (
        "# Provenance Emulator — License Attribution\n\n"
        "> Auto-generated by `Scripts/generate_licenses.py` — do not edit manually.\n\n"
        "## Emulator Cores & Libraries\n\n"
        "| Core / Library | License | Copyright Holder | Project URL | App Store Safe |\n"
        "|---|---|---|---|---|\n"
    )

    rows: list[str] = []
    for e in entries:
        name = e.get("name") or e.get("identifier") or "Unknown"
        identifier = e.get("identifier", "")
        project_url = e.get("projectURL")
        license_spdx = _tbd(e.get("license"))
        license_url = e.get("licenseURL")
        copyright_val = _tbd(e.get("copyrightHolder"))
        upstream_url = e.get("upstreamProjectURL")
        app_compat = e.get("appStoreCompatible")

        # Format the license cell: link to licenseURL if available
        if e.get("license") and license_url:
            license_cell = f"[{e['license']}]({license_url})"
        else:
            license_cell = license_spdx

        # Format the name cell: link to projectURL or upstreamProjectURL
        link_url = upstream_url or project_url
        name_cell = _md_link(link_url, name)
        if identifier:
            name_cell += f"<br/><small>`{identifier}`</small>"

        # App Store safe column
        if app_compat is True:
            app_safe_cell = "Yes"
        elif app_compat is False:
            app_safe_cell = "No"
        else:
            app_safe_cell = "TBD"

        rows.append(
            f"| {name_cell} | {license_cell} | {copyright_val} | "
            f"{_md_link(project_url, project_url or 'TBD')} | {app_safe_cell} |"
        )

    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as fh:
        fh.write(header)
        fh.write("\n".join(rows))
        fh.write("\n\n---\n_Generated: "
                 + datetime.now(timezone.utc).strftime("%Y-%m-%d")
                 + "_\n")
    print(f"  Wrote {output_path} ({len(rows)} rows)")


# ---------------------------------------------------------------------------
# Check mode
# ---------------------------------------------------------------------------

def check_completeness(entries: list[dict[str, Any]]) -> int:
    """
    Return the number of entries missing required license fields.
    Prints a summary.
    """
    incomplete = [
        e for e in entries
        if not e.get("license") or not e.get("copyrightHolder")
    ]
    if incomplete:
        print(
            f"\nCHECK: {len(incomplete)} / {len(entries)} entries missing "
            "PVLicense or PVCopyrightHolder:",
            file=sys.stderr,
        )
        for e in incomplete:
            missing = []
            if not e.get("license"):
                missing.append("license")
            if not e.get("copyrightHolder"):
                missing.append("copyrightHolder")
            print(
                f"  - {e.get('name', e.get('identifier'))} [{', '.join(missing)}]",
                file=sys.stderr,
            )
    else:
        print(f"\nCHECK: All {len(entries)} entries have required license fields.")
    return len(incomplete)


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------

def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate license manifest from Core.plist files and Package.resolved.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=None,
        help="Path to repository root (default: parent of this script's directory)",
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help=(
            "Directory for output files. LICENSES.md goes here; "
            "licenses.json goes into <output-dir>/Scripts/. "
            "Defaults to repo root."
        ),
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Exit non-zero if any core is missing required license fields.",
    )
    parser.add_argument(
        "--skip-spm",
        action="store_true",
        help="Skip scanning Package.resolved for SPM dependencies.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()

    # Resolve repo root
    script_dir = Path(__file__).resolve().parent
    repo_root = args.repo_root or script_dir.parent
    if not (repo_root / "Cores").is_dir() and not (repo_root / "CoresRetro").is_dir():
        sys.exit(
            f"ERROR: {repo_root} does not look like the Provenance repo root "
            "(no Cores/ or CoresRetro/ directory found)."
        )

    output_dir = args.output_dir or repo_root

    print("Scanning native cores …")
    native_entries = scan_native_cores(repo_root)
    print(f"  Found {len(native_entries)} native core entries.")

    print("Scanning RetroArch cores …")
    ra_entries = scan_retroarch_cores(repo_root)
    print(f"  Found {len(ra_entries)} RetroArch core entries.")

    spm_entries: list[dict[str, Any]] = []
    if not args.skip_spm:
        print("Scanning SPM packages …")
        spm_entries = scan_spm_packages(repo_root)
        print(f"  Found {len(spm_entries)} SPM package entries.")

    all_entries = native_entries + ra_entries + spm_entries

    print(f"\nTotal entries: {len(all_entries)}")
    print("\nWriting outputs …")

    json_path = output_dir / "Scripts" / "licenses.json"
    md_path = output_dir / "LICENSES.md"

    write_licenses_json(all_entries, json_path)
    write_licenses_md(all_entries, md_path)

    if args.check:
        missing_count = check_completeness(all_entries)
        if missing_count:
            sys.exit(1)


if __name__ == "__main__":
    main()
