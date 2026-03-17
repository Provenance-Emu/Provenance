#!/usr/bin/env python3
"""
update_core_licenses.py — Sync PVRetroArch/Core.plist license data from libretro .info files.

Usage:
  python3 Scripts/update_core_licenses.py [--dry-run]

The script reads PVRetroArch/Core.plist, looks up each core in the
libretro-super dist/info directory, and applies license name + URL updates.
Entries with missing data are filled in; incorrect entries are corrected.
Already-correct entries are left untouched.

The authoritative source for license *type* is the .info file.
The authoritative source for license *URL* is the MANUAL_OVERRIDES table below,
which should be updated when repos move files or new cores are added.
"""

import argparse
import os
import plistlib
import sys

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(SCRIPT_DIR)
PLIST_PATH = os.path.join(REPO_ROOT, "PVRetroArch", "Core.plist")
INFO_DIR = os.path.join(REPO_ROOT, "libretro-super", "dist", "info")

# ---------------------------------------------------------------------------
# SPDX / display name mapping from libretro .info license strings
# ---------------------------------------------------------------------------
LICENSE_NAME_MAP = {
    "GPLv2":              "GPL-2.0-or-later",
    "GPLv2+":             "GPL-2.0-or-later",
    "GPL-2.0-only":       "GPL-2.0-only",
    "GPLv3":              "GPL-3.0-or-later",
    "GPLv3+":             "GPL-3.0-or-later",
    "LGPLv2.1+":          "LGPL-2.1-or-later",
    "LGPLv3":             "LGPL-3.0-only",
    "MIT":                "MIT",
    "Zlib":               "Zlib",
    "Artistic License":   "Artistic-2.0",
    "Non-commercial":     "LicenseRef-NonCommercial",
    "MAME":               "LicenseRef-MAME",
    "MAME Noncommercial": "LicenseRef-MAME-NC",
    "LicenseRef-FBNeo":   "LicenseRef-FBNeo",
}

# ---------------------------------------------------------------------------
# Manual overrides: keyed by PVProjectName (exact match).
# Format: (license_name, license_url, new_project_url_or_None)
# new_project_url_or_None — only set if the existing PVProjectURL is wrong.
# ---------------------------------------------------------------------------
MANUAL_OVERRIDES = {
    # --- Wrong BSD-3-Clause + MAME URL mismatches ---
    "MAME 2000 (RetroArch)": (
        "LicenseRef-MAME",
        "https://github.com/libretro/mame2000-libretro/blob/HEAD/LICENSE.md",
        None,
    ),
    "MAME 2003 (RetroArch)": (
        "LicenseRef-MAME",
        "https://github.com/libretro/mame2003-libretro/blob/HEAD/LICENSE.md",
        None,
    ),
    "MAME 2003 Plus (RetroArch)": (
        "LicenseRef-MAME-NC",
        "https://github.com/libretro/mame2003-plus-libretro/blob/HEAD/LICENSE.md",
        "https://github.com/libretro/mame2003-plus-libretro",  # plist has wrong URL
    ),
    "MAME 2010 (RetroArch)": (
        "LicenseRef-MAME",
        "https://github.com/libretro/mame2010-libretro/blob/HEAD/LICENSE.md",
        None,
    ),
    "MAME (Current) (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/mame/blob/HEAD/LICENSE.md",
        None,
    ),
    "Same CDi (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/same_cdi/blob/HEAD/LICENSE.md",
        None,
    ),
    # --- Missing license data ---
    "EightyOne (ZX81) (RetroArch)": (
        "GPL-3.0-or-later",
        "https://github.com/libretro/81-libretro/blob/HEAD/COPYING",
        None,
    ),
    "BSNES Mercury (Performance) (RetroArch)": (
        "GPL-3.0-or-later",
        "https://github.com/libretro/bsnes-mercury/blob/HEAD/COPYING",
        "https://github.com/libretro/bsnes-mercury",
    ),
    "FBAlpha 2012 (RetroArch)": (
        "LicenseRef-NonCommercial",
        "https://github.com/libretro/fbalpha/blob/HEAD/LICENSE.md",
        None,
    ),
    "FBAlpha 2012 NeoGeo (RetroArch)": (
        "LicenseRef-NonCommercial",
        "https://github.com/libretro/fbalpha/blob/HEAD/LICENSE.md",
        None,
    ),
    "fMSX (RetroArch)": (
        "LicenseRef-NonCommercial",
        "https://github.com/libretro/fmsx-libretro/blob/HEAD/LICENSE",
        None,
    ),
    "Fairchild ChannelF (FreeChaf) (RetroArch)": (
        "GPL-3.0-or-later",
        "https://github.com/libretro/freechaf/blob/HEAD/COPYING",
        None,
    ),
    "FreeINTV (RetroArch)": (
        "GPL-3.0-or-later",
        "https://github.com/libretro/FreeIntv/blob/HEAD/COPYING",
        None,
    ),
    "Gambatte (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/gambatte-libretro/blob/HEAD/COPYING",
        None,
    ),
    "Gearcoleco (RetroArch)": (
        "GPL-3.0-or-later",
        "https://github.com/drhelius/Gearcoleco/blob/HEAD/COPYING",
        None,
    ),
    "gpSP (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/gpsp/blob/HEAD/COPYING",
        None,
    ),
    "Handy (Atari Lynx) (RetroArch)": (
        "Zlib",
        "https://github.com/libretro/libretro-handy/blob/HEAD/COPYING",
        None,
    ),
    "Beetle PC Engine (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/beetle-pce-libretro/blob/HEAD/COPYING",
        None,
    ),
    "Beetle PC Engine Fast (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/beetle-pce-fast-libretro/blob/HEAD/COPYING",
        None,
    ),
    "Beetle PC-FX (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/beetle-pcfx-libretro/blob/HEAD/COPYING",
        None,
    ),
    "Beetle SNES (RetroArch)": (
        "GPL-3.0-or-later",
        "https://github.com/libretro/beetle-bsnes-libretro/blob/HEAD/COPYING",
        None,
    ),
    "Beetle WonderSwan (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/beetle-wswan-libretro/blob/HEAD/COPYING",
        None,
    ),
    "NeoCD (RetroArch)": (
        "LGPL-3.0-only",
        "https://github.com/libretro/neocd_libretro/blob/HEAD/LICENSE",
        None,
    ),
    "O2EM (Odyssey 2) (RetroArch)": (
        "Artistic-2.0",
        "https://github.com/libretro/libretro-o2em/blob/HEAD/COPYING",
        None,
    ),
    "PUAE (Amiga) (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/libretro-uae/blob/HEAD/LICENSE",
        None,
    ),
    "PUAE 2021 (Amiga) (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/libretro-uae/blob/HEAD/LICENSE",
        None,
    ),
    "QuickNES (RetroArch)": (
        "LGPL-2.1-or-later",
        "https://github.com/libretro/QuickNES_Core/blob/HEAD/COPYING",
        None,
    ),
    "SameDuck (RetroArch)": (
        "MIT",
        "https://github.com/libretro/libretro-SameDuck/blob/HEAD/LICENSE",
        None,
    ),
    "ScummVM (RetroArch)": (
        "GPL-3.0-or-later",
        "https://github.com/libretro/scummvm/blob/HEAD/COPYING",
        None,
    ),
    "SMS Plus GX (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/smsplus-gx/blob/HEAD/COPYING",
        None,
    ),
    "Snes9x 2002 (RetroArch)": (
        "LicenseRef-Snes9x",
        "https://github.com/libretro/snes9x2002/blob/HEAD/LICENSE",
        None,
    ),
    "Snes9x 2005 (RetroArch)": (
        "LicenseRef-Snes9x",
        "https://github.com/libretro/snes9x2005/blob/HEAD/LICENSE",
        None,
    ),
    "Snes9x 2005 Plus (RetroArch)": (
        "LicenseRef-Snes9x",
        "https://github.com/libretro/snes9x2005/blob/HEAD/LICENSE",
        None,
    ),
    "Snes9x 2010 (RetroArch)": (
        "LicenseRef-Snes9x",
        "https://github.com/libretro/snes9x2010/blob/HEAD/LICENSE",
        None,
    ),
    "Stella (Current) (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/stella-emu/stella/blob/HEAD/License.txt",
        None,
    ),
    "Stella 2023 (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/stella2023-libretro/blob/HEAD/COPYING",
        None,
    ),
    "VBA Next (RetroArch)": (
        "GPL-2.0-or-later",
        "https://github.com/libretro/vba-next/blob/HEAD/COPYING",
        None,
    ),
}


def load_info_file(project_name: str, project_url: str) -> dict[str, str]:
    """Try to find and parse a .info file for the given core."""
    # Derive a candidate filename from the project URL
    if project_url and "github.com" in project_url:
        repo = project_url.rstrip("/").split("/")[-1]
        candidate = repo.replace("-", "_")
        if not candidate.endswith("_libretro"):
            candidate += "_libretro"
        path = os.path.join(INFO_DIR, candidate + ".info")
        if os.path.isfile(path):
            return _parse_info(path)
    return {}


def _parse_info(path: str) -> dict[str, str]:
    result = {}
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            line = line.strip()
            if "=" in line and not line.startswith("#"):
                k, _, v = line.partition("=")
                result[k.strip()] = v.strip().strip('"')
    return result


def apply_updates(dry_run: bool = False) -> None:
    with open(PLIST_PATH, "rb") as f:
        data = plistlib.load(f)

    cores = data.get("PVCores", [])
    changed = 0

    for core in cores:
        name = core.get("PVProjectName", "")
        if name not in MANUAL_OVERRIDES:
            continue

        lic_name, lic_url, new_project_url = MANUAL_OVERRIDES[name]

        updates = []
        if core.get("PVLicenseName") != lic_name:
            updates.append(f"  LicenseName: {core.get('PVLicenseName')!r} → {lic_name!r}")
        if core.get("PVLicenseURL") != lic_url:
            updates.append(f"  LicenseURL:  {core.get('PVLicenseURL')!r} → {lic_url!r}")
        if new_project_url and core.get("PVProjectURL") != new_project_url:
            updates.append(f"  ProjectURL:  {core.get('PVProjectURL')!r} → {new_project_url!r}")

        if updates:
            print(f"{'[DRY RUN] ' if dry_run else ''}Updating: {name}")
            for u in updates:
                print(u)
            changed += 1
            if not dry_run:
                core["PVLicenseName"] = lic_name
                core["PVLicenseURL"] = lic_url
                if new_project_url:
                    core["PVProjectURL"] = new_project_url

    if not dry_run and changed:
        with open(PLIST_PATH, "wb") as f:
            plistlib.dump(data, f, fmt=plistlib.FMT_XML)
        print(f"\n✓ Updated {changed} core(s) in Core.plist")
    elif dry_run:
        print(f"\n(dry run) Would update {changed} core(s)")
    else:
        print("No changes needed.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dry-run", action="store_true", help="Show changes without writing")
    args = parser.parse_args()
    apply_updates(dry_run=args.dry_run)
