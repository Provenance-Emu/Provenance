#!/usr/bin/env python3
"""
generate_uti_declarations.py — Provenance UTI/MIME Registration Generator

Reads systems.plist and outputs UTExportedTypeDeclarations + UTImportedTypeDeclarations
for embedding in iOS/tvOS Info.plist files.

Usage:
    python3 Scripts/generators/generate_uti_declarations.py
    python3 Scripts/generators/generate_uti_declarations.py --update-plist Provenance/Provenance-Info.plist
    python3 Scripts/generators/generate_uti_declarations.py --check Provenance/Provenance-Info.plist

--update-plist MERGES into the plist: it adds/refreshes only the declarations it
generates and leaves every other declaration (save bundles, skins, BIOS, ...)
untouched; --check exits 1 if any plist would change. See "Merging into an
existing Info.plist" below for the exact rule.

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

import argparse
import copy
import plistlib
import re
import sys
from pathlib import Path
from collections import defaultdict

# ── Configuration ──────────────────────────────────────────────────────────────

REPO_ROOT = Path(__file__).resolve().parents[2]
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


# ── Merging into an existing Info.plist ────────────────────────────────────────
#
# The Info.plists carry many declarations this script does not generate (save
# bundles, skins, RetroArch configs, BIOS, ...). --update-plist therefore MERGES:
#
#   * "Generator-owned" UTIs are exactly the identifiers generate_declarations()
#     emits (com.provenance.rom, com.provenance.rom.<system>, savestate, cheat,
#     artwork, and the imported archive types). Missing ones are added; existing
#     ones are topped up (see merge_declaration) -- never trimmed or reordered.
#   * Every other declaration is left byte-for-byte untouched, in place.
#   * CFBundleDocumentTypes are merged by CFBundleTypeName the same way.
#
# The file is edited as text, not re-dumped through plistlib, because a plistlib
# round trip would drop XML comments, rewrite &apos; escapes and reorder keys in
# unrelated parts of the plist. Only the changed or added <dict> elements are
# re-rendered (plistlib, sort_keys=True, tab indented, like the files).

EXPORTED_KEY = "UTExportedTypeDeclarations"
IMPORTED_KEY = "UTImportedTypeDeclarations"
DOCTYPES_KEY = "CFBundleDocumentTypes"
FILENAME_EXT_KEY = "public.filename-extension"
SYSTEM_UTI_PREFIX = "com.provenance.rom."

_PLIST_OPEN = '<plist version="1.0">'
_XML_HEADER = '<?xml version="1.0" encoding="UTF-8"?>\n' + _PLIST_OPEN + "\n"
_TAG_RE = re.compile(r"<!--.*?-->|<(/?)(dict|array)(/?)>", re.DOTALL)


def _union(existing: list, wanted: list) -> list:
    """existing + any item of wanted not already present (order preserved)."""
    return list(existing) + [x for x in wanted if x not in existing]


def merge_declaration(existing: dict, generated: dict) -> dict:
    """
    Merge a generated UT*TypeDeclarations entry into the one already in the plist.
    Additive only: the description is refreshed, lists (conformance, extensions,
    MIME types) gain what is missing, and nothing the plist already has is removed
    (hand-added extensions such as .rvz on the base ROM type survive).
    """
    merged = copy.deepcopy(existing)
    merged["UTTypeDescription"] = generated["UTTypeDescription"]
    merged["UTTypeConformsTo"] = _union(merged.get("UTTypeConformsTo", []),
                                        generated["UTTypeConformsTo"])
    for field in ("UTTypeIconFiles", "UTTypeReferenceURL"):
        if field in generated:
            merged.setdefault(field, copy.deepcopy(generated[field]))
    spec = merged.setdefault("UTTypeTagSpecification", {})
    for tag, wanted in generated.get("UTTypeTagSpecification", {}).items():
        spec[tag] = _union(spec.get(tag, []), wanted)
    return merged


def merge_document_type(existing: dict, generated: dict) -> dict:
    """Additive merge of a CFBundleDocumentTypes entry (matched by name)."""
    merged = copy.deepcopy(existing)
    for field, value in generated.items():
        if field == "LSItemContentTypes":
            merged[field] = _union(merged.get(field, []), value)
        else:
            merged.setdefault(field, copy.deepcopy(value))
    return merged


def _find_array(text: str, key: str):
    """Span (start, end) of the <array> element following <key>key</key>, or None."""
    m = re.search(rf"<key>{re.escape(key)}</key>\s*", text)
    if not m:
        return None
    start = m.end()
    if text.startswith("<array/>", start):
        return start, start + len("<array/>")
    if not text.startswith("<array>", start):
        return None
    depth = 0
    for tag in _TAG_RE.finditer(text, start):
        if tag.group(2) is None:  # comment
            continue
        closing, name, selfclosing = tag.group(1), tag.group(2), tag.group(3)
        if selfclosing:
            continue
        depth += -1 if closing else 1
        if depth == 0 and name == "array":
            return start, tag.end()
    raise ValueError(f"unterminated <array> for key {key}")


def _split_children(text: str, span) -> list:
    """Spans of the direct <dict> children of the array occupying `span`."""
    start, end = span
    children, depth, child_start = [], 0, None
    for tag in _TAG_RE.finditer(text, start, end):
        if tag.group(2) is None:
            continue
        closing, name, selfclosing = tag.group(1), tag.group(2), tag.group(3)
        if selfclosing:
            if depth == 1 and name == "dict":
                children.append((tag.start(), tag.end()))
            continue
        if closing:
            depth -= 1
            if depth == 1 and name == "dict":
                children.append((child_start, tag.end()))
        else:
            depth += 1
            if depth == 2 and name == "dict":
                child_start = tag.start()
    return children


def _parse_fragment(fragment: str):
    return plistlib.loads((_XML_HEADER + fragment + "\n</plist>\n").encode("utf-8"))


def _render(value, indent: str) -> str:
    """Render a plist value as XML, every line prefixed with `indent`."""
    body = plistlib.dumps(value, fmt=plistlib.FMT_XML, sort_keys=True).decode("utf-8")
    body = body[body.index(_PLIST_OPEN) + len(_PLIST_OPEN) + 1:]
    body = body[:body.rindex("</plist>")].rstrip("\n")
    return "\n".join(indent + line for line in body.split("\n"))


def _line_indent(text: str, pos: int) -> str:
    """Leading whitespace of the line containing `pos` (empty if pos is mid-line)."""
    line_start = text.rfind("\n", 0, pos) + 1
    prefix = text[line_start:pos]
    return prefix if not prefix.strip() else ""


def merge_array_text(text: str, key: str, generated: list, id_field: str, merge_fn) -> str:
    """
    Merge `generated` (dicts identified by id_field) into the array stored under
    `key`, editing only the changed or added elements. Returns the new text.
    """
    span = _find_array(text, key)
    if span is None:
        # Key absent: append a fresh array at the end of the root dict.
        wrapper = _render({key: generated}, "").split("\n")
        root_end = text.rindex("</dict>")
        return text[:root_end] + "\n".join(wrapper[1:-1]) + "\n" + text[root_end:]

    children = _split_children(text, span)
    existing = [_parse_fragment(text[s:e]) for s, e in children]
    by_id = {d.get(id_field): i for i, d in enumerate(existing)}
    indent = _line_indent(text, children[0][0]) if children else "\t\t"

    edits = []  # (start, end, replacement)
    additions = []
    for gen in generated:
        idx = by_id.get(gen[id_field])
        if idx is None:
            additions.append(_render(gen, indent))
            continue
        merged = merge_fn(existing[idx], gen)
        if merged != existing[idx]:
            s, e = children[idx]
            edits.append((s, e, _render(merged, indent).lstrip()))

    if additions:
        owned = [by_id[g[id_field]] for g in generated if g[id_field] in by_id]
        if children:
            # After the last existing generator-owned entry, else at the end.
            anchor = children[max(owned) if owned else -1][1]
            edits.append((anchor, anchor, "\n" + "\n".join(additions)))
        else:
            s, e = span
            outer = _line_indent(text, text.rfind("<key>", 0, s))
            edits.append((s, e, "<array>\n" + "\n".join(additions) + "\n" + outer + "</array>"))

    for s, e, repl in sorted(edits, key=lambda edit: edit[0], reverse=True):
        text = text[:s] + repl + text[e:]
    return text


def stale_system_utis(text: str, generated_exported: list) -> list:
    """com.provenance.rom.* exported UTIs in the plist that no system generates any more."""
    span = _find_array(text, EXPORTED_KEY)
    if span is None:
        return []
    current = {g["UTTypeIdentifier"] for g in generated_exported}
    found = []
    for s, e in _split_children(text, span):
        ident = _parse_fragment(text[s:e]).get("UTTypeIdentifier", "")
        if ident.startswith(SYSTEM_UTI_PREFIX) and ident not in current:
            found.append(ident)
    return found


def merge_plist_text(text: str, exported: list, imported: list, doc_types: list) -> str:
    text = merge_array_text(text, EXPORTED_KEY, exported, "UTTypeIdentifier", merge_declaration)
    text = merge_array_text(text, IMPORTED_KEY, imported, "UTTypeIdentifier", merge_declaration)
    return merge_array_text(text, DOCTYPES_KEY, doc_types, "CFBundleTypeName", merge_document_type)


def update_plist(plist_path: Path, exported: list, imported: list,
                 check_only: bool = False, report_stale: bool = False) -> bool:
    """
    Merge the generated declarations into an Info.plist. Returns True when the file
    changed (or, with check_only, would change). Nothing is written in check mode.
    """
    original = plist_path.read_text(encoding="utf-8")
    updated = merge_plist_text(original, exported, imported, build_document_types())
    plistlib.loads(updated.encode("utf-8"))  # never write something that is not a valid plist
    changed = updated != original

    if report_stale:
        for ident in stale_system_utis(original, exported):
            print(f"  {plist_path}: stale {ident} (no matching system; left in place)")

    if changed and not check_only:
        plist_path.write_text(updated, encoding="utf-8")
    verb = "Would update" if check_only else "Updated"
    print(f"  {verb if changed else 'Unchanged'} {plist_path}")
    return changed


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


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Generate UTI declarations from systems.plist"
    )
    parser.add_argument(
        "--update-plist",
        metavar="INFO_PLIST",
        nargs="+",
        help="Info.plist file(s) to merge the generated declarations into, in place",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="With --update-plist: write nothing; list the plists that would change and "
             "exit 1 if there are any (exit 0 when all are current)",
    )
    parser.add_argument(
        "--prune",
        action="store_true",
        help="With --update-plist: also REPORT com.provenance.rom.* types in a plist that "
             "no system generates any more. Report only; nothing is ever deleted",
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
    args = parser.parse_args(argv)

    if args.check and not args.update_plist:
        parser.error("--check needs --update-plist <Info.plist...>")

    systems_plist_path = Path(args.systems_plist)
    if not systems_plist_path.exists():
        print(f"Error: systems.plist not found at {systems_plist_path}", file=sys.stderr)
        return 2

    exported, imported = generate_declarations(systems_plist_path)
    if not args.check:
        print_summary(exported, imported)

    if (args.dry_run or not args.update_plist) and not args.check:
        print("\n(dry run — no files written)")
        return 0

    check_only = args.check or args.dry_run
    print("\nChecking Info.plist files:" if check_only else "\nUpdating Info.plist files:")
    stale, missing = 0, 0
    for plist_path_str in args.update_plist:
        p = Path(plist_path_str)
        if not p.exists():
            print(f"  Warning: {p} not found, skipping", file=sys.stderr)
            missing += 1
            continue
        if update_plist(p, exported, imported, check_only=check_only, report_stale=args.prune):
            stale += 1

    if args.check:
        if missing:
            print(f"{missing} plist(s) not found")
            return 2
        if stale:
            print(f"{stale} of {len(args.update_plist)} Info.plist(s) out of date with systems.plist")
            return 1
        print("All Info.plist file-type declarations are current")
    return 0


if __name__ == "__main__":
    sys.exit(main())
