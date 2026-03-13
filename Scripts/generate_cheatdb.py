#!/usr/bin/env python3
"""
generate_cheatdb.py — Convert libretro .cht cheat files to SQLite database.

Parses the libretro-database cht/ directory structure and produces a
libretro_cheats.sqlite database for Provenance's cheat code lookup.

Usage:
    python3 Scripts/generate_cheatdb.py /path/to/libretro-database/cht/ \
        --output PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite

    # With MD5 cross-reference (recommended):
    python3 Scripts/generate_cheatdb.py /path/to/libretro-database/cht/ \
        --dat-dir /path/to/libretro-database \
        --output PVLookup/Sources/LibretroCheatDB/Resources/libretro_cheats.sqlite

The cht/ directory has the structure:
    cht/
      Nintendo - Game Boy Advance/
        Super Mario Advance (USA).cht
        Super Mario Advance (USA) (Action Replay).cht
      Sega - Mega Drive - Genesis/
        Sonic the Hedgehog (USA, Europe).cht
      ...

Each .cht file is INI-style:
    cheats = 3
    cheat0_desc = "Infinite Lives"
    cheat0_code = "01FF00C5"
    cheat0_enable = false
    cheat1_desc = ...

MD5 cross-reference uses CLRMamePro DAT files (from metadat/no-intro/,
metadat/redump/, and dat/) to add ROM MD5 hashes to each game entry.
"""

import argparse
import os
import re
import sqlite3
import zipfile
import sys
from pathlib import Path


# Map libretro cht/ directory names to short system names.
# These must match SystemIdentifier.libretroCheatSystemName in Provenance
# (which may differ from libretroDatabaseName used for thumbnail URLs —
# e.g. DOOM cheats use "PrBoom" but thumbnails use "DOOM").
SYSTEM_SHORT_NAMES = {
    "Atari - 2600": "2600",
    "Atari - 5200": "5200",
    "Atari - 7800": "7800",
    "Atari - 8-bit Family": "Atari8bit",
    "Atari - Jaguar": "Jaguar",
    "Atari - Jaguar CD": "JaguarCD",
    "Atari - Lynx": "Lynx",
    "Atari - ST": "AtariST",
    "Bandai - WonderSwan": "WonderSwan",
    "Bandai - WonderSwan Color": "WonderSwanColor",
    "Coleco - ColecoVision": "ColecoVision",
    "Commodore - C64": "C64",
    "DOS": "DOS",
    "GCE - Vectrex": "Vectrex",
    "Magnavox - Odyssey2": "Odyssey2",
    "Mattel - Intellivision": "Intellivision",
    # MSX and MSX2 are consolidated into one directory in the libretro cheat DB.
    # Both systems share the same cheats folder; MSX2 games are a superset of MSX.
    "Microsoft - MSX - MSX2 - MSX2P - MSX Turbo R": "MSX",
    "Microsoft - MSX - MSX2 - MSX2P - MSX Turbo R (fMSX core)": "MSX",
    "NEC - PC Engine - TurboGrafx 16": "PCE",
    "NEC - PC Engine CD - TurboGrafx-CD": "PCECD",
    "NEC - PC Engine SuperGrafx": "SGFX",
    "NEC - PC-FX": "PCFX",
    "Nintendo - Family Computer Disk System": "FDS",
    "Nintendo - Game Boy": "GB",
    "Nintendo - Game Boy Advance": "GBA",
    "Nintendo - Game Boy Color": "GBC",
    "Nintendo - GameCube": "GameCube",
    "Nintendo - Nintendo 64": "N64",
    # N64-based hardware variants — map to the base N64 system.
    "Nintendo - Nintendo 64 (Aleck64)": "N64",
    "Nintendo - Nintendo 64 (iQue)": "N64",
    "Nintendo - Nintendo 64 (Unreleased)": "N64",
    "Nintendo - Nintendo DS": "DS",
    "Nintendo - Nintendo Entertainment System": "NES",
    "Nintendo - Pokemon Mini": "PokemonMini",
    # Satellaview is a SNES peripheral; map its cheats to the SNES system.
    "Nintendo - Satellaview": "SNES",
    "Nintendo - Super Nintendo Entertainment System": "SNES",
    "Nintendo - Virtual Boy": "VirtualBoy",
    "Nintendo - Wii": "Wii",
    "Nintendo - Nintendo 3DS": "3DS",
    # PrBoom runs Doom WADs; map to the DOOM system identifier.
    "PrBoom": "DOOM",
    # Wolfenstein 3D engine cheats.
    "Wolfenstein 3D": "Wolf3D",
    "Sega - 32X": "Sega32X",
    "Sega - Dreamcast": "Dreamcast",
    "Sega - Game Gear": "GameGear",
    "Sega - Master System - Mark III": "MasterSystem",
    "Sega - Mega Drive - Genesis": "Genesis",
    "Sega - Mega-CD - Sega CD": "SegaCD",
    "Sega - SG-1000": "SG1000",
    "Sega - Saturn": "Saturn",
    # Both ZX Spectrum variants map to the same Provenance system.
    "Sinclair - ZX Spectrum": "ZXSpectrum",
    "Sinclair - ZX Spectrum +3": "ZXSpectrum",
    "SNK - Neo Geo": "NeoGeo",
    "SNK - Neo Geo Pocket": "NGP",
    "SNK - Neo Geo Pocket Color": "NGPC",
    "Sony - PlayStation": "PSX",
    "Sony - PlayStation 2": "PS2",
    "Sony - PlayStation Portable": "PSP",
    "The 3DO Company - 3DO": "3DO",
    "TIC-80": "TIC80",
    # FBNeo (FinalBurn Neo) is the libretro arcade core; maps to Provenance's MAME system.
    "FBNeo - Arcade Games": "MAME",
    "Watara - Supervision": "Supervision",
    "Philips - CD-i": "CDi",
}

# Libretro cht/ directories intentionally NOT mapped (Provenance does not support them):
#   "Amstrad - GX4000"     — Amstrad GX4000 console; no Provenance core
#   "ChaiLove"             — Scripting/game engine, not a hardware system
#   "PuzzleScript"         — Scripting/game engine, not a hardware system
#   "Thomson - MOTO"       — Thomson MO/TO home computers; no Provenance core

# Regex to extract region from filename like "Game Name (USA)" or "Game (USA, Europe)"
REGION_RE = re.compile(r"\(([^)]*(?:USA|Europe|Japan|World|Korea|France|Germany|Spain|Italy|Brazil|Australia|Asia|China|Taiwan)[^)]*)\)")

# Regex to detect device name suffixes like "(Action Replay)" or "(Game Genie)"
DEVICE_SUFFIXES = [
    "Action Replay",
    "Game Genie",
    "GameShark",
    "Pro Action Replay",
    "Xploder",
    "Code Breaker",
    "CodeBreaker",
    "Codebreaker",
    "Goldfinger",
]
DEVICE_RE = re.compile(r"\((" + "|".join(re.escape(d) for d in DEVICE_SUFFIXES) + r")\)", re.IGNORECASE)

# CLRMamePro DAT parsing patterns
_DAT_GAME_NAME_RE = re.compile(r'^\s*name\s+"([^"]+)"', re.MULTILINE)
_DAT_ROM_MD5_RE = re.compile(r'rom\s*\([^)]*\bmd5\s+([0-9a-fA-F]{32})', re.IGNORECASE)
_DAT_ROM_NAME_RE = re.compile(r'rom\s*\([^)]*\bname\s+"([^"]+)"', re.IGNORECASE)


def parse_cht_file(filepath):
    """Parse a single .cht file and return a list of (desc, code, enable) tuples."""
    cheats = []
    data = {}

    try:
        with open(filepath, "r", encoding="utf-8", errors="replace") as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith("#"):
                    continue
                if "=" not in line:
                    continue
                key, _, value = line.partition("=")
                key = key.strip()
                value = value.strip().strip('"')
                data[key] = value
    except Exception as e:
        print(f"  Warning: Could not read {filepath}: {e}", file=sys.stderr)
        return cheats

    # Read number of cheats
    try:
        num_cheats = int(data.get("cheats", "0"))
    except ValueError:
        return cheats

    for i in range(num_cheats):
        desc = data.get(f"cheat{i}_desc", "").strip().strip('"')
        code = data.get(f"cheat{i}_code", "").strip().strip('"')
        if not desc and not code:
            continue
        if not desc:
            desc = f"Cheat {i + 1}"
        if not code:
            continue
        cheats.append((desc, code))

    return cheats


def extract_title_and_region(filename_stem):
    """Extract clean game title and region from filename stem.

    Example: "Super Mario World (USA)" -> ("Super Mario World", "USA")
    Example: "Sonic (USA, Europe) (Action Replay)" -> ("Sonic", "USA, Europe")
    """
    name = filename_stem

    # Remove device suffix first
    name = DEVICE_RE.sub("", name).strip()

    # Extract region
    region_match = REGION_RE.search(name)
    region = region_match.group(1) if region_match else None

    # Remove all parenthetical groups to get clean title
    clean = re.sub(r"\s*\([^)]*\)", "", name).strip()

    return clean, region


def extract_device_name(filename_stem):
    """Extract device name from filename suffix, default to 'RetroArch'."""
    match = DEVICE_RE.search(filename_stem)
    return match.group(1) if match else "RetroArch"


def _stem_without_device(filename_stem):
    """Return the cht stem with device suffix removed (for DAT lookup)."""
    return DEVICE_RE.sub("", filename_stem).strip()


# Format detection patterns, evaluated in order.
# Each entry: (compiled_regex, format_string)
_FORMAT_PATTERNS = [
    # Game Genie SNES/NES: XXXX-XXXX-XXXX (letters+digits, dash-separated triples)
    (re.compile(r'^[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}$'), "Game Genie (SNES/NES)"),
    # Game Genie GB/GBA short: AAAA:DDDD (4-hex colon 4-hex)
    (re.compile(r'^[0-9A-Fa-f]{4}:[0-9A-Fa-f]{4}$'), "Game Genie"),
    # GameShark GBA-style: 0XXXXXXX YYYY (8 hex starting with 0, space, 4 hex)
    (re.compile(r'^0[0-9A-Fa-f]{7}\s+[0-9A-Fa-f]{4}$'), "GameShark GBA"),
    # Action Replay v2: XXXXXXXX:XXXXXXXX (8 hex colon 8 hex)
    (re.compile(r'^[0-9A-Fa-f]{8}:[0-9A-Fa-f]{8}$'), "Action Replay v2"),
    # GameShark: XXXXXXXX+XXXXXXXX (8 hex plus 8 hex)
    (re.compile(r'^[0-9A-Fa-f]{8}\+[0-9A-Fa-f]{8}$'), "GameShark"),
    # Raw AR/GS v3: XXXXXXXX XXXXXXXX (8 hex space 8 hex)
    (re.compile(r'^[0-9A-Fa-f]{8}\s+[0-9A-Fa-f]{8}$'), "Raw (AR/GS v3)"),
]

# Device name → format override (when filename already tells us the exact device)
_DEVICE_FORMAT_MAP = {
    "action replay": "Action Replay",
    "game genie": "Game Genie",
    "gameshark": "GameShark",
    "pro action replay": "Pro Action Replay",
    "xploder": "Xploder",
    "code breaker": "Code Breaker",
    "codebreaker": "Code Breaker",
    "goldfinger": "Gold Finger",
}


def detect_format(code, device_name):
    """Detect the cheat code format from the code string and device name.

    First checks device_name (extracted from filename suffix) for a direct match.
    Falls back to pattern matching on the code string.
    Returns a format string or None if no pattern matches.
    """
    # If the device name is specific (not the generic 'RetroArch'), use it directly.
    dn_lower = device_name.lower()
    if dn_lower != "retroarch":
        mapped = _DEVICE_FORMAT_MAP.get(dn_lower)
        if mapped:
            return mapped
        # Unknown named device — return the device name as-is
        return device_name

    # Pattern-match individual lines of the code (some codes are multi-line)
    lines = [ln.strip() for ln in code.splitlines() if ln.strip()]
    if not lines:
        return None

    # Use the first non-empty line for pattern detection
    first_line = lines[0]
    for pattern, fmt in _FORMAT_PATTERNS:
        if pattern.match(first_line):
            return fmt

    return None


def parse_dat_file(dat_path):
    """Parse a CLRMamePro DAT file and return a dict mapping game_name_stem -> md5.

    The DAT format is:
        game (
            name "Game Name (Region)"
            ...
            rom ( name "Game Name (Region).ext" size 12345 crc XXXXXXXX md5 YYYYYYYY sha1 ... )
        )

    Returns: {filename_stem: md5_lowercase}
    where filename_stem is the rom name without its extension.
    """
    result = {}

    try:
        # DAT files may contain non-UTF-8 bytes; use errors='replace'
        with open(dat_path, "r", encoding="utf-8", errors="replace") as f:
            content = f.read()
    except Exception as e:
        print(f"  Warning: Could not read DAT {dat_path}: {e}", file=sys.stderr)
        return result

    # Split on game-record boundaries to avoid cross-game matches
    # Each record starts with "game (" and ends with the matching ")"
    # Simple approach: split on game blocks
    game_block_re = re.compile(r'\bgame\s*\(', re.IGNORECASE)
    positions = [m.start() for m in game_block_re.finditer(content)]

    for i, start in enumerate(positions):
        end = positions[i + 1] if i + 1 < len(positions) else len(content)
        block = content[start:end]

        # Extract the rom entry's name and md5
        rom_md5_m = _DAT_ROM_MD5_RE.search(block)
        rom_name_m = _DAT_ROM_NAME_RE.search(block)

        if not rom_md5_m or not rom_name_m:
            continue

        md5 = rom_md5_m.group(1).lower()
        rom_filename = rom_name_m.group(1)  # e.g. "Game Name (USA).sfc"

        # Strip file extension to get the lookup stem
        stem = Path(rom_filename).stem  # e.g. "Game Name (USA)"
        result[stem] = md5

    return result


def build_md5_map(db_root):
    """Build a mapping from (system_name, file_title) -> md5 using DAT files.

    Scans metadat/no-intro/, metadat/redump/, and dat/ subdirectories of
    db_root for CLRMamePro DAT files. Matches them to cht system names by
    filename.

    Returns: {system_name: {file_title_stem: md5}}
    """
    if db_root is None:
        return {}

    db_root = Path(db_root)
    # Directories to search for DAT files, in priority order
    search_dirs = [
        db_root / "metadat" / "no-intro",
        db_root / "metadat" / "redump",
        db_root / "dat",
    ]

    # Build system_name -> dat_stem mapping for the systems we care about
    # A DAT file named "Nintendo - Game Boy.dat" matches system "Nintendo - Game Boy"
    system_to_stems: dict[str, dict] = {}

    for search_dir in search_dirs:
        if not search_dir.exists():
            continue
        for dat_file in sorted(search_dir.glob("*.dat")):
            dat_stem = dat_file.stem  # e.g. "Nintendo - Game Boy"
            # Check if this matches any of our known system names
            if dat_stem not in SYSTEM_SHORT_NAMES:
                continue
            system_name = dat_stem
            if system_name not in system_to_stems:
                print(f"  Loading MD5 map: {dat_file.name} ({system_name})")
                system_to_stems[system_name] = parse_dat_file(dat_file)
            # If already loaded from a higher-priority dir, skip lower-priority

    total_md5 = sum(len(v) for v in system_to_stems.values())
    if total_md5 > 0:
        print(f"  MD5 map: {total_md5} entries across {len(system_to_stems)} systems")

    return system_to_stems


def create_database(db_path):
    """Create the SQLite database with the cheat schema."""
    conn = sqlite3.connect(db_path)
    c = conn.cursor()

    c.executescript("""
        DROP TABLE IF EXISTS cheats;
        DROP TABLE IF EXISTS games;
        DROP TABLE IF EXISTS systems;

        CREATE TABLE systems (
            system_id INTEGER PRIMARY KEY AUTOINCREMENT,
            system_name TEXT NOT NULL UNIQUE,
            system_short TEXT NOT NULL
        );

        CREATE TABLE games (
            game_id INTEGER PRIMARY KEY AUTOINCREMENT,
            system_id INTEGER NOT NULL REFERENCES systems(system_id),
            game_title TEXT NOT NULL,
            file_title TEXT NOT NULL,
            region TEXT,
            md5 TEXT
        );

        CREATE TABLE cheats (
            cheat_id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(game_id),
            cheat_name TEXT NOT NULL,
            cheat_code TEXT NOT NULL,
            device_name TEXT NOT NULL DEFAULT 'RetroArch',
            format       TEXT
        );

        CREATE INDEX idx_games_title ON games(game_title COLLATE NOCASE);
        CREATE INDEX idx_games_system ON games(system_id);
        CREATE INDEX idx_games_md5 ON games(md5);
        CREATE INDEX idx_cheats_game ON cheats(game_id);
        CREATE INDEX idx_systems_name ON systems(system_name);
    """)

    conn.commit()
    return conn


def process_cht_directory(cht_root, db_path, md5_map=None):
    """Walk the cht directory and populate the database."""
    conn = create_database(db_path)
    c = conn.cursor()
    md5_map = md5_map or {}

    system_cache = {}  # system_name -> system_id
    total_games = 0
    total_cheats = 0
    total_md5_hits = 0
    skipped_systems = set()

    for system_dir in sorted(Path(cht_root).iterdir()):
        if not system_dir.is_dir():
            continue

        system_name = system_dir.name
        short_name = SYSTEM_SHORT_NAMES.get(system_name)

        if not short_name:
            skipped_systems.add(system_name)
            # Still process it with the directory name as short name
            short_name = system_name

        # Insert or get system
        if system_name not in system_cache:
            c.execute(
                "INSERT OR IGNORE INTO systems (system_name, system_short) VALUES (?, ?)",
                (system_name, short_name),
            )
            c.execute("SELECT system_id FROM systems WHERE system_name = ?", (system_name,))
            system_cache[system_name] = c.fetchone()[0]

        system_id = system_cache[system_name]
        system_games = 0
        system_cheats = 0
        system_md5_hits = 0

        # Get MD5 lookup dict for this system (may be None)
        sys_md5 = md5_map.get(system_name, {})

        for cht_file in sorted(system_dir.glob("*.cht")):
            stem = cht_file.stem
            cheats = parse_cht_file(cht_file)

            if not cheats:
                continue

            title, region = extract_title_and_region(stem)
            device = extract_device_name(stem)

            # MD5 lookup: strip device suffix from stem to get the No-Intro name
            lookup_stem = _stem_without_device(stem)
            md5 = sys_md5.get(lookup_stem)
            if md5:
                system_md5_hits += 1

            c.execute(
                "INSERT INTO games (system_id, game_title, file_title, region, md5) VALUES (?, ?, ?, ?, ?)",
                (system_id, title, stem, region, md5),
            )
            game_id = c.lastrowid
            system_games += 1

            for desc, code in cheats:
                fmt = detect_format(code, device)
                c.execute(
                    "INSERT INTO cheats (game_id, cheat_name, cheat_code, device_name, format) VALUES (?, ?, ?, ?, ?)",
                    (game_id, desc, code, device, fmt),
                )
                system_cheats += 1

        total_games += system_games
        total_cheats += system_cheats
        total_md5_hits += system_md5_hits

        if system_games > 0:
            md5_info = f", {system_md5_hits}/{system_games} with MD5" if sys_md5 else ""
            print(f"  {system_name}: {system_games} games, {system_cheats} cheats{md5_info}")

    conn.commit()

    # Print summary
    print(f"\nTotal: {total_games} games, {total_cheats} cheats across {len(system_cache)} systems")
    if md5_map:
        print(f"MD5 hashes found: {total_md5_hits}/{total_games} games ({100*total_md5_hits//max(total_games,1)}%)")

    if skipped_systems:
        print(f"\nSystems without short name mapping ({len(skipped_systems)}):")
        for s in sorted(skipped_systems):
            print(f"  - {s}")

    # Analyze and optimize
    c.execute("ANALYZE")
    conn.commit()
    conn.close()

    return total_games, total_cheats


def compress_database(db_path):
    """Compress the database to a .zip file."""
    zip_path = db_path + ".zip"
    db_name = os.path.basename(db_path)

    with zipfile.ZipFile(zip_path, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as zf:
        zf.write(db_path, db_name)

    db_size = os.path.getsize(db_path)
    zip_size = os.path.getsize(zip_path)
    ratio = (1 - zip_size / db_size) * 100 if db_size > 0 else 0

    print(f"\nDatabase: {db_size / 1024 / 1024:.1f} MB")
    print(f"Compressed: {zip_size / 1024 / 1024:.1f} MB ({ratio:.0f}% reduction)")

    return zip_path


def main():
    parser = argparse.ArgumentParser(
        description="Convert libretro .cht cheat files to SQLite database"
    )
    parser.add_argument(
        "cht_dir",
        help="Path to the libretro-database cht/ directory",
    )
    parser.add_argument(
        "--output",
        "-o",
        default="libretro_cheats.sqlite",
        help="Output SQLite database path (default: libretro_cheats.sqlite)",
    )
    parser.add_argument(
        "--dat-dir",
        default=None,
        metavar="PATH",
        help=(
            "Root of the libretro-database repo (contains metadat/ and dat/ dirs). "
            "When provided, MD5 hashes are cross-referenced from CLRMamePro DAT files "
            "and stored in the games.md5 column."
        ),
    )
    parser.add_argument(
        "--no-compress",
        action="store_true",
        help="Skip creating the .zip compressed version",
    )
    args = parser.parse_args()

    cht_dir = args.cht_dir
    if not os.path.isdir(cht_dir):
        print(f"Error: {cht_dir} is not a directory", file=sys.stderr)
        sys.exit(1)

    # Ensure output directory exists
    output_dir = os.path.dirname(args.output)
    if output_dir:
        os.makedirs(output_dir, exist_ok=True)

    print(f"Processing .cht files from: {cht_dir}")
    print(f"Output: {args.output}\n")

    # Build MD5 map if dat-dir provided
    md5_map = {}
    if args.dat_dir:
        if not os.path.isdir(args.dat_dir):
            print(f"Warning: --dat-dir '{args.dat_dir}' is not a directory; skipping MD5 lookup", file=sys.stderr)
        else:
            print(f"Building MD5 map from DAT files in: {args.dat_dir}")
            md5_map = build_md5_map(args.dat_dir)
            print()

    total_games, total_cheats = process_cht_directory(cht_dir, args.output, md5_map)

    if total_cheats == 0:
        print("Warning: No cheats were found!", file=sys.stderr)
        sys.exit(1)

    if not args.no_compress:
        compress_database(args.output)

    print("\nDone!")


if __name__ == "__main__":
    main()
