#!/usr/bin/env python3
"""
generate_uti_declarations.py — Provenance UTI/MIME Registration Generator

Reads systems.plist and outputs UTExportedTypeDeclarations + UTImportedTypeDeclarations
for embedding in iOS/tvOS Info.plist files.

Usage:
    python3 Scripts/generate_uti_declarations.py
    python3 Scripts/generate_uti_declarations.py --update-plist Provenance/Provenance-Info.plist

Design:
- Provenance-owned ROM types → UTExportedTypeDeclarations
  • com.provenance.rom (base, abstract parent)
  • com.provenance.rom.<system> (per-system, conform to base)
  • com.provenance.savestate
  • com.provenance.cheat
- Standard archive/container formats → UTImportedTypeDeclarations
  • org.7-zip.7-zip-archive (.7z)
  • com.rarlab.rar-archive (.rar)
  • public.zip-archive (.zip)
  • public.iso-image (.iso)

The per-system hierarchy lets QuickLook, Spotlight, File Provider, and "Open With"
discover all supported ROM types via the com.provenance.rom parent.
"""

import plistlib
import argparse
import sys
from pathlib import Path
from collections import defaultdict

# ── Configuration ──────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).parent.parent
SYSTEMS_PLIST = REPO_ROOT / "PVLibrary/Sources/PVLibrary/Resources/systems.plist"
REFERENCE_URL = "https://provenance-emu.com/"
MIME_BASE = "application/x-provenance-"

# Map system identifiers from systems.plist → (uti_suffix, display_name)
# Systems not in this map get added to the base com.provenance.rom type.
SYSTEM_UTI_MAP = {
    "com.provenance.2600":         ("atari2600",    "Atari 2600"),
    "com.provenance.5200":         ("atari5200",    "Atari 5200"),
    "com.provenance.7800":         ("atari7800",    "Atari 7800"),
    "com.provenance.lynx":         ("lynx",         "Atari Lynx"),
    "com.provenance.jaguar":       ("jaguar",       "Atari Jaguar"),
    "com.provenance.jaguarcd":     ("jaguarcd",     "Atari Jaguar CD"),
    "com.provenance.atarist":      ("atarist",      "Atari ST"),
    "com.provenance.atari8bit":    ("atari8bit",    "Atari 8-bit"),
    "com.provenance.nes":          ("nes",          "Nintendo Entertainment System"),
    "com.provenance.fds":          ("fds",          "Famicom Disk System"),
    "com.provenance.snes":         ("snes",         "Super Nintendo"),
    "com.provenance.gb":           ("gb",           "Game Boy"),
    "com.provenance.gbc":          ("gbc",          "Game Boy Color"),
    "com.provenance.gba":          ("gba",          "Game Boy Advance"),
    "com.provenance.n64":          ("n64",          "Nintendo 64"),
    "com.provenance.ds":           ("ds",           "Nintendo DS"),
    "com.provenance.3ds":          ("3ds",          "Nintendo 3DS"),
    "com.provenance.gamecube":     ("gamecube",     "GameCube"),
    "com.provenance.wii":          ("wii",          "Wii"),
    "com.provenance.genesis":      ("genesis",      "Sega Genesis / Mega Drive"),
    "com.provenance.mastersystem": ("mastersystem", "Sega Master System"),
    "com.provenance.gamegear":     ("gamegear",     "Game Gear"),
    "com.provenance.32X":          ("sega32x",      "Sega 32X"),
    "com.provenance.segacd":       ("segacd",       "Sega CD"),
    "com.provenance.saturn":       ("saturn",       "Sega Saturn"),
    "com.provenance.dreamcast":    ("dreamcast",    "Dreamcast"),
    "com.provenance.sg1000":       ("sg1000",       "SG-1000"),
    "com.provenance.psx":          ("psx",          "PlayStation"),
    "com.provenance.ps2":          ("ps2",          "PlayStation 2"),
    "com.provenance.ps3":          ("ps3",          "PlayStation 3"),
    "com.provenance.psp":          ("psp",          "PlayStation Portable"),
    "com.provenance.3DO":          ("3do",          "3DO"),
    "com.provenance.pce":          ("pce",          "TurboGrafx-16 / PC Engine"),
    "com.provenance.pcecd":        ("pcecd",        "TurboGrafx-CD"),
    "com.provenance.sgfx":         ("sgfx",         "SuperGrafx"),
    "com.provenance.pcfx":         ("pcfx",         "PC-FX"),
    "com.provenance.ngp":          ("ngp",          "Neo Geo Pocket"),
    "com.provenance.ngpc":         ("ngpc",         "Neo Geo Pocket Color"),
    "com.provenance.neogeo":       ("neogeo",       "Neo Geo"),
    "com.provenance.ws":           ("ws",           "WonderSwan"),
    "com.provenance.wsc":          ("wsc",          "WonderSwan Color"),
    "com.provenance.vb":           ("vb",           "Virtual Boy"),
    "com.provenance.pokemonmini":  ("pokemonmini",  "Pokémon mini"),
    "com.provenance.msx":          ("msx",          "MSX"),
    "com.provenance.msx2":         ("msx2",         "MSX2"),
    "com.provenance.colecovision": ("colecovision", "ColecoVision"),
    "com.provenance.intellivision":("intellivision","Intellivision"),
    "com.provenance.odyssey2":     ("odyssey2",     "Odyssey2 / Videopac"),
    "com.provenance.c64":          ("c64",          "Commodore 64"),
    "com.provenance.dos":          ("dos",          "DOS"),
    "com.provenance.macintosh":    ("macintosh",    "Classic Mac"),
    "com.provenance.appleII":      ("appleii",      "Apple II"),
    "com.provenance.ep128":        ("ep128",        "Enterprise 128"),
    "com.provenance.zxspectrum":   ("zxspectrum",   "ZX Spectrum"),
    "com.provenance.vectrex":      ("vectrex",      "Vectrex"),
    "com.provenance.supervision":  ("supervision",  "Supervision"),
    "com.provenance.tic80":        ("tic80",        "TIC-80"),
    "com.provenance.cdi":          ("cdi",          "Philips CD-i"),
    "com.provenance.palmos":       ("palmos",       "Palm OS"),
    "com.provenance.mame":         ("mame",         "MAME"),
    "com.provenance.cps1":         ("cps1",         "CPS-1"),
    "com.provenance.cps2":         ("cps2",         "CPS-2"),
    "com.provenance.cps3":         ("cps3",         "CPS-3"),
    "com.provenance.music":        ("music",        "Game Music"),
    "com.provenance.doom":         ("doom",         "Doom"),
    "com.provenance.quake":        ("quake",        "Quake"),
    "com.provenance.quake2":       ("quake2",       "Quake II"),
    "com.provenance.wolf3d":       ("wolf3d",       "Wolfenstein 3D"),
    "com.provenance.pc98":         ("pc98",         "NEC PC-98"),
    "com.provenance.retroarch":    ("retroarch",    "RetroArch"),
}

# Extensions claimed by standard system UTIs — we import these rather than export.
# We can still HANDLE them, but another app "owns" the type definition.
STANDARD_ARCHIVE_UTIS = {
    "7z":  ("org.7-zip.7-zip-archive",     "7-Zip Archive"),
    "rar": ("com.rarlab.rar-archive",       "RAR Archive"),
    "zip": ("public.zip-archive",           "Zip Archive"),
    "iso": ("public.iso-image",             "ISO Disc Image"),
}

# Extensions that are generic enough to stay on the base rom type
# (shared by many systems, not uniquely identifying any one system)
BASE_ROM_EXTENSIONS = [
    "rom", "ROM",
    "bin",
    "cue", "toc", "ccd",
    "chd",
    "m3u", "m3u8",
    "bios",
    "elf",
    "dol",
    "img",
    "mdf", "mds",
    "nrg",
    "ciso",
    "gcz",
    "isz",
    "gz",
    "lzh",
]

# ── Core logic ─────────────────────────────────────────────────────────────────

def load_systems(plist_path: Path) -> list:
    with open(plist_path, "rb") as f:
        return plistlib.load(f)


def build_system_extension_map(systems: list) -> dict:
    """Returns {system_id: [lowercased extensions]}"""
    result = {}
    for s in systems:
        sid = s.get("PVSystemIdentifier", "")
        exts = sorted(set(e.lower() for e in s.get("PVSupportedExtensions", [])))
        result[sid] = exts
    return result


def make_exported_type(uti_id: str, description: str, conforms_to: list,
                       extensions: list, mime_type: str) -> dict:
    """Build a UTExportedTypeDeclarations dict entry."""
    return {
        "UTTypeConformsTo": conforms_to,
        "UTTypeDescription": description,
        "UTTypeIconFiles": [],
        "UTTypeIdentifier": uti_id,
        "UTTypeReferenceURL": REFERENCE_URL,
        "UTTypeTagSpecification": {
            "public.filename-extension": extensions,
            "public.mime-type": [mime_type],
        },
    }


def make_imported_type(uti_id: str, description: str, conforms_to: list,
                       extensions: list) -> dict:
    """Build a UTImportedTypeDeclarations dict entry."""
    return {
        "UTTypeConformsTo": conforms_to,
        "UTTypeDescription": description,
        "UTTypeIconFiles": [],
        "UTTypeIdentifier": uti_id,
        "UTTypeReferenceURL": REFERENCE_URL,
        "UTTypeTagSpecification": {
            "public.filename-extension": extensions,
        },
    }


def generate_declarations(systems_plist: Path = SYSTEMS_PLIST):
    systems = load_systems(systems_plist)
    system_ext_map = build_system_extension_map(systems)

    exported = []
    imported_archives = []

    # Track which extensions are claimed by per-system types (avoid duplication)
    system_claimed_exts: set = set()

    # ── 1. Per-system UTI entries ─────────────────────────────────────────────
    per_system_entries = []
    for sid, exts in sorted(system_ext_map.items()):
        uti_info = SYSTEM_UTI_MAP.get(sid)
        if not uti_info:
            # Unknown system — extensions go into base type
            continue

        suffix, display_name = uti_info
        uti_id = f"com.provenance.rom.{suffix}"

        # Filter out generic/archive extensions from the per-system type
        # (they'll live on the base type or be imported)
        system_specific = [
            e for e in exts
            if e not in STANDARD_ARCHIVE_UTIS
            and e not in ("zip", "rar", "7z", "iso")  # archives handled separately
        ]
        # Deduplicate: track all non-archive extensions claimed by any system
        for e in system_specific:
            system_claimed_exts.add(e)

        if system_specific:
            entry = make_exported_type(
                uti_id=uti_id,
                description=f"{display_name} ROM",
                conforms_to=["com.provenance.rom"],
                extensions=system_specific,
                mime_type=f"{MIME_BASE}{suffix}-rom",
            )
            per_system_entries.append(entry)

    # ── 2. Base ROM type ──────────────────────────────────────────────────────
    # Includes generic extensions not owned by any specific system
    all_system_exts: set = set()
    for exts in system_ext_map.values():
        all_system_exts.update(exts)

    base_exts_raw = sorted(
        all_system_exts
        - set(STANDARD_ARCHIVE_UTIS.keys())
        - {"zip", "rar", "7z", "iso"}
    )
    # Keep only extensions that aren't already in a per-system type,
    # plus the explicitly listed base extensions
    base_extra = sorted(
        set(BASE_ROM_EXTENSIONS)
        | (all_system_exts - system_claimed_exts
           - set(STANDARD_ARCHIVE_UTIS.keys())
           - {"zip", "rar", "7z", "iso"})
    )
    # Remove duplicates and sort (case-insensitive)
    seen = set()
    base_exts_final = []
    for e in sorted(set(BASE_ROM_EXTENSIONS) | (all_system_exts - system_claimed_exts
                                                  - set(STANDARD_ARCHIVE_UTIS.keys())
                                                  - {"zip", "rar", "7z", "iso"}),
                    key=lambda x: x.lower()):
        if e.lower() not in seen:
            seen.add(e.lower())
            base_exts_final.append(e)

    base_rom = make_exported_type(
        uti_id="com.provenance.rom",
        description="ROM file",
        conforms_to=["public.data"],
        extensions=sorted(base_exts_final, key=lambda x: x.lower()),
        mime_type=f"{MIME_BASE}rom",
    )
    exported.append(base_rom)
    exported.extend(per_system_entries)

    # ── 3. Save State (exported — Provenance owns this format) ───────────────
    exported.append(make_exported_type(
        uti_id="com.provenance.savestate",
        description="Provenance Save State",
        conforms_to=["public.data"],
        extensions=["svs"],
        mime_type=f"{MIME_BASE}savestate",
    ))

    # ── 4. Cheat codes ────────────────────────────────────────────────────────
    exported.append(make_exported_type(
        uti_id="com.provenance.cheat",
        description="Provenance Cheat Code",
        conforms_to=["public.data"],
        extensions=["pvc"],
        mime_type=f"{MIME_BASE}cheat",
    ))

    # ── 5. Artwork ────────────────────────────────────────────────────────────
    exported.append(make_exported_type(
        uti_id="com.provenance.artwork",
        description="Provenance Game Artwork",
        conforms_to=["public.image"],
        extensions=["jpg", "jpeg", "png", "gif", "webp"],
        mime_type="image/jpeg",
    ))

    # ── 6. Imported archive types ─────────────────────────────────────────────
    imported_archives.append(make_imported_type(
        uti_id="org.7-zip.7-zip-archive",
        description="7-Zip Archive",
        conforms_to=["public.archive", "public.data"],
        extensions=["7z"],
    ))
    imported_archives.append(make_imported_type(
        uti_id="com.rarlab.rar-archive",
        description="RAR Archive",
        conforms_to=["public.archive", "public.data"],
        extensions=["rar"],
    ))
    imported_archives.append(make_imported_type(
        uti_id="public.zip-archive",
        description="Zip Archive",
        conforms_to=["public.archive", "public.data"],
        extensions=["zip"],
    ))
    imported_archives.append(make_imported_type(
        uti_id="public.iso-image",
        description="ISO Disc Image",
        conforms_to=["public.disk-image", "public.data"],
        extensions=["iso"],
    ))

    return exported, imported_archives


def build_document_types() -> list:
    """
    CFBundleDocumentTypes — the types Provenance will open from "Open With".
    The base com.provenance.rom covers all sub-types via conformance.
    """
    return [
        {
            "CFBundleTypeIconFiles": [],
            "CFBundleTypeName": "ROM",
            "LSHandlerRank": "Owner",
            "LSItemContentTypes": [
                "com.provenance.rom",
                # Archive / generic formats handled via import
                "org.7-zip.7-zip-archive",
                "com.rarlab.rar-archive",
                "public.zip-archive",
                "public.iso-image",
            ],
        },
        {
            "CFBundleTypeIconFiles": [],
            "CFBundleTypeName": "Save State",
            "LSHandlerRank": "Owner",
            "LSItemContentTypes": ["com.provenance.savestate"],
        },
        {
            "CFBundleTypeIconFiles": [],
            "CFBundleTypeName": "Artwork",
            "LSHandlerRank": "Alternate",
            "LSItemContentTypes": [
                "public.image",
                "public.jpeg",
                "public.png",
                "com.compuserve.gif",
            ],
        },
    ]


def update_plist(plist_path: Path, exported: list, imported: list):
    """Update a target Info.plist with generated UTI declarations."""
    with open(plist_path, "rb") as f:
        plist = plistlib.load(f)

    plist["UTExportedTypeDeclarations"] = exported
    plist["UTImportedTypeDeclarations"] = imported
    plist["CFBundleDocumentTypes"] = build_document_types()

    with open(plist_path, "wb") as f:
        plistlib.dump(plist, f, fmt=plistlib.FMT_XML, sort_keys=True)

    print(f"  Updated {plist_path}")


def print_summary(exported: list, imported: list):
    print(f"\n=== UTI Generation Summary ===")
    print(f"Exported types: {len(exported)}")
    print(f"  Base + system types: {len([e for e in exported if 'rom' in e['UTTypeIdentifier']])}")
    all_exts = set()
    for e in exported:
        all_exts.update(e["UTTypeTagSpecification"].get("public.filename-extension", []))
    for i in imported:
        all_exts.update(i["UTTypeTagSpecification"].get("public.filename-extension", []))
    print(f"  Total extensions covered: {len(all_exts)}")
    print(f"Imported types: {len(imported)}")
    print(f"\nPer-system types:")
    for e in exported:
        if e["UTTypeIdentifier"].startswith("com.provenance.rom."):
            exts = e["UTTypeTagSpecification"].get("public.filename-extension", [])
            print(f"  {e['UTTypeIdentifier']}: {exts}")


def main():
    parser = argparse.ArgumentParser(
        description="Generate UTI declarations from systems.plist"
    )
    parser.add_argument(
        "--update-plist",
        metavar="INFO_PLIST",
        nargs="+",
        help="Info.plist file(s) to update in-place",
    )
    parser.add_argument(
        "--systems-plist",
        default=str(SYSTEMS_PLIST),
        help=f"Path to systems.plist (default: {SYSTEMS_PLIST})",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print summary without writing any files",
    )
    args = parser.parse_args()

    systems_plist_path = Path(args.systems_plist)
    if not systems_plist_path.exists():
        print(f"Error: systems.plist not found at {systems_plist_path}", file=sys.stderr)
        sys.exit(1)

    exported, imported = generate_declarations(systems_plist_path)
    print_summary(exported, imported)

    if args.dry_run or not args.update_plist:
        print("\n(dry run — no files written)")
        return

    print("\nUpdating Info.plist files:")
    for plist_path_str in args.update_plist:
        p = Path(plist_path_str)
        if not p.exists():
            print(f"  Warning: {p} not found, skipping", file=sys.stderr)
            continue
        update_plist(p, exported, imported)

    print("\nDone. Remember to run 'swiftlint lint' on any changed Swift files.")


if __name__ == "__main__":
    main()
