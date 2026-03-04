#!/usr/bin/env python3
"""
generate_cheatdb.py — Convert libretro .cht cheat files to SQLite database.

Parses the libretro-database cht/ directory structure and produces a
libretro_cheats.sqlite database for Provenance's cheat code lookup.

Usage:
    python3 Scripts/generate_cheatdb.py /path/to/libretro-database/cht/ \
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
"""

import argparse
import os
import re
import sqlite3
import zipfile
import sys
from pathlib import Path


# Map libretro directory names to short system names.
# These must match SystemIdentifier.libretroDatabaseName in Provenance.
SYSTEM_SHORT_NAMES = {
    "Atari - 2600": "2600",
    "Atari - 5200": "5200",
    "Atari - 7800": "7800",
    "Atari - 8-bit": "Atari8bit",
    "Atari - Jaguar": "Jaguar",
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
    "Microsoft - MSX": "MSX",
    "Microsoft - MSX2": "MSX2",
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
    "Nintendo - Nintendo DS": "DS",
    "Nintendo - Nintendo Entertainment System": "NES",
    "Nintendo - Pokemon Mini": "PokemonMini",
    "Nintendo - Super Nintendo Entertainment System": "SNES",
    "Nintendo - Virtual Boy": "VirtualBoy",
    "Nintendo - Wii": "Wii",
    "Nintendo - Nintendo 3DS": "3DS",
    "Sega - 32X": "Sega32X",
    "Sega - Dreamcast": "Dreamcast",
    "Sega - Game Gear": "GameGear",
    "Sega - Master System - Mark III": "MasterSystem",
    "Sega - Mega Drive - Genesis": "Genesis",
    "Sega - Mega-CD - Sega CD": "SegaCD",
    "Sega - SG-1000": "SG1000",
    "Sega - Saturn": "Saturn",
    "SNK - Neo Geo": "NeoGeo",
    "SNK - Neo Geo Pocket": "NGP",
    "SNK - Neo Geo Pocket Color": "NGPC",
    "Sony - PlayStation": "PSX",
    "Sony - PlayStation 2": "PS2",
    "Sony - PlayStation Portable": "PSP",
    "The 3DO Company - 3DO": "3DO",
    "MAME": "MAME",
    "Watara - Supervision": "Supervision",
    "Sinclair - ZX Spectrum": "ZXSpectrum",
    "Philips - CD-i": "CDi",
}

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
            region TEXT
        );

        CREATE TABLE cheats (
            cheat_id INTEGER PRIMARY KEY AUTOINCREMENT,
            game_id INTEGER NOT NULL REFERENCES games(game_id),
            cheat_name TEXT NOT NULL,
            cheat_code TEXT NOT NULL,
            device_name TEXT NOT NULL DEFAULT 'RetroArch'
        );

        CREATE INDEX idx_games_title ON games(game_title COLLATE NOCASE);
        CREATE INDEX idx_games_system ON games(system_id);
        CREATE INDEX idx_cheats_game ON cheats(game_id);
        CREATE INDEX idx_systems_name ON systems(system_name);
    """)

    conn.commit()
    return conn


def process_cht_directory(cht_root, db_path):
    """Walk the cht directory and populate the database."""
    conn = create_database(db_path)
    c = conn.cursor()

    system_cache = {}  # system_name -> system_id
    total_games = 0
    total_cheats = 0
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

        for cht_file in sorted(system_dir.glob("*.cht")):
            stem = cht_file.stem
            cheats = parse_cht_file(cht_file)

            if not cheats:
                continue

            title, region = extract_title_and_region(stem)
            device = extract_device_name(stem)

            c.execute(
                "INSERT INTO games (system_id, game_title, file_title, region) VALUES (?, ?, ?, ?)",
                (system_id, title, stem, region),
            )
            game_id = c.lastrowid
            system_games += 1

            for desc, code in cheats:
                c.execute(
                    "INSERT INTO cheats (game_id, cheat_name, cheat_code, device_name) VALUES (?, ?, ?, ?)",
                    (game_id, desc, code, device),
                )
                system_cheats += 1

        total_games += system_games
        total_cheats += system_cheats

        if system_games > 0:
            print(f"  {system_name}: {system_games} games, {system_cheats} cheats")

    conn.commit()

    # Print summary
    print(f"\nTotal: {total_games} games, {total_cheats} cheats across {len(system_cache)} systems")

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

    total_games, total_cheats = process_cht_directory(cht_dir, args.output)

    if total_cheats == 0:
        print("Warning: No cheats were found!", file=sys.stderr)
        sys.exit(1)

    if not args.no_compress:
        compress_database(args.output)

    print("\nDone!")


if __name__ == "__main__":
    main()
